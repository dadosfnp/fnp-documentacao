# Lições — fnp-documentacao

> Padrões aprendidos com correções do Pedro. Revisar no início de cada sessão.

## 2026-06-11 — Validar contra a infra REAL, não contra a doc

**O que aconteceu:** ao reconciliar a contradição "Docker vs. App Platform", segui o
`docs/sistemas/SISTEMA_FNP.md` ("App Platform / nunca Docker") e concluí o lado errado —
marquei Docker como "opcional" e o FNP como App Platform. A realidade (registrada em
`Subfinanciados/tasks/runbook-migracao-droplet.md`) é **Droplet `fnp-web` + Docker + Postgres
Managed, 1 database por sistema**. O `SISTEMA_FNP.md` é que estava desatualizado.

**Regra para mim:**
- Antes de documentar/decidir arquitetura, **procurar o registro de execução real** (runbooks,
  `tasks/`, `.env.example`, configs de deploy) — não confiar só nos docs descritivos, que divergem.
- Quando dois docs se contradizem, **o que descreve execução real ganha** do que descreve intenção.
- O playbook já avisava ("a documentação não é a realidade; valide o ambiente real primeiro") —
  aplicar isso literalmente, inclusive varrendo os outros repositórios em `Projetos-Git/`.

**Fatos da infra (fonte: runbook 2026-06-02), para não reperguntar:**
- Servidor: Droplet `fnp-web` (Ubuntu), Nginx, Docker padrão. FNP ainda systemd+venv (legado).
- Banco: Postgres Managed (porta 25060, SSL). **1 database por sistema, schema `public`**
  (`fnp_sistema`, `ifem`, `nucleo_dados`). Sem schema-por-sistema.
- RAG: database próprio `fnp_rag`; lê os outros por `postgres_fdw` read-only (decisão do Pedro,
  2026-06-11). Núcleo é database próprio, não schema do RAG.
- Upgrade de Droplet e banco **previsto** quando o RAG entrar — dimensionamento a estudar.
