# fnp-documentacao — Base de Conhecimento FNP

## Contexto do projeto

Sistema RAG (Recuperação com Geração Aumentada) para a FNP (Frente Nacional de Prefeitas e Prefeitos).
Indexa documentos internos — Google Drive, rede local, DO Spaces — e responde perguntas em linguagem natural
via Claude API, citando as fontes exatas de onde veio cada informação.

A infraestrutura roda 100% no DigitalOcean. O banco PostgreSQL já existe e está operacional.
Este projeto **não é um sistema isolado** — o worker de ingestão e a API serão integrados
ao Sistema FNP existente (Django 5.x) quando estiverem prontos.

---

## Stack

| Componente | Tecnologia |
|------------|------------|
| Linguagem | Python 3.12 |
| Banco de dados | PostgreSQL 16 com extensão pgvector (DO Managed) |
| Armazenamento de arquivos | DO Spaces (compatível com S3) |
| Geração de embeddings | OpenAI `text-embedding-ada-002` |
| Geração de respostas | Anthropic Claude Sonnet (`claude-sonnet-4-20250514`) |
| API e interface | Django 5.x (mesmo projeto do Sistema FNP) |
| Sistema operacional do worker | Ubuntu 22.04 (Droplet DO sem IP público) |

---

## Convenções obrigatórias

- **Todo código, comentário, docstring, log e documentação em português brasileiro (PT-BR)**
- Nomes técnicos de bibliotecas Python permanecem em inglês (são os nomes reais das APIs)
- Nomes de funções, variáveis, classes e arquivos: PT-BR
- Nunca commitar `.env` — credenciais ficam exclusivamente em variáveis de ambiente
- Nunca hardcodar senhas, chaves de API ou strings de conexão no código
- Scripts SQL em `scripts/sql/`
- Scripts Python em `scripts/python/`
- Scripts de servidor em `scripts/shell/`
- Documentação em `docs/`

---

## Estrutura do repositório

```
fnp-documentacao/
├── CLAUDE.md                        ← este arquivo
├── README.md                        ← visão geral do projeto
├── .env.example                     ← template de variáveis (sem valores reais)
├── .gitignore
│
├── docs/
│   ├── equipe/                      ← guias para a equipe sem acesso técnico
│   │   ├── COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md
│   │   ├── GUIA_ARQUIVOS.md
│   │   └── ESTRUTURA_DRIVE.md
│   ├── tecnico/
│   │   └── ARQUITETURA.md
│   ├── banco/
│   │   └── BANCO.md
│   └── sistemas/
│       ├── TEMPLATE_SISTEMA.md
│       └── SISTEMA_FNP.md           ← gerado a partir do CLAUDE.md do Sistema FNP
│
└── scripts/
    ├── sql/
    │   └── 01_setup_banco.sql       ← cria extensões, schemas, roles e tabelas
    ├── python/
    │   └── ingestor.py              ← worker de ingestão (Spaces → banco)
    └── shell/
        └── setup_worker.sh         ← configura o Droplet de ingestão no DO
```

---

## Variáveis de ambiente necessárias

Todas ficam no arquivo `.env` na raiz do projeto. Ver `.env.example` para o template completo.

```
# Banco de dados
DB_HOST, DB_PORT, DB_NAME, DB_SSL
DB_PASS_ADMIN, DB_PASS_APP_WRITE, DB_PASS_INGESTOR, DB_PASS_READONLY

# DigitalOcean Spaces
DO_SPACES_KEY, DO_SPACES_SECRET, DO_SPACES_BUCKET, DO_SPACES_REGION, DO_SPACES_ENDPOINT

# Google Drive API
GOOGLE_SERVICE_ACCOUNT_JSON, GOOGLE_DRIVE_FOLDER_ID

# OpenAI (embeddings)
OPENAI_API_KEY, OPENAI_EMBEDDING_MODEL

# Anthropic (respostas)
ANTHROPIC_API_KEY, ANTHROPIC_MODEL
```

---

## Fases do projeto

O projeto está dividido em 7 fases. Cada fase deve ser concluída e testada antes de avançar.
Atualize os checkboxes conforme for concluindo.

### Fase 1 — Extensões e schemas no banco DigitalOcean
**Status:** `[ ] pendente`

O que fazer:
- Conectar no banco DO usando as credenciais do `.env`
- Executar `scripts/sql/01_setup_banco.sql` completo
- Verificar que as extensões `vector`, `uuid-ossp` e `pgcrypto` foram criadas
- Verificar que os schemas `rag`, `app` e `admin` existem
- Verificar que o schema `public` está bloqueado

