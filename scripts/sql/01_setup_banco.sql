-- =============================================================
-- FNP Knowledge Base — Setup do banco do RAG (database `fnp_rag`)
-- Executar como doadmin, CONECTADO ao database fnp_rag.
--
-- Modelo (RDA-002): cada app tem seu próprio database (fnp_sistema, ifem,
-- nucleo_dados, ...). O RAG tem o SEU — `fnp_rag` — e é o HUB de leitura:
-- guarda localmente os embeddings (pgvector) + o catálogo, e lê os outros
-- bancos via postgres_fdw (read-only, sem copiar dado). Ver seção 7.
--
-- Criar o database uma vez (como doadmin, no defaultdb):
--   CREATE ROLE fnp_rag_app LOGIN PASSWORD '<senha-forte-gerada-no-servidor>';
--   CREATE DATABASE fnp_rag OWNER fnp_rag_app;
--   REVOKE ALL ON DATABASE fnp_rag FROM PUBLIC;
-- Depois conectar em fnp_rag e rodar este script.
-- =============================================================

-- -------------------------------------------------------------
-- 1. EXTENSÕES
-- -------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;   -- para ler os outros bancos (seção 7)

-- -------------------------------------------------------------
-- 2. SCHEMAS
-- -------------------------------------------------------------
-- Só o que é do RAG vive aqui. Dados de apps e do Núcleo NÃO ficam neste
-- banco — são lidos por FDW (seção 7). Por isso não há schema `app` nem
-- schemas temáticos do Núcleo aqui.
CREATE SCHEMA IF NOT EXISTS rag;     -- embeddings, catálogo, histórico
CREATE SCHEMA IF NOT EXISTS admin;   -- usuários do chat, audit log

-- Bloquear acesso público ao schema public
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- -------------------------------------------------------------
-- 3. ROLES (todos LOGIN, privilégio mínimo)
-- -------------------------------------------------------------

-- Admin (só Pedro)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dba_admin') THEN
    CREATE ROLE dba_admin WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Django API do RAG — lê/escreve em rag e admin; lê as foreign tables (FDW)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_write') THEN
    CREATE ROLE app_write WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Worker de ingestão — escreve só em rag
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ingestor') THEN
    CREATE ROLE ingestor WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Analistas — só leitura (rag + foreign tables)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'readonly') THEN
    CREATE ROLE readonly WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Grupo para adicionar colegas facilmente
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'fnp_readers') THEN
    CREATE ROLE fnp_readers;
  END IF;
END $$;
GRANT readonly TO fnp_readers;
-- Para adicionar um colega: GRANT fnp_readers TO nome_do_usuario;

-- Nota: a carga dos datasets do Núcleo NÃO acontece aqui. O role nucleo_carga
-- e a tabela vivem no database `nucleo_dados` (ver TIC/playbook-ingestao-dados.md).

-- -------------------------------------------------------------
-- 4. PERMISSÕES POR SCHEMA
-- -------------------------------------------------------------

-- app_write: rag + admin
GRANT USAGE ON SCHEMA rag, admin TO app_write;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA rag, admin TO app_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rag, admin TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT, INSERT, UPDATE ON TABLES TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA admin
  GRANT SELECT, INSERT, UPDATE ON TABLES TO app_write;

-- ingestor: só rag
GRANT USAGE ON SCHEMA rag TO ingestor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rag TO ingestor;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rag TO ingestor;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ingestor;

-- readonly: leitura em rag
GRANT USAGE ON SCHEMA rag TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA rag TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT ON TABLES TO readonly;

