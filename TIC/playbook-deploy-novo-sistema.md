# Playbook — Subir um novo sistema na infra da FNP

> **Propósito:** receita padrão e replicável para colocar **qualquer** novo sistema (Django/FastAPI)
> na infraestrutura própria da FNP (Droplet DigitalOcean + PostgreSQL Managed), sem quebrar o que já roda.
> **Natureza:** documento **global e genérico** — serve de **modelo para todo app** (Sistema FNP, RAG e futuros).
> **Como usar:** siga as fases em ordem. Cada sistema novo repete este mesmo fluxo.

---

## 0. Princípios gerais (valem para tudo)

1. **Reconhecer antes de decidir.** A documentação diverge da realidade — valide o ambiente real (read-only) antes de planejar.
2. **Não tocar no que está em produção.** Sistema novo é greenfield: monte e valide em paralelo; só vire o tráfego no fim.
3. **Privilégio mínimo.** Cada sistema tem credenciais próprias com o menor escopo possível.
4. **Segredos nunca no git.** `.env` e bancos locais fora do versionamento; segredos em cofre.
5. **Tudo versionado e reproduzível.** Imagem Docker, migrations, e documentação (ADR + runbook + dicionário).
6. **Validar sem publicar.** Use túnel SSH para revisar antes de expor à internet.

---

## 1. Pré-flight — reconhecimento (read-only)

Antes de escrever qualquer coisa, levante (e anote num runbook):

- **Droplet:** SO, RAM/disco livres, **swap** (criar 2G se não houver), serviços e portas em uso, se há Docker.
- **Banco Managed:** versão do PostgreSQL, databases/roles existentes, qual role pode criar db/role (`doadmin`).
- **Rede:** o IP do droplet está na allowlist do banco? (testes de DB rodam do droplet, não da máquina local).
- **Padrões reais já implantados** (não os documentados): como os outros sistemas rodam, autenticam, servem estáticos.

> ⚠️ Aprendizado: o doc pode dizer "Docker + schemas" enquanto a realidade é "systemd+venv + 1 database por sistema".
> Decida sempre a partir do que existe.

---

## 2. Banco de dados — 1 sistema = 1 database + 1 role

Com a credencial admin (`doadmin`), criar **uma única vez**:

```sql
CREATE ROLE <sys>_app LOGIN PASSWORD '<senha-forte-gerada-no-servidor>';
CREATE DATABASE <sys> OWNER <sys>_app;
REVOKE ALL ON DATABASE <sys> FROM PUBLIC;
GRANT ALL ON DATABASE <sys> TO <sys>_app;
-- conectando no database <sys>:
GRANT ALL ON SCHEMA public TO <sys>_app;
ALTER SCHEMA public OWNER TO <sys>_app;   -- garante que o migrate consiga criar tabelas
```

- A **senha do role** é gerada **no servidor** (`openssl rand -hex 24`) — nunca trafega por chat/log.
- A `DATABASE_URL` final usa `...?sslmode=require` e vai **só no `.env` do droplet** (e no cofre).
- O sistema **nunca** usa o `doadmin` em runtime — só o role de privilégio mínimo.

---

## 3. Segredos e credenciais

- `.gitignore` desde o commit zero: `.env`, `*.sqlite3`, dumps, `__pycache__/`.
- `.env.example` versionado com as chaves (sem valores). `DATABASE_URL` **comentada** por padrão (local cai em SQLite).
- Cada segredo vive em **2 lugares**: no `.env` do servidor (uso) e no **cofre Bitwarden** (backup/recuperação).
- Se um segredo já vazou no histórico do git (ex.: `.env` versionado por engano): **rotacionar** a chave.
- `SECRET_KEY` do Django é **nova por ambiente** — a de produção nunca é a mesma do repo.

---

## 4. Containerização (padrão Docker para todos)

Cada sistema entrega, no próprio repo:

- **`Dockerfile`** — base slim, **usuário não-root**, deps via `requirements.txt` (cache de layer), `EXPOSE` da porta interna.
- **`entrypoint.sh`** — `migrate` (opcional via env) → `collectstatic` → `gunicorn`/`uvicorn`. **Invocar via `sh`** (não depender de bit +x).
- **`docker-compose.yml`** — `env_file: .env`, **bind em `127.0.0.1:<porta>`** (nunca porta pública direta), `healthcheck`, volume para uploads/media.
- **`.dockerignore`** — exclui `.env`, banco local, `staticfiles/`, dumps, `tasks/`.
- **`.gitattributes`** — `*.sh text eol=lf` (senão CRLF do Windows quebra no container Linux).

