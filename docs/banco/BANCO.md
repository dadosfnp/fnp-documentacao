# Banco de Dados — FNP PostgreSQL (DigitalOcean)

> **Modelo (RDA-002):** 1 database por sistema no cluster DO Managed — `fnp_sistema` (CRM),
> `ifem`, `nucleo_dados` e o **`fnp_rag`** (este doc). O `fnp_rag` é o **hub**: guarda os
> embeddings e o catálogo, e lê os outros bancos por `postgres_fdw` (read-only, RDA-008).

## Conexão (database `fnp_rag`)

| Campo | Valor |
|-------|-------|
| Host | `db-xxx.db.ondigitalocean.com` *(atualizar)* |
| Porta | `25060` |
| Banco | `fnp_rag` |
| SSL | obrigatório (`sslmode=require`) |

---

## Roles (usuários do banco `fnp_rag`)

| Role | Acesso | Usado por |
|------|--------|-----------|
| `dba_admin` | tudo | Pedro (admin) |
| `app_write` | escrita em `rag`/`admin`; **leitura** nas foreign tables (FDW) | Django API (inclui o text-to-SQL) |
| `ingestor` | leitura + escrita só em `rag` | Worker Python |
| `readonly` | leitura em `rag` e nas foreign tables | Analistas / colegas |

**Regra:** nenhum role externo acessa o schema `admin`.
**Carga do Núcleo:** o role `nucleo_carga` **não vive aqui** — ele pertence ao database
`nucleo_dados` (ver [`playbook-ingestao-dados.md`](../../TIC/playbook-ingestao-dados.md)). O `fnp_rag`
só **lê** o `nucleo_dados` via FDW, com um role só-leitura (`nucleo_ro`).

---

## Schemas

### `rag` — Knowledge Base e embeddings

**`rag.documentos`** — chunks de texto indexados com embedding

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `fonte` | text | caminho/URL do arquivo original |
| `tipo` | text | pdf, docx, pptx, md, txt (só documentos — tabular não é embedado) |
| `sistema` | text | nome do sistema (para CLAUDE.md) |
| `conteudo` | text | texto do chunk |
| `embedding` | vector(1536) | vetor semântico (OpenAI text-embedding-3-small) |
| `nivel_acesso` | text | `publico` \| `interno` \| `restrito` — derivado da pasta (LGPD, RDA-007) |
| `metadata` | jsonb | página, slide, aba etc. |
| `hash_arquivo` | text | SHA-256 do arquivo (evita reindexação desnecessária) |
| `indexado_em` | timestamptz | quando foi indexado |
| `atualizado_em` | timestamptz | última atualização |

> **Índice de busca semântica:** `hnsw (embedding vector_cosine_ops)` — melhor recall que o
> `ivfflat` e sem necessidade de treino com dados pré-carregados.
> **Filtro de acesso:** toda consulta de chunks filtra por `nivel_acesso` conforme o usuário,
> para não vazar trecho de pasta restrita (ver RDA-007 em [`ARQUITETURA.md`](../tecnico/ARQUITETURA.md)).

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

**`rag.catalogo_fontes`** — o "mapa" das fontes que o roteador usa para o text-to-SQL
(qual dataset/tabela existe, em que banco, com que colunas/grão/chave). Alimentado pelos
dicionários `.yaml` (ver [`template-dicionario-dataset.yaml`](../../TIC/template-dicionario-dataset.yaml)).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | uuid | chave primária |
| `fonte` | text | banco de origem (ex.: `nucleo_dados`, `fnp_sistema`) |
| `schema_tabela` | text | ex.: `economia.pib_municipal` |
| `descricao` | text | o que o dataset responde |
| `dicionario` | jsonb | colunas, grão, chave, tags (do `.yaml`) |
| `atualizado_em` | timestamptz | última sincronização do catálogo |

---

### Foreign tables (FDW) — `ext_fnp_sistema`, `ext_ifem`, `ext_nucleo`

> ✅ **O RAG não perde acesso a nada.** Tirar o schema `app` não tira acesso — só muda *como* ele
> acessa: em vez de uma cópia local (o antigo `app`), ele lê o **banco real ao vivo** (read-only).
> O que era `app.municipios` agora é `ext_fnp_sistema.municipios`. Acesso a tudo, dado fresco, sem cópia.

Os dados que vivem em **outros bancos** (CRM em `fnp_sistema`, IFEM em `ifem`, indicadores em
`nucleo_dados`) **não são copiados** para o `fnp_rag`. Eles entram como **foreign tables** via
`postgres_fdw` (RDA-008), em schemas espelho `ext_*`, **só-leitura**:

- O text-to-SQL do assistente roda no `fnp_rag` e dá `JOIN` entre as `ext_*` como se fossem locais.
- Cada banco-fonte expõe um role só-leitura (`<fonte>_ro`) usado no *user mapping* do FDW.
- Os dados do Núcleo são carregados no database `nucleo_dados` pela TIC (role `nucleo_carga`),
  seguindo o [`playbook-ingestao-dados.md`](../../TIC/playbook-ingestao-dados.md); o `fnp_rag` só lê.
- **Sem dicionário, o roteador não enxerga:** cada dataset entra com seu dicionário
  ([`.md`](../../TIC/template-dicionario-dataset.md) + [`.yaml`](../../TIC/template-dicionario-dataset.yaml)),
  registrado em `rag.catalogo_fontes`.

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

Contato: **Pedro Ivo** — pedro.machado@fnp.org.br
Informar: nome completo, e-mail, qual tipo de acesso precisa e para qual finalidade.
