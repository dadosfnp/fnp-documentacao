# Arquitetura — FNP Knowledge Base

## Visão geral

O sistema é composto por três camadas:

1. **Fontes de dados** — onde os arquivos vivem (Google Drive, rede local, banco)
2. **Pipeline de ingestão** — lê, extrai texto, gera embeddings e indexa
3. **API de consulta** — recebe perguntas, busca contexto, retorna respostas via Claude

Os arquivos originais **não são movidos**. O sistema cria um índice de busca semântica (embeddings) sobre o conteúdo deles.

---

## Componentes no DigitalOcean

```
DigitalOcean (VPC privada)
│
├── App Platform
│   └── Django API (HTTPS :443)
│       ├── endpoint /api/perguntar/
│       └── interface de chat (React)
│
├── Droplet worker (sem IP público)
│   └── ingestor.py
│       ├── lê Google Drive via API
│       ├── lê DO Spaces
│       └── escreve embeddings no banco
│
├── DO Spaces (privado)
│   └── fnp-knowledge-base/
│       ├── documentos/
│       ├── sistemas/    ← CLAUDE.md de cada sistema
│       └── dados/       ← Parquet, XLS pesados
│
└── PostgreSQL gerenciado (banco único)
    ├── schema: rag                    ← embeddings, histórico, catálogo
    ├── schema: app                    ← dados FNP (municípios etc.)
    ├── schema: admin                  ← usuários, audit log
    └── schemas do Núcleo de Dados     ← dados tabulares consultáveis via SQL
        ├── economia                   ← ex.: economia.pib_municipal
        ├── social
        └── eleitoral
```

> Os schemas do Núcleo ficam **no mesmo banco** do `rag` (RDA-002) — assim o assistente
> cruza documento + dado na mesma query, sem `postgres_fdw`.

---

## Fluxo de ingestão

```
Arquivo novo/modificado no Drive ou Spaces
    │
    ▼
Worker detecta mudança (cron diário + polling: lista e compara hash)
    │
    ▼
É dado tabular (xlsx/parquet/csv)? → NÃO embeda: vai pro Núcleo (text-to-SQL)
    │ (documento)
    ▼
Extrai texto (PyPDF / python-docx / python-pptx)
    │
    ▼
Divide em chunks (~800 chars, overlap 100)
    │
    ▼
Classifica nível de acesso pela pasta de origem (publico/interno/restrito)
    │
    ▼
Gera embedding via OpenAI text-embedding-3-small (1536 dims)
    │
    ▼
Salva em rag.documentos (conteudo + embedding + nivel_acesso + metadata)
    │
    ▼
Atualiza rag.arquivos_indexados (hash + timestamp)
```

> **Por que cron + polling e não webhook do Drive:** o webhook do Google exige um endpoint
> HTTPS público e renova o canal a cada 7 dias — incompatível com o worker sem IP público
> (RDA-003). O cron diário lista o Drive e compara o SHA-256 contra o catálogo. Mais simples
> e suficiente para o volume da FNP.

---

## Fluxo de consulta

```
Usuário faz pergunta na interface
    │
    ▼
Django API recebe POST /api/perguntar/
    │
    ▼
ROTEADOR: a pergunta é sobre documento ou sobre dado?  (ver RDA-006)
    │
    ├── DOCUMENTO ("o que foi decidido na 89ª Reunião?")
    │       │
    │       ▼
    │   Gera embedding da pergunta
    │       │
    │       ▼
    │   Busca top-6 chunks por similaridade coseno (pgvector),
    │   filtrando por nivel_acesso do usuário  (ver RDA-007)
    │       │
    │       ▼
    │   Monta prompt: system + chunks + pergunta
    │
    └── DADO ("PIB dos 10 maiores municípios filiados")
            │
            ▼
        Seleciona o(s) dataset(s) pelo catálogo/dicionário (tabela, colunas, grão)
            │
            ▼
        Claude gera SQL (text-to-SQL), roda nos schemas do Núcleo (readonly)
            │
            ▼
        Monta prompt: system + resultado da query + pergunta
    │
    ▼
Claude Sonnet gera a resposta citando a fonte (arquivo no Drive OU tabela no banco)
    │
    ▼
Salva em rag.historico_perguntas
    │
    ▼
Retorna { resposta, fontes, tokens }
```

---

## Decisões de arquitetura (RDAs)

### RDA-001 — Arquivos originais ficam no Drive, não no banco
**Decisão:** não mover arquivos do Drive para o banco. O banco guarda só texto extraído e embeddings.
**Motivo:** Drive já tem versionamento, colaboração e permissões. Duplicar seria trabalho sem ganho.