Comando para testar:
```bash
psql "postgresql://doadmin:SENHA@HOST:25060/defaultdb?sslmode=require" \
  -c "SELECT extname FROM pg_extension WHERE extname IN ('vector','uuid-ossp','pgcrypto');"
```

Critério de conclusão: os 3 schemas existem e as 3 extensões aparecem na consulta.

---

### Fase 2 — Roles e permissões
**Status:** `[ ] pendente`

O que fazer:
- Confirmar que os 4 roles foram criados: `dba_admin`, `app_write`, `ingestor`, `readonly`
- Confirmar que as permissões por schema estão corretas (ver `docs/banco/BANCO.md`)
- Testar conexão com cada role

Comando para verificar roles:
```bash
psql "postgresql://doadmin:SENHA@HOST:25060/defaultdb?sslmode=require" \
  -c "SELECT rolname FROM pg_roles WHERE rolname IN ('dba_admin','app_write','ingestor','readonly');"
```

Critério de conclusão: os 4 roles aparecem na consulta e cada um consegue conectar.

---

### Fase 3 — Tabelas do schema rag
**Status:** `[ ] pendente`

O que fazer:
- Confirmar que as tabelas foram criadas: `rag.documentos`, `rag.arquivos_indexados`, `rag.historico_perguntas`
- Confirmar que o índice `ivfflat` para busca por similaridade foi criado em `rag.documentos`
- Confirmar que as tabelas `admin.usuarios` e `admin.audit_log` existem

Comando para verificar:
```bash
psql "postgresql://doadmin:SENHA@HOST:25060/defaultdb?sslmode=require" \
  -c "SELECT schemaname, tablename FROM pg_tables WHERE schemaname IN ('rag','admin') ORDER BY 1,2;"
```

Critério de conclusão: todas as tabelas aparecem na consulta.

---

### Fase 4 — DO Spaces configurado
**Status:** `[ ] pendente`

O que fazer:
- Criar o Space `fnp-knowledge-base` no painel DO (região nyc3, acesso privado)
- Criar a estrutura de pastas (prefixos):
  - `documentos/regulamentos/`
  - `documentos/apresentacoes/`
  - `documentos/administrativo/`
  - `sistemas/` (para os CLAUDE.md de cada sistema)
  - `dados/` (para Parquet e XLS pesados)
- Gerar chaves de acesso (Access Keys) em DO → API → Spaces Keys
- Configurar as variáveis `DO_SPACES_*` no `.env`
- Testar o upload de um arquivo de teste via Python

Script de teste de conexão ao Spaces:
```python
# testar_spaces.py — rodar localmente para validar conexão
import boto3, os
from dotenv import load_dotenv
load_dotenv()

s3 = boto3.client(
    "s3",
    region_name=os.getenv("DO_SPACES_REGION"),
    endpoint_url=os.getenv("DO_SPACES_ENDPOINT"),
    aws_access_key_id=os.getenv("DO_SPACES_KEY"),
    aws_secret_access_key=os.getenv("DO_SPACES_SECRET"),
)
bucket = os.getenv("DO_SPACES_BUCKET")
s3.put_object(Bucket=bucket, Key="teste/conexao.txt", Body=b"FNP Spaces OK")
print("Upload OK")
objs = s3.list_objects_v2(Bucket=bucket, Prefix="teste/")
print("Arquivo encontrado:", objs["Contents"][0]["Key"])
s3.delete_object(Bucket=bucket, Key="teste/conexao.txt")
print("Limpeza feita — Spaces funcionando!")
```

Critério de conclusão: script de teste roda sem erro.

---

### Fase 5 — Worker de ingestão funcionando localmente
**Status:** `[ ] pendente`

O que fazer:
- Instalar dependências localmente para teste:
  ```bash
  pip install openai anthropic psycopg2-binary pgvector boto3 pypdf \
              python-docx python-pptx pandas pyarrow openpyxl \
              tiktoken python-dotenv
  ```
- Fazer upload de 2 a 3 arquivos de teste no Spaces (um PDF, um DOCX, uma planilha)
- Rodar o ingestor apontando para um arquivo específico:
  ```bash
  python scripts/python/ingestor.py --arquivo documentos/regulamentos/arquivo_teste.pdf
  ```
