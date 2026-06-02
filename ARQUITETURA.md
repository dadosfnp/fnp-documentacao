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
└── PostgreSQL gerenciado
    ├── schema: rag      ← embeddings, histórico
    ├── schema: app      ← dados FNP (municípios etc.)
    └── schema: admin    ← usuários, audit log
```

---

## Fluxo de ingestão

```
Arquivo novo/modificado no Drive ou Spaces
    │
    ▼
Worker detecta mudança (webhook Drive ou cron Spaces)
    │
    ▼
Extrai texto (PyPDF / python-docx / python-pptx / pandas)
    │
    ▼
Divide em chunks (~800 chars, overlap 100)
    │
    ▼
Gera embedding via OpenAI ada-002
    │
    ▼
Salva em rag.documentos (conteudo + embedding + metadata)
    │
    ▼
Atualiza rag.arquivos_indexados (hash + timestamp)
```

---

## Fluxo de consulta

```
Usuário faz pergunta na interface
    │
    ▼
Django API recebe POST /api/perguntar/
    │
    ▼
Gera embedding da pergunta
    │
    ▼
Busca top-6 chunks por similaridade coseno (pgvector)
    │
    ▼
Monta prompt: system prompt + chunks + pergunta
    │
    ▼
Claude Sonnet gera resposta citando as fontes
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
**Decisão:** schemas `rag`, `app`, `admin` no mesmo banco DO.
**Motivo:** simplifica operação, backup e custo. Isolamento via roles do PostgreSQL.

### RDA-003 — Worker sem IP público
**Decisão:** Droplet do worker fica só na VPC interna, sem acesso externo.
**Motivo:** o worker só precisa falar com o banco e o Spaces, ambos dentro da VPC.

### RDA-004 — Reindexação por hash, não por data
**Decisão:** só reindexar arquivo se o SHA-256 mudou.
**Motivo:** economiza custo de embedding (OpenAI cobra por token).

### RDA-005 — Acesso à API apenas via autenticação Django
**Decisão:** endpoint `/api/perguntar/` exige login. Colegas acessam via interface web, não diretamente ao banco.
**Motivo:** banco fica inacessível externamente. API é a única entrada controlada.

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
