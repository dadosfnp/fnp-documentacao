# FNP — Documentação e Padrões de TIC

Repositório central de **padrões, playbooks e modelos** da infraestrutura de TIC da FNP
(Frente Nacional de Prefeitas e Prefeitos).

---

## O que é este repositório

Reúne a documentação **transversal e reutilizável** da TIC da FNP:

- Playbooks de infraestrutura (subir um sistema novo; ingerir dados no banco)
- A documentação da **Base de Conhecimento (RAG)** — arquitetura, banco e guias da equipe
- Modelos para documentar sistemas e datasets

**Não contém** senhas, chaves de acesso ou dados sensíveis. Credenciais ficam exclusivamente em
variáveis de ambiente (`.env`) e arquivos de credencial (`*.json`), que **nunca** são enviados ao repositório.

---

## Estrutura do repositório

```
fnp-documentacao/
│
├── TIC/                                       ← padrões e playbooks de infraestrutura
│   ├── playbook-deploy-novo-sistema.md        ← receita para subir qualquer sistema novo
│   ├── playbook-ingestao-dados.md             ← como dados tabulares entram no banco da FNP
│   ├── template-dicionario-dataset.md         ← modelo de dicionário humano (1 por dataset)
│   ├── template-dicionario-dataset.yaml       ← versão estruturada que alimenta o text-to-SQL
│   └── inventario.md                          ← inventário TIC (sistemas, portas, schemas, datasets)
│
├── docs/
│   ├── equipe/                                ← guias para a equipe (linguagem acessível)
│   │   ├── GUIA_DA_EQUIPE.md                  ← guia único: onde salvar, como nomear, como entregar dados (mandar à equipe)
│   │   ├── VISAO_GERAL_E_PROXIMOS_PASSOS.md   ← apresentação: desenho da arquitetura + próximos passos
│   │   ├── COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md  ← o porquê (linguagem acessível)
│   │   └── COMO_DOCUMENTAR_SEUS_DADOS.md      ← aprofundamento p/ o Núcleo (ficha de dados)
│   ├── tecnico/
│   │   ├── ARQUITETURA.md                     ← arquitetura do RAG (componentes, fluxos, RDAs)
│   │   ├── FASES.md                           ← fonte única de status das fases do projeto
│   │   ├── AVALIACAO_RAG.md                   ← método e gabarito para medir o RAG antes do "100%"
│   │   ├── ROADMAP_RAG_V2.md                  ← plano futuro: melhorias de maior alavancagem
│   │   └── RAG_SOBERANO.md                    ← plano futuro: zero-egress (local) + custos/aquisição
│   ├── banco/
│   │   └── BANCO.md                           ← schemas, roles e tabelas do PostgreSQL
│   └── sistemas/
│       ├── TEMPLATE_SISTEMA.md                ← modelo para documentar um novo sistema
│       └── SISTEMA_FNP.md                     ← documentação do Sistema FNP (CRM)
│
├── scripts/
│   ├── sql/01_setup_banco.sql                 ← cria extensões, schemas, roles e tabelas
│   ├── python/ingestor.py                     ← worker de ingestão (Spaces/Drive → banco)
│   └── shell/setup_worker.sh                  ← provisiona o Droplet de ingestão
│
├── .env.example                               ← template de variáveis de ambiente (sem valores)
├── .gitignore                                 ← ignora .env, *.json e o CLAUDE.md interno
└── README.md
```

---

## Por onde começar

| Você quer... | Leia |
|--------------|------|
| **(Equipe)** Entender o projeto, o desenho e os próximos passos | [`docs/equipe/VISAO_GERAL_E_PROXIMOS_PASSOS.md`](docs/equipe/VISAO_GERAL_E_PROXIMOS_PASSOS.md) |
| Subir um novo sistema na infra (Droplet + Postgres) | [`TIC/playbook-deploy-novo-sistema.md`](TIC/playbook-deploy-novo-sistema.md) |
| **(Equipe)** Aprender a mapear os dados que você domina | [`docs/equipe/COMO_DOCUMENTAR_SEUS_DADOS.md`](docs/equipe/COMO_DOCUMENTAR_SEUS_DADOS.md) |
| Entregar dados (Excel/Parquet do R) pro banco da FNP | [`TIC/playbook-ingestao-dados.md`](TIC/playbook-ingestao-dados.md) |
| Documentar um dataset do Núcleo de Dados | [`TIC/template-dicionario-dataset.md`](TIC/template-dicionario-dataset.md) |
| Documentar um novo sistema da FNP | [`docs/sistemas/TEMPLATE_SISTEMA.md`](docs/sistemas/TEMPLATE_SISTEMA.md) |

---

## Contato técnico

Dúvidas sobre acesso, infraestrutura ou padrões de TIC:
**Pedro Machado** — pedro.machado@fnp.org.br
