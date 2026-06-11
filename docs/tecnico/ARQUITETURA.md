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
DigitalOcean
│
├── Droplet «fnp-web» (Ubuntu) — IP público, Nginx (TLS), atrás de Cloudflare
│   ├── Containers Docker (padrão da infra; Compose + Nginx reverse-proxy)
│   │   ├── RAG — Django API (:8002)   ← /api/perguntar/ + chat (React)
│   │   ├── Sistema FNP (:8001) *      (* hoje systemd+venv, migrando p/ Docker)
│   │   └── IFEM (:8003)
│   └── Worker de ingestão (cron diário) — ingestor.py
│         ├── lê Google Drive / DO Spaces
│         └── escreve embeddings no banco fnp_rag
│
├── DO Spaces (privado)
│   └── fnp-knowledge-base/  (documentos/, sistemas/, dados/)
│
└── PostgreSQL Managed (DO) — 1 database por sistema
    ├── fnp_rag       ← RAG: schema rag (embeddings/catálogo) + admin
    ├── fnp_sistema   ← Sistema FNP (CRM)
    ├── ifem          ← IFEM
    └── nucleo_dados  ← dados tabulares do Núcleo (economia, social…)
            ▲
            └── fnp_rag lê os outros via postgres_fdw (read-only) — ver RDA-002/RDA-008