-- -------------------------------------------------------------
-- 5. TABELAS — SCHEMA RAG
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rag.documentos (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    fonte         TEXT        NOT NULL,
    tipo          TEXT        NOT NULL,
    sistema       TEXT,
    conteudo      TEXT        NOT NULL,
    embedding     VECTOR(1536),
    -- Classificação de acesso herdada da pasta de origem (ver RDA-007 e ingestor.py).
    -- O assistente filtra os chunks por este campo conforme o nível do usuário,
    -- para não vazar trecho de pasta restrita (ex.: Administrativo/, contratos) na resposta.
    nivel_acesso  TEXT        NOT NULL DEFAULT 'interno'
                  CHECK (nivel_acesso IN ('publico', 'interno', 'restrito')),
    metadata      JSONB       NOT NULL DEFAULT '{}',
    hash_arquivo  TEXT,
    indexado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice de busca semântica.
-- HNSW (pgvector 0.5+) em vez de ivfflat: melhor recall e não exige treino
-- com dados pré-carregados (ivfflat degrada se o índice é criado com a tabela vazia).
CREATE INDEX IF NOT EXISTS idx_documentos_embedding
    ON rag.documentos USING hnsw (embedding vector_cosine_ops);

-- Índices de filtro
CREATE INDEX IF NOT EXISTS idx_documentos_tipo         ON rag.documentos (tipo);
CREATE INDEX IF NOT EXISTS idx_documentos_sistema      ON rag.documentos (sistema);
CREATE INDEX IF NOT EXISTS idx_documentos_fonte        ON rag.documentos (fonte);
CREATE INDEX IF NOT EXISTS idx_documentos_nivel_acesso ON rag.documentos (nivel_acesso);

-- Controle de ingestão
CREATE TABLE IF NOT EXISTS rag.arquivos_indexados (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    caminho          TEXT        UNIQUE NOT NULL,
    hash_sha256      TEXT        NOT NULL,
    tipo             TEXT,
    total_chunks     INT         DEFAULT 0,
    ultima_ingestao  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status           TEXT        NOT NULL DEFAULT 'ok'
);

-- Catálogo: o "mapa" do que existe nas fontes (datasets do Núcleo, tabelas dos
-- apps) que o roteador consulta para montar o text-to-SQL. Alimentado pelos
-- dicionários (.yaml) — ver template-dicionario-dataset.yaml.
CREATE TABLE IF NOT EXISTS rag.catalogo_fontes (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    fonte         TEXT        NOT NULL,        -- ex.: nucleo_dados, fnp_sistema
    schema_tabela TEXT        NOT NULL,        -- ex.: economia.pib_municipal
    descricao     TEXT,
    dicionario    JSONB       NOT NULL DEFAULT '{}',  -- colunas, grão, chave, tags
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (fonte, schema_tabela)
);

-- Histórico de perguntas
CREATE TABLE IF NOT EXISTS rag.historico_perguntas (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id    UUID,
    pergunta      TEXT        NOT NULL,
    resposta      TEXT,
    fontes_usadas TEXT[],
    tokens_usados INT,
    latencia_ms   INT,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------
-- 6. TABELAS — SCHEMA ADMIN
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS admin.usuarios (
    id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome       TEXT        NOT NULL,
    email      TEXT        UNIQUE NOT NULL,
    role       TEXT        NOT NULL DEFAULT 'leitor',
    ativo      BOOLEAN     NOT NULL DEFAULT TRUE,
    criado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin.audit_log (
    id         BIGSERIAL   PRIMARY KEY,
    usuario    TEXT,
    acao       TEXT,
    tabela     TEXT,
    dado_novo  JSONB,
    ip         TEXT,
    criado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para consultas de auditoria por data
CREATE INDEX IF NOT EXISTS idx_audit_criado_em ON admin.audit_log (criado_em DESC);

-- -------------------------------------------------------------
-- 7. FEDERAÇÃO — ler os outros bancos via postgres_fdw (RDA-008)
-- -------------------------------------------------------------
-- O fnp_rag lê fnp_sistema, ifem e nucleo_dados como foreign tables READ-ONLY.
-- Cada banco-fonte deve ter um role SÓ-LEITURA (ex.: <fonte>_ro); a senha dele
-- entra no USER MAPPING (via .env, nunca hardcoded). Os bancos estão no mesmo
-- cluster DO Managed, então o host é o mesmo (porta 25060, sslmode require).
--
-- Repita o bloco abaixo para cada fonte. Exemplo com nucleo_dados:
--
--   CREATE SERVER IF NOT EXISTS srv_nucleo_dados
--     FOREIGN DATA WRAPPER postgres_fdw
--     OPTIONS (host 'SUBSTITUIR_HOST_DB', port '25060', dbname 'nucleo_dados', sslmode 'require');
--
--   CREATE USER MAPPING IF NOT EXISTS FOR app_write SERVER srv_nucleo_dados
--     OPTIONS (user 'nucleo_ro', password 'SUBSTITUIR_SENHA_RO');
--   CREATE USER MAPPING IF NOT EXISTS FOR readonly  SERVER srv_nucleo_dados
--     OPTIONS (user 'nucleo_ro', password 'SUBSTITUIR_SENHA_RO');
--
--   -- foreign tables ficam num schema espelho, fora do rag/admin:
--   CREATE SCHEMA IF NOT EXISTS ext_nucleo;
--   IMPORT FOREIGN SCHEMA economia FROM SERVER srv_nucleo_dados INTO ext_nucleo;
--   GRANT USAGE ON SCHEMA ext_nucleo TO app_write, readonly;
--   GRANT SELECT ON ALL TABLES IN SCHEMA ext_nucleo TO app_write, readonly;
--
-- Para fnp_sistema/ifem: idem, importando o schema `public` de cada um para
-- ext_fnp_sistema / ext_ifem. Assim o text-to-SQL dá JOIN entre as fontes.

-- -------------------------------------------------------------
-- 8. VERIFICAÇÃO FINAL
-- -------------------------------------------------------------
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname IN ('rag', 'admin')
ORDER BY schemaname, tablename;

-- Servidores estrangeiros configurados (após rodar a seção 7):
SELECT srvname, srvoptions FROM pg_foreign_server ORDER BY srvname;