### RDA-002 — Um banco PostgreSQL único com schemas separados
**Decisão:** schemas `rag`, `app`, `admin` **e os schemas do Núcleo de Dados** (`economia`,
`social`, `eleitoral`...) no mesmo banco DO. Isolamento via roles do PostgreSQL.
**Motivo:** simplifica operação, backup e custo — e, principalmente, permite ao assistente
**cruzar documento + dado na mesma query** (`rag` × Núcleo) sem `postgres_fdw`.

**Regra canônica (schema vs. database):**
- **Dado tabular consultável** (datasets do Núcleo) → **schema** no banco do RAG.
- **Sistema com ORM próprio** (ex.: IFEM) → **database** dedicado (1 sistema = 1 database, ver
  [`playbook-deploy-novo-sistema.md`](../../TIC/playbook-deploy-novo-sistema.md)). É um app externo
  com ciclo de vida próprio, não um dado que o assistente consulta diretamente.

> Isto reconcilia a aparente contradição com o playbook de deploy: "1 sistema = 1 database" vale
> para **apps**; dado tabular do Núcleo **não é um app**, é um schema aqui.

### RDA-003 — Worker sem IP público
**Decisão:** Droplet do worker fica só na VPC interna, sem acesso externo.
**Motivo:** o worker só precisa falar com o banco e o Spaces, ambos dentro da VPC.
**Consequência:** a detecção de mudança é por **cron diário + polling** (lista o Drive/Spaces e
compara hash), **não por webhook** — webhook do Google exige endpoint HTTPS público e renovação
de canal a cada 7 dias, o que o worker sem IP não consegue oferecer.

### RDA-004 — Reindexação por hash, não por data
**Decisão:** só reindexar arquivo se o SHA-256 mudou.
**Motivo:** economiza custo de embedding (OpenAI cobra por token).

### RDA-005 — Acesso à API apenas via autenticação Django
**Decisão:** endpoint `/api/perguntar/` exige login. Colegas acessam via interface web, não diretamente ao banco.
**Motivo:** banco fica inacessível externamente. API é a única entrada controlada.

### RDA-006 — Roteamento documento vs. dado (text-to-SQL)
**Decisão:** o assistente tem **duas pernas**, escolhidas por um roteador antes de responder:
- **Documento** ("o que foi decidido na ata X?") → busca semântica nos embeddings de `rag`.
- **Dado** ("PIB dos 10 maiores municípios filiados?") → **text-to-SQL**: Claude gera a query a
  partir do dicionário do dataset (tabela, colunas, grão, unidade), roda nos schemas do Núcleo
  (com credencial de leitura) e responde com o resultado, citando a tabela.

**Motivo:** busca por similaridade de vetor **não responde** pergunta de ranking/soma/filtro — isso
é SQL. Indexar uma base de 78 mil linhas como texto seria caro e inútil. O **dicionário que o Núcleo
preenche é exatamente o insumo do text-to-SQL** (ver
[`template-dicionario-dataset.md`](../../TIC/template-dicionario-dataset.md) e a versão `.yaml`),
então o trabalho da equipe não se perde — o roteador apenas consome esse mapa.

### RDA-007 — Classificação na ingestão + controle de acesso na resposta (LGPD)
**Decisão:** todo chunk indexado recebe um `nivel_acesso` (`publico` | `interno` | `restrito`)
derivado da **pasta de origem**; a resposta **filtra** os chunks pelo nível do usuário.
**Motivo:** o RAG copia o texto dos documentos para `rag.documentos.conteudo`. Sem controle, um
contrato ou ata com dado pessoal viraria cópia de PII acessível a qualquer usuário do chat,
furando o LGPD nível 2 do [Sistema FNP](../sistemas/SISTEMA_FNP.md). A pasta `documentos/administrativo/`
e contratos entram como `restrito`; o default é `interno` (conservador).
**Pendência conhecida:** a detecção de PII **no conteúdo** (não só pela pasta) ainda falta — está
marcada como TODO no `ingestor.py` e deve ser resolvida antes de indexar material sensível.

---

## Variáveis de ambiente necessárias

Ver `.env.example` na raiz do repositório.

---

## Custo estimado mensal (referência)

| Componente | Custo |
|------------|-------|
| PostgreSQL DO (Basic) | ~$15/mês |
| App Platform (Basic) | ~$12/mês |
| Droplet worker (1GB) | ~$6/mês |
| DO Spaces (250GB) | ~$5/mês |
| OpenAI Embeddings (indexação) | ~$2–5 (só na indexação inicial) |
| Claude API (consultas) | ~$20–30/mês (estimativa 100 perguntas/dia) |
| **Total estimado** | **~$60–75/mês** |