- Verificar no banco se os chunks foram salvos:
  ```sql
  SELECT fonte, tipo, total_chunks FROM rag.arquivos_indexados;
  SELECT fonte, LEFT(conteudo, 100) FROM rag.documentos LIMIT 5;
  ```
- Rodar ingestão completa com tudo que estiver no Spaces:
  ```bash
  python scripts/python/ingestor.py
  ```

Critério de conclusão: chunks aparecem no banco com embedding preenchido (não nulo).

---

### Fase 6 — Busca semântica e resposta via Claude
**Status:** `[ ] pendente`

O que fazer:
- Criar `scripts/python/buscar.py` com a função de busca semântica
- Criar `scripts/python/rag.py` com a função de resposta via Claude
- Testar no terminal com perguntas reais sobre os documentos indexados

Script de teste rápido:
```python
# testar_rag.py — validação local antes de integrar ao Django
from buscar import buscar
from rag import perguntar

resultado = perguntar("Qual é o objetivo do programa X?")
print("Resposta:", resultado["resposta"])
print("Fontes:", resultado["fontes"])
print("Tokens usados:", resultado["tokens"])
```

Critério de conclusão: perguntas sobre os documentos indexados retornam respostas coerentes com as fontes citadas.

---

### Fase 7 — Deploy do worker no Droplet DO
**Status:** `[ ] pendente`

O que fazer:
- Criar Droplet Ubuntu 22.04 no DO (1GB RAM, $6/mês), dentro da mesma VPC do banco, sem IP público
- Executar `scripts/shell/setup_worker.sh` no servidor
- Copiar `ingestor.py` e `.env` para `/home/fnp/app/`
- Testar manualmente no servidor
- Confirmar que o cron está rodando (ingestão diária às 2h)

Critério de conclusão: log `/var/log/fnp-ingestor.log` mostra execução bem-sucedida.

---

## Como rodar localmente (desenvolvimento)

```bash
# 1. Clonar o repositório
git clone git@github.com:fnp/fnp-documentacao.git
cd fnp-documentacao

# 2. Criar ambiente virtual
python -m venv .venv
source .venv/bin/activate        # Linux/Mac
.venv\Scripts\activate           # Windows

# 3. Instalar dependências
pip install openai anthropic psycopg2-binary pgvector boto3 pypdf \
            python-docx python-pptx pandas pyarrow openpyxl \
            tiktoken python-dotenv

# 4. Copiar e preencher o .env
cp .env.example .env
# editar .env com as credenciais reais

# 5. Testar conexão ao banco
psql "postgresql://readonly:SENHA@HOST:25060/defaultdb?sslmode=require" -c "\dt rag.*"

# 6. Testar ingestão de um arquivo
python scripts/python/ingestor.py --arquivo sistemas/SISTEMA_FNP.md
```

---

## Decisões técnicas relevantes

| Decisão | Escolha | Motivo |
|---------|---------|--------|
| Armazenamento de vetores | pgvector no PostgreSQL DO | Sem custo extra, mesmo banco já existente |
| Modelo de embedding | OpenAI ada-002 | Melhor custo-benefício para PT-BR, API simples |
| Modelo de resposta | Claude Sonnet | Contexto grande, excelente em português |
| Reindexação | Por hash SHA-256 | Só reindexar se o arquivo realmente mudou |
| Arquivos originais | Ficam no Drive/Spaces | Não duplicar o que já funciona bem no Drive |
| Acesso ao banco | Só pela VPC DO | Banco nunca exposto à internet |

---

## Erros comuns e soluções

**Erro: `pgvector` não encontrado ao fazer INSERT**
→ A extensão não foi ativada. Rodar: `CREATE EXTENSION IF NOT EXISTS vector;` como `doadmin`.

**Erro: permissão negada ao inserir em `rag.documentos`**
→ O role `ingestor` não tem permissão. Verificar se `ALTER DEFAULT PRIVILEGES` foi executado após criar as tabelas.

**Erro: SSL obrigatório no banco DO**
→ Sempre usar `sslmode=require` na string de conexão. O DO Managed Postgres exige SSL.

**Embedding retorna vetor de tamanho diferente de 1536**
→ O modelo foi trocado. O campo `embedding VECTOR(1536)` é fixo para o `ada-002`. Se mudar o modelo, recriar a coluna.

**Ingestão não encontra arquivo no Spaces**
→ Verificar o `Key` exato do objeto. O Spaces é sensível a maiúsculas e o prefixo de pasta faz parte do Key.

---

## Contato

Pedro Ivo — pedro.ivo@fnp.org.br