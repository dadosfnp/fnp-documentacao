# FNP — Documentação e Padrões de TIC

Repositório central de **padrões, playbooks e modelos** da infraestrutura de TIC da FNP
(Frente Nacional de Prefeitas e Prefeitos).

---

## O que é este repositório

Reúne a documentação **transversal e reutilizável** da TIC — o que vale para qualquer sistema
da FNP, independente de projeto específico:

- Playbook replicável para subir um novo sistema na infraestrutura própria (Droplet + PostgreSQL)
- Modelo padrão para documentar cada sistema

**Não contém** senhas, chaves de acesso ou dados sensíveis. Credenciais ficam exclusivamente em
variáveis de ambiente (`.env`), que nunca são enviadas ao repositório.

> A documentação de sistemas específicos (ex.: base de conhecimento / RAG) será adicionada aqui
> conforme cada projeto for validado.

---

## Estrutura do repositório

```
fnp-documentacao/
│
├── TIC/
│   └── playbook-deploy-novo-sistema.md   ← receita replicável para subir qualquer sistema novo
│
├── docs/
│   └── sistemas/
│       └── TEMPLATE_SISTEMA.md            ← modelo para documentar um novo sistema
│
├── .gitignore
└── README.md
```

---

## Por onde começar

| Você quer... | Leia |
|--------------|------|
| Subir um novo sistema na infra (Droplet + Postgres) | [`TIC/playbook-deploy-novo-sistema.md`](TIC/playbook-deploy-novo-sistema.md) |
| Documentar um novo sistema da FNP | [`docs/sistemas/TEMPLATE_SISTEMA.md`](docs/sistemas/TEMPLATE_SISTEMA.md) |

---

## Contato técnico

Dúvidas sobre acesso, infraestrutura ou padrões de TIC:
**Pedro Machado** — pedro.machado@fnp.org.br