```

> O `fnp_rag` é o **hub de leitura**: guarda local os embeddings e o catálogo (rápido) e
> alcança os dados dos outros bancos por `postgres_fdw`, sem copiar nada.

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
> HTTPS público dedicado e renova o canal a cada 7 dias — complexidade desnecessária (RDA-003).
> O cron diário lista o Drive e compara o SHA-256 contra o catálogo. Mais simples e suficiente
> para o volume da FNP.

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
        Claude gera SQL (text-to-SQL), roda no fnp_rag via foreign tables (postgres_fdw, read-only)
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

### RDA-002 — Cada sistema tem seu database; o RAG é o hub de leitura
**Decisão:** seguir o padrão real da infra — **1 database por sistema** no mesmo cluster DO Managed
(`fnp_sistema`, `ifem`, `nucleo_dados`, ...). O RAG tem o **seu próprio database `fnp_rag`**, com
schemas `rag` (embeddings + catálogo) e `admin`. Ele **não guarda** dado de app nem do Núcleo —
lê esses bancos por `postgres_fdw` (ver RDA-008).
**Motivo:** isola backup, carga e risco de cada fonte; não duplica dado (e não cria cópia de PII);
e mantém o `pgvector`/embeddings locais ao RAG, que é onde a busca semântica precisa rodar.

**Regra canônica:**
- **App/sistema com ORM** (CRM, IFEM) ou **base de dados do Núcleo** → **database próprio**.
- **O RAG** → database próprio (`fnp_rag`) que **lê os demais via FDW**, nunca por cópia.

> Reconcilia o playbook de deploy ("1 sistema = 1 database") com a necessidade do RAG cruzar tudo:
> ele cruza por federação (FDW), não colocando todo mundo no mesmo banco.

### RDA-003 — Worker de ingestão no Droplet, detecção por cron+polling
**Decisão:** o `ingestor.py` roda no Droplet `fnp-web` (como container/cron), escrevendo no `fnp_rag`.
A detecção de mudança é por **cron diário + polling** (lista Drive/Spaces e compara SHA-256), **não
por webhook**.
**Motivo:** webhook do Google exige endpoint HTTPS público dedicado e renova o canal a cada 7 dias —
complexidade desnecessária para o volume da FNP. O cron é mais simples e suficiente. (O Droplet tem
IP público para servir as apps via Nginx, mas o worker não precisa receber chamadas de fora.)

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

### RDA-008 — Cruzamento entre bancos por postgres_fdw (read-only)
**Decisão:** o `fnp_rag` lê `fnp_sistema`, `ifem` e `nucleo_dados` por **`postgres_fdw`**, com
foreign tables em schemas espelho (`ext_fnp_sistema`, `ext_ifem`, `ext_nucleo`). O acesso usa um
role **só-leitura** em cada banco-fonte (`<fonte>_ro`); o text-to-SQL roda no `fnp_rag` e dá `JOIN`
entre as fontes como se fossem locais.
**Motivo:** os bancos estão no mesmo cluster DO Managed (mesmo host), então o FDW conecta sem rede
extra; lê sempre o dado fresco, sem ETL nem cópia de PII. É a forma de o RAG "cruzar dados de todos"
mantendo cada banco como dono do seu dado.
**Alternativa considerada:** federar na camada Django (uma conexão por banco, junção em Python) —
mais simples de configurar, mas cruzar duas fontes vira trabalho manual e mais lento. Fica como
plano B se o FDW der atrito no Managed.
**Dado público do Núcleo:** por ser público e só-leitura, pode opcionalmente ser **colocado** dentro
do `fnp_rag` (cópia analítica) se a leitura via FDW se mostrar lenta — começar por FDW e medir.

---

## Privacidade e fronteira de dados (LGPD)

O que é importante deixar claro — e ser honesto sobre — para a equipe e para a LGPD:

**Fica dentro da infra da FNP:**
- O assistente **não navega na internet** — responde **só** do acervo interno (Drive indexado +
  bancos da FNP). Não há busca na web.
- Documentos e dados ficam no DigitalOcean (Drive/Spaces + Postgres Managed). O **banco não é
  exposto** à internet; o acesso é só pela API autenticada (RDA-005).
- **Controle de acesso por documento** (`nivel_acesso`, RDA-007): conteúdo restrito não aparece
  para quem não pode.
- O RAG lê os outros bancos **só-leitura** (FDW) — não altera dado de ninguém.

**O que sai da FNP (e precisa ser tratado como operador de dados):**
- Para gerar **embeddings** e **respostas**, trechos de texto são enviados por HTTPS às APIs da
  **OpenAI** (embeddings) e da **Anthropic** (Claude). Elas são **operadores** de dados pessoais —
  exige base legal, contrato/DPA e, idealmente, evitar enviar PII.
- **Pendências de LGPD a resolver antes de indexar material sensível:** (a) detectar/mascarar PII
  no conteúdo antes de embedar (TODO no `ingestor.py`, RDA-007); (b) formalizar o tratamento com
  OpenAI/Anthropic. Alternativa a estudar: embedding local (sem sair da FNP).

> Resumo honesto: **não navega na web e os dados ficam na nossa infra — exceto** o texto enviado às
> APIs de IA (operadores). É isso que deve ir para a equipe, sem prometer "zero internet".

**Rumo a zero-egress:** o plano para o dado realmente não sair (embeddings locais + modelo de resposta
self-hosted) e os custos/requisitos de aquisição estão em [`RAG_SOBERANO.md`](RAG_SOBERANO.md). Visão
geral das melhorias em [`ROADMAP_RAG_V2.md`](ROADMAP_RAG_V2.md).

---

## Variáveis de ambiente necessárias

Ver `.env.example` na raiz do repositório.

---

## Custo estimado mensal (referência)

> ⚠️ Capacidade: o Droplet `fnp-web` e o cluster Postgres têm **previsão de upgrade** quando o RAG
> entrar (o runbook já aponta swap 2G → RAM 4GB). Dimensionamento a estudar.

| Componente | Custo |
|------------|-------|
| PostgreSQL Managed DO | ~$15/mês (a reavaliar no upgrade) |
| Droplet `fnp-web` (compartilhado: FNP + RAG + IFEM) | ~$6–12/mês (a reavaliar no upgrade) |
| DO Spaces (250GB) | ~$5/mês |
| OpenAI Embeddings (indexação) | ~$2–5 (só na indexação inicial) |
| Claude API (consultas) | ~$20–30/mês (estimativa 100 perguntas/dia) |
| **Total estimado** | **~$50–65/mês** (antes do upgrade) |
