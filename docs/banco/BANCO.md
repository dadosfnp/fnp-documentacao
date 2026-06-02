# Banco de Dados — FNP PostgreSQL (DigitalOcean)

## Conexão

| Campo | Valor |
|-------|-------|
| Host | `db-xxx.db.ondigitalocean.com` *(atualizar)* |
| Porta | `25060` |
| Banco | `defaultdb` |
| SSL | obrigatório (`sslmode=require`) |

---

## Roles (usuários do banco)

| Role | Acesso | Usado por |
|------|--------|-----------|
| `dba_admin` | tudo | Pedro (admin) |
| `app_write` | leitura + escrita em `rag` e `app` | Django API |
| `ingestor` | leitura + escrita só em `rag` | Worker Python |
| `readonly` | leitura em `rag` e `app` | Analistas / colegas |

**Regra:** nenhum role externo acessa o schema `admin`.

---

## Schemas

### `rag` — Knowledge Base e embeddings

**`rag.documentos`** — chunks de texto indexados com embedding

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `fonte` | text | caminho/URL do arquivo original |
| `tipo` | text | pdf, docx, pptx, md, xlsx, parquet |
| `sistema` | text | nome do sistema (para CLAUDE.md) |
| `conteudo` | text | texto do chunk |
| `embedding` | vector(1536) | vetor semântico (OpenAI ada-002) |
| `metadata` | jsonb | página, slide, aba etc. |
| `hash_arquivo` | text | SHA-256 do arquivo (evita reindexação desnecessária) |
| `indexado_em` | timestamptz | quando foi indexado |
| `atualizado_em` | timestamptz | última atualização |

**`rag.arquivos_indexados`** — controle de ingestão

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `caminho` | text | caminho único do arquivo |
| `hash_sha256` | text | hash para detectar mudanças |
| `tipo` | text | extensão do arquivo |
| `total_chunks` | int | quantos chunks foram gerados |
| `ultima_ingestao` | timestamptz | quando foi indexado por último |
| `status` | text | ok, erro, pendente |

**`rag.historico_perguntas`** — log de consultas

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `usuario_id` | uuid | quem perguntou |
| `pergunta` | text | texto da pergunta |
| `resposta` | text | resposta gerada |
| `fontes_usadas` | text[] | arquivos citados |
| `tokens_usados` | int | tokens consumidos |
| `latencia_ms` | int | tempo de resposta |
| `criado_em` | timestamptz | quando foi feita |

---

### `app` — Dados do Sistema FNP

Tabelas do sistema operacional da FNP (municípios, prefeitos, eventos etc.).
Ver documentação específica em `docs/sistemas/`.

---

### `admin` — Auditoria e controle

**`admin.usuarios`** — usuários com acesso ao sistema de chat

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `nome` | text | nome completo |
| `email` | text | email único |
| `role` | text | leitor, editor, admin |
| `ativo` | boolean | se tem acesso ativo |
| `criado_em` | timestamptz | data de criação |

**`admin.audit_log`** — registro de todas as ações

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | bigserial | chave primária |
| `usuario` | text | quem executou |
| `acao` | text | INSERT, UPDATE, DELETE, PERGUNTA |
| `tabela` | text | tabela afetada |
| `dado_novo` | jsonb | dado no momento da ação |
| `ip` | text | IP de origem |
| `criado_em` | timestamptz | quando ocorreu |

---

## Como conectar (para analistas)

**DBeaver (recomendado):**
1. Download gratuito em dbeaver.io
2. New Connection → PostgreSQL
3. Preencha host, porta, banco, usuário `readonly`
4. Aba SSL → SSL mode = Require

**Python:**
```python
import psycopg2
conn = psycopg2.connect(
    host="db-xxx.db.ondigitalocean.com",
    port=25060,
    dbname="defaultdb",
    user="readonly",
    password="SENHA",
    sslmode="require"
)
```

---

## Pedir acesso

Contato: **Pedro Ivo** — pedro.ivo@fnp.org.br
Informar: nome completo, e-mail, qual tipo de acesso precisa e para qual finalidade.
