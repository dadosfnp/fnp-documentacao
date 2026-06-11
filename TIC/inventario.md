# Inventário TIC — FNP

> Fonte única do que existe na infraestrutura: sistemas, portas, bancos/schemas, datasets e status.
> Vários checklists (deploy e ingestão) mandam "atualizar o inventário TIC" — é **este** arquivo.
> Atualize ao subir um sistema, criar um schema/database ou carregar um dataset.

_Última atualização: 2026-06-11._

---

## Infra base

| Recurso | Detalhe |
|---|---|
| Servidor | **Droplet `fnp-web`** (DO, Ubuntu) — Nginx (TLS) na frente; **upgrade previsto** (swap 2G → RAM 4GB quando o RAG entrar) |
| Banco | **PostgreSQL Managed** (DO), porta 25060, SSL — **upgrade a estudar** |
| Runtime padrão | **Docker** (Compose + Nginx reverse-proxy). FNP ainda em systemd+venv (legado, a migrar) |

## Sistemas (1 database por sistema)

| Sistema | Runtime | Porta | Database | Domínio | LGPD | Status |
|---|---|---|---|---|---|---|
| **Sistema FNP** (CRM) | systemd+venv no `fnp-web` (migrando p/ Docker) | 8001 | `fnp_sistema` | `sistema.fnp.org.br` | nível 2 | produção |
| **IFEM** (Subfinanciados) | Docker no `fnp-web` | 8003 | `ifem` | a publicar | a definir | no ar (túnel SSH) |
| **RAG** (Base de Conhecimento) | Docker no `fnp-web` + worker cron | 8002 | `fnp_rag` (+ FDW p/ os outros) | a definir | herda RDA-007 | em construção |
| _(próximos)_ | Docker no `fnp-web` | 8004+ | 1 sistema = 1 database | | | |

> Portas: FNP=8001, RAG=8002, IFEM=8003, próximos=8004+.

---

## Bancos PostgreSQL (DO Managed — 1 db por sistema)

| Database | Conteúdo | Escreve | Lê |
|---|---|---|---|
| `fnp_sistema` | CRM (municípios, pessoas, eventos…) | FNP (`admin_sistema`) | `fnp_ro` (FDW do RAG) |
| `ifem` | dados do IFEM/Subfinanciados | IFEM (`ifem_app`) | `ifem_ro` (FDW do RAG) |
| `nucleo_dados` | datasets do Núcleo (schemas `economia`, `social`…) | `nucleo_carga` | `nucleo_ro` (FDW do RAG) |
| `fnp_rag` | RAG: `rag` (embeddings/catálogo) + `admin` | `ingestor`, `app_write` | `readonly` |

> Regra (RDA-002): app/sistema/Núcleo = **database próprio**; o `fnp_rag` lê os demais por
> **`postgres_fdw`** read-only (RDA-008), sem copiar dado.

---

## Datasets do Núcleo de Dados (database `nucleo_dados`)

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
