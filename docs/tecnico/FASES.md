# Fases do projeto — fonte única de status

> **Esta é a fonte canônica do status do RAG.** Qualquer outra lista de fases no repositório
> (a visão da equipe em [`VISAO_GERAL_E_PROXIMOS_PASSOS.md`](../equipe/VISAO_GERAL_E_PROXIMOS_PASSOS.md)
> e o detalhamento técnico no `CLAUDE.md` interno do projeto) **deriva daqui**. Se algo divergir,
> vale este arquivo. Atualize **só aqui** ao concluir uma fase.

> Legenda: ✅ concluído · 🔄 em andamento · ⏳ a fazer.

| Fase (técnica) | O que entrega | Critério de conclusão | Status |
|---|---|---|---|
| **1. Extensões e schemas** | `vector`/`uuid-ossp`/`pgcrypto`; schemas `rag`/`app`/`admin` + schemas do Núcleo; `public` bloqueado | os schemas existem e as 3 extensões aparecem na consulta | 🔄 |
| **2. Roles e permissões** | `dba_admin`, `app_write`, `ingestor`, `nucleo_carga`, `readonly` | os roles aparecem e cada um conecta com o escopo certo | ⏳ |
| **3. Tabelas do `rag`** | `rag.documentos` (com `nivel_acesso` + índice HNSW), `arquivos_indexados`, `historico_perguntas`, `admin.*` | todas as tabelas aparecem na consulta | ⏳ |
| **4. DO Spaces** | bucket `fnp-knowledge-base` + prefixos; chaves; teste de upload | script de teste roda sem erro | ⏳ |
| **5. Worker de ingestão (local)** | documentos viram chunks + embedding em `rag.documentos` | chunks no banco com embedding não nulo e `nivel_acesso` preenchido | ⏳ |
| **6. Busca + roteador + resposta** | busca semântica (documento) **e** text-to-SQL (dado), resposta via Claude citando a fonte | perguntas reais retornam respostas coerentes com as fontes; ver [`AVALIACAO_RAG.md`](AVALIACAO_RAG.md) | ⏳ |
| **7. Deploy do worker (Droplet)** | Droplet sem IP público, cron diário de ingestão | `/var/log/fnp-ingestor.log` mostra execução bem-sucedida | ⏳ |

---

## Mapa para a visão da equipe

A tabela acima (técnica, 7 fases) é resumida para a equipe em 7 marcos (0–6) no
[`VISAO_GERAL`](../equipe/VISAO_GERAL_E_PROXIMOS_PASSOS.md). Correspondência:

| Equipe (0–6) | Técnica (1–7) |
|---|---|
| 0. Padrões definidos | (pré-projeto — playbooks e modelos) |
| 1. Banco e infra | 1, 2, 3, 4 |
| 2. Conectar o Drive | 5, 7 |
| 3. Organizar o acervo | (trabalho da equipe/Núcleo, em paralelo) |
| 4. Busca + respostas | 6 |
| 5. Interface | (camada Django, sobre a fase 6) |
| 6. RAG 100% | todas concluídas + acervo indexado |

> ⚠️ Não há um critério técnico de "text-to-SQL pronto" sem dado carregado: a fase 6 só fecha
> quando houver ao menos um dataset do Núcleo no banco para o roteador consultar.
