# Roadmap RAG v2 — onde modernizar (sem over-engineering)

> **Status: PLANO FUTURO / proposta.** Melhorias de maior alavancagem para o RAG, calibradas para uma
> TIC de 1 pessoa: fundação chata e estável + camada de qualidade moderna + soberania + avaliação
> automática. O que faz durar não é a tecnologia mais nova — é não apodrecer em silêncio.

## O que MANTER (já é moderno e durável)
- **Postgres + pgvector como base única.** Não trocar por vector DB dedicado (Pinecone/Weaviate/Qdrant)
  neste volume — seria mais um sistema para manter, sem ganho real.
- **Docker + DO + 1 database por sistema + FDW + catálogo.** Arquitetura sólida e auditável.
- **Separar documento/dado (roteador) e ter conjunto de avaliação.** Instinto certo.

## Onde modernizar (ordem de alavancagem)

### ① Qualidade de retrieval — o maior salto percebido
O chunking de 800 chars + busca vetorial pura é o estado da arte de ~2023. Combo atual:
- **Contextual Retrieval** (técnica da Anthropic): o Claude escreve 1 frase de contexto por chunk antes
  de embedar ("trecho da ata da 89ª reunião sobre X"). Reduz falha de busca em ~50%.
- **Busca híbrida** (semântica + palavra-chave/BM25) — no próprio Postgres (`tsvector` ou extensão
  `pg_search`/ParadeDB).
- **Reranking** com cross-encoder (bge-reranker-v2-m3, local) reordenando o top-K. Barato, grande ganho
  de precisão.

### ② Soberania de dados — ver [`RAG_SOBERANO.md`](RAG_SOBERANO.md)
- **Embeddings locais** (BGE-M3): tira o egress da indexação/busca, melhora PT-BR, custa pouco. É também
  decisão de fundação (muda a dimensão do vetor) → fazer cedo.
- **PII**: usar **Presidio** (Microsoft, open-source, suporta PT) para detectar/mascarar antes de indexar
  — em vez de hand-rollar o TODO do `ingestor.py` (RDA-007).
- Geração self-hosted: plano e custos em [`RAG_SOBERANO.md`](RAG_SOBERANO.md).

### ③ Observabilidade + avaliação automática — o que faz DURAR
RAG apodrece em silêncio sem isso.
- **Langfuse** (open-source, self-hospedável — LGPD-friendly): rastreia cada pergunta, o que recuperou,
  custo e latência. Você enxerga o sistema.
- **Ragas** ou golden-set rodando no CI: toda mudança roda as ~20 perguntas e mede regressão. O
  [`AVALIACAO_RAG.md`](AVALIACAO_RAG.md) vira teste automático, não planilha manual.

### ④ Text-to-SQL com segurança
- Role read-only (já temos) + catálogo + few-shot de queries boas + `LIMIT` automático + validar a query
  antes de rodar.
- Para o Núcleo (dado público): considerar **DuckDB sobre os Parquet** (já usado no IFEM) — rápido,
  analítico, sem tocar produção; complemento/alternativa ao FDW para esse caso.

## O que NÃO fazer (anti-padrões que matam projeto de 1 pessoa)
- Não adotar framework pesado por moda (LangChain inteiro). Usar peças maduras e finas (LlamaIndex/
  Haystack) **só** onde reduzem código próprio.
- Não trocar Postgres por vector DB dedicado.
- Não construir semantic layer (Cube/dbt metrics) agora — certo no futuro, over-engineering hoje.

## Sequência sugerida
1. **Embeddings locais** (fundação — define a coluna do vetor).
2. Indexar já com **contextual retrieval + híbrido + rerank**.
3. **Langfuse + golden-set no CI** antes de abrir para a equipe.
4. **Presidio** no pipeline antes de qualquer documento sensível.
5. Text-to-SQL com guardrails; DuckDB para o Núcleo.

> **Se fizer só uma coisa diferente:** embeddings locais + contextual retrieval. Resolve qualidade *e*
> soberania de uma vez, e é decisão de fundação que custa caro mudar depois.
