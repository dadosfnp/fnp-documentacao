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
| `app_write` | escrita em `rag`/`app`; **leitura** nos schemas do Núcleo | Django API (inclui o text-to-SQL) |
| `ingestor` | leitura + escrita só em `rag` | Worker Python |
| `nucleo_carga` | escrita só nos schemas do Núcleo (`economia`, `social`...) | TIC, ao carregar datasets |
| `readonly` | leitura em `rag`, `app` e schemas do Núcleo | Analistas / colegas |

**Regra:** nenhum role externo acessa o schema `admin`.

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

---

### `app` — Dados do Sistema FNP

Tabelas do sistema operacional da FNP (municípios, prefeitos, eventos etc.).
Ver documentação específica em `docs/sistemas/`.

---

### Schemas do Núcleo de Dados — `economia`, `social`, `eleitoral`…

Dados tabulares tratados no R (PIB, indicadores, séries) que a equipe quer **consultar/cruzar**.
Vivem como **schemas no mesmo banco** (não em database separado — RDA-002), um por tema, com
**uma tabela por dataset** em `snake_case` PT-BR (ex.: `economia.pib_municipal`).

- **Quem alimenta:** a TIC, com o role `nucleo_carga`, seguindo o
  [`playbook-ingestao-dados.md`](../../TIC/playbook-ingestao-dados.md).
- **Quem lê:** o assistente (via text-to-SQL, RDA-006) e os analistas (`readonly`).
- **Sem dicionário, não carrega:** cada dataset entra acompanhado do seu dicionário
  (ver [`template-dicionario-dataset.md`](../../TIC/template-dicionario-dataset.md) e a versão `.yaml`),
  que é o que o roteador usa para gerar a query certa.

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
