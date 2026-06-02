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
    metadata      JSONB       NOT NULL DEFAULT '{}',
    hash_arquivo  TEXT,
    indexado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice de busca semântica
CREATE INDEX IF NOT EXISTS idx_documentos_embedding
    ON rag.documentos USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Índices de filtro
CREATE INDEX IF NOT EXISTS idx_documentos_tipo     ON rag.documentos (tipo);
CREATE INDEX IF NOT EXISTS idx_documentos_sistema  ON rag.documentos (sistema);
CREATE INDEX IF NOT EXISTS idx_documentos_fonte    ON rag.documentos (fonte);

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
WHERE schemaname IN ('rag', 'app', 'admin')
ORDER BY schemaname, tablename;
