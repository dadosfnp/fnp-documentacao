# Inventário TIC — FNP

> Fonte única do que existe na infraestrutura: sistemas, portas, bancos/schemas, datasets e status.
> Vários checklists (deploy e ingestão) mandam "atualizar o inventário TIC" — é **este** arquivo.
> Atualize ao subir um sistema, criar um schema/database ou carregar um dataset.

_Última atualização: 2026-06-11._

---

## Sistemas

| Sistema | Runtime | Porta interna | Database | Domínio | LGPD | Status |
|---|---|---|---|---|---|---|
| **Sistema FNP** (CRM) | App Platform / systemd+venv (sem Docker) | 8001 | `fnp` | `sistema.fnp.org.br` | nível 2 | produção |
| **RAG** (Base de Conhecimento) | Django (API) + Droplet worker `systemd`+cron | 8002 | banco único (schemas abaixo) | a definir | herda RDA-007 | em construção |
| **IFEM** | a definir | 8003 | `ifem` (database próprio) | a definir | a definir | futuro |
| _(próximos)_ | | 8004+ | 1 sistema = 1 database | | | |

> Convenção de portas (ver [`playbook-deploy-novo-sistema.md`](playbook-deploy-novo-sistema.md)):
> FNP=8001, RAG=8002, IFEM=8003, próximos=8004+.

---

## Banco PostgreSQL (DO Managed) — banco único

| Schema | Conteúdo | Quem escreve | Quem lê |
|---|---|---|---|
| `rag` | embeddings, catálogo, histórico de perguntas | `ingestor` | `app_write`, `readonly` |
| `app` | dados do Sistema FNP espelhados/integrados | `app_write` | `readonly` |
| `admin` | usuários do chat, audit log | `dba_admin` / `app_write` | — |
| `economia` | datasets do Núcleo (tema economia) | `nucleo_carga` | `app_write`, `readonly` |
| `social` | datasets do Núcleo (tema social) | `nucleo_carga` | `app_write`, `readonly` |
| `eleitoral` | datasets do Núcleo (tema eleitoral) | `nucleo_carga` | `app_write`, `readonly` |

> Regra (RDA-002): dado tabular consultável = **schema** aqui; app com ORM próprio = **database** dedicado.

---

## Datasets do Núcleo de Dados

| Dataset | Schema.tabela | Dono | Última versão | Dicionário | Status |
|---|---|---|---|---|---|
| _(nenhum carregado ainda)_ | | | | | |

> Ao carregar um dataset: preencher a linha acima + os dois dicionários (`.md` e `.yaml`),
> seguindo o [`playbook-ingestao-dados.md`](playbook-ingestao-dados.md).

---

## Storage — DO Spaces

| Bucket | Região | Acesso | Uso |
|---|---|---|---|
| `fnp-knowledge-base` | nyc3 | privado | documentos, sistemas/, dados/ (Parquet arquivado) |