Portas internas por sistema (convenção FNP): FNP=8001, RAG=8002, IFEM=8003, próximos=8004+.

---

## 5. Migração de dados (quando há dados a trazer)

1. **Dump da origem:** `dumpdata <app> --natural-primary` → JSON. (gerar via a própria imagem evita depender do Python local).
2. **Criar estrutura:** `migrate` no database novo.
3. **Carregar:** `loaddata <dump>.json` (montar o dump como volume; ele fica fora da imagem).
4. **Validar contagens** origem × destino, tabela a tabela. Só seguir se baterem.

---

## 6. Git e deploy

- **Branch dedicada** (`infra/...`, `feat/...`); commits **semânticos e coesos**; nunca direto na `main`.
- **Droplet clona via Deploy Key SSH read-only**, criada por repo (escopo mínimo):
  ```bash
  ssh-keygen -t ed25519 -f /root/.ssh/id_<sys>_deploy
  # adicionar a .pub em GitHub → repo → Settings → Deploy keys (sem write access)
  ```
- O `.env` do servidor é criado **manualmente no droplet** (não vem do clone).

---

## 7. Validação sem publicar (túnel SSH)

```bash
ssh -L <porta>:localhost:<porta> root@<ip-do-droplet>
# abrir http://localhost:<porta>
```
"Connection refused" no túnel = container ainda não está no ar (normal antes do `up`).

---

## 8. Publicação (só depois de aprovado)

- **Nginx (host):** novo `server`/`location` com `proxy_pass http://127.0.0.1:<porta>`; servir `/static/` e `/media/`.
- **TLS:** Let's Encrypt (certbot) com renovação automática.
- **Cloudflare:** WAF/DDoS + esconder IP; criar o subdomínio (ex.: `<sys>.fnp.org.br`).
- **Domínio:** apontar DNS no registro.br/Cloudflare.
- **Só então** desligar o ambiente antigo (ex.: Render).

---

## 9. Documentação obrigatória (todo sistema)

| Artefato | Onde | Para quê |
|---|---|---|
| **ADR** (decisões) | repo `tasks/` ou pasta TIC | registrar o porquê de cada escolha de arquitetura |
| **Runbook** (append-only) | repo `tasks/` | o que foi executado, comandos e resultados |
| **Dicionário de dados** | repo `docs/` (gerado dos models) + índice na TIC | manutenção/reciclagem de dados |
| **README** | repo | como rodar (Docker local + produção) |

> O **dicionário de dados é gerado automaticamente a partir dos models** (introspection), nunca à mão —
> assim nunca diverge do banco e segue o mesmo padrão de colunas em todos os sistemas. Ver `dicionario-dados-padrao.md`.

---

## 10. Armadilhas conhecidas (já nos pegaram)

- **Conflito de migrations** (duas `0003` em branches diferentes) → `python manage.py makemigrations --merge`.
- **Imagem Docker desatualizada após `git pull`** → **rebuildar**: o código entra por `COPY` no build, não é montado.
- **Bind mount de escrita** com usuário não-root → falha de permissão; usar stdout ou `--user root`.
- **Docker `-v` no git-bash/Windows** → prefixar `MSYS_NO_PATHCONV=1`.
- **Allowlist do banco** → testes de conexão só funcionam a partir do droplet, não da máquina local.

---

## 11. Checklist final (Definition of Done)

- [ ] Database + role dedicados criados; conexão testada.
- [ ] Imagem builda; container **healthy**; HTTP 200.
- [ ] Dados migrados e **contagens validadas**.
- [ ] Segredos no cofre; nenhum segredo no git.
- [ ] ADR + runbook + README + dicionário de dados atualizados.
- [ ] Ambiente antigo desligado (se aplicável).
- [ ] Inventário TIC atualizado (sistema, porta, database, status).

---

## 12. Resumo dos aprendizados (uma frase cada)

- **Recon antes de decidir** — a documentação não é a realidade; valide o ambiente real primeiro.
- **1 database + 1 role por sistema** — isolamento e privilégio mínimo.
- **Segredos nunca no git** — sempre no cofre (Bitwarden), nunca em chat/log/commit.
- **Docker padroniza todos** — mesma forma de buildar, rodar e servir em qualquer sistema.
- **Valide por túnel antes de publicar** — revise via SSH antes de expor à internet.
- **Documente os três eixos** — decisão (ADR) + execução (runbook) + schema (dicionário gerado).
