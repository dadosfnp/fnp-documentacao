-- =============================================================
-- FNP Knowledge Base — Setup completo do banco PostgreSQL
-- Executar como doadmin no banco DO
-- =============================================================

-- -------------------------------------------------------------
-- 1. EXTENSÕES
-- -------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- 2. SCHEMAS
-- -------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS rag;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS admin;

-- Schemas do Núcleo de Dados (dados tabulares consultáveis via SQL).
-- Regra canônica (RDA-002): dado tabular vive como SCHEMA no banco do RAG,
-- não como database separado — assim o assistente cruza rag + dados na mesma
-- query, sem postgres_fdw. Um schema por tema mantém a base navegável.
-- Adicione novos temas aqui conforme o Núcleo entregar datasets.
CREATE SCHEMA IF NOT EXISTS economia;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS eleitoral;

-- Bloquear acesso público ao schema public
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- -------------------------------------------------------------
-- 3. ROLES
-- -------------------------------------------------------------

-- Admin (só Pedro)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dba_admin') THEN
    CREATE ROLE dba_admin WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Django API — lê e escreve em rag e app
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

-- Carga do Núcleo de Dados — escreve só nos schemas temáticos do Núcleo.
-- Usado pela TIC ao carregar os datasets do Núcleo (Parquet validado → tabela).
-- Privilégio mínimo: nunca toca em rag, app nem admin.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nucleo_carga') THEN
    CREATE ROLE nucleo_carga WITH LOGIN PASSWORD 'SUBSTITUIR_SENHA_FORTE';
  END IF;
END $$;

-- Colegas / analistas — só leitura
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

-- -------------------------------------------------------------
-- 4. PERMISSÕES POR SCHEMA
-- -------------------------------------------------------------

-- app_write: rag + app
GRANT USAGE ON SCHEMA rag TO app_write;
GRANT USAGE ON SCHEMA app TO app_write;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA rag TO app_write;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO app_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rag TO app_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT, INSERT, UPDATE ON TABLES TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE ON TABLES TO app_write;

-- ingestor: só rag
GRANT USAGE ON SCHEMA rag TO ingestor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rag TO ingestor;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rag TO ingestor;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ingestor;

-- readonly: leitura em rag e app
GRANT USAGE ON SCHEMA rag TO readonly;
GRANT USAGE ON SCHEMA app TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA rag TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
  GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT ON TABLES TO readonly;

-- Schemas do Núcleo de Dados (economia, social, eleitoral):
--   nucleo_carga → escreve (carga dos datasets)
--   app_write    → lê (o text-to-SQL do assistente roda com esta credencial)
--   readonly     → lê (analistas consultam direto via DBeaver/psql)
-- O loop aplica a mesma política a cada schema temático; ao criar um schema
-- novo do Núcleo, basta acrescentá-lo na lista do array.
DO $$
DECLARE
  schema_nucleo TEXT;
BEGIN
  FOREACH schema_nucleo IN ARRAY ARRAY['economia', 'social', 'eleitoral']
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO nucleo_carga, app_write, readonly', schema_nucleo);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO nucleo_carga', schema_nucleo);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO app_write, readonly', schema_nucleo);
    EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO nucleo_carga', schema_nucleo);
    -- Tabelas futuras carregadas pelo nucleo_carga herdam as permissões de leitura.
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE nucleo_carga IN SCHEMA %I GRANT SELECT ON TABLES TO app_write, readonly', schema_nucleo);
  END LOOP;
END $$;

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
-- 7. VERIFICAÇÃO FINAL
-- -------------------------------------------------------------
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname IN ('rag', 'app', 'admin', 'economia', 'social', 'eleitoral')
ORDER BY schemaname, tablename;
