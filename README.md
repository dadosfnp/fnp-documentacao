# FNP — Base de Conhecimento e Infraestrutura de Dados

Repositório central de documentação técnica, scripts e guias da infraestrutura de dados da FNP (Frente Nacional de Prefeitas e Prefeitos).

---

## O que é este repositório

Este repositório contém:

- Documentação para a equipe sobre como organizar e compartilhar arquivos
- Explicação sobre o sistema de busca inteligente da FNP (Base de Conhecimento)
- Scripts SQL para criação e manutenção do banco de dados
- Scripts Python para ingestão, indexação e manutenção
- Documentação técnica da infraestrutura no DigitalOcean
- Documentação de cada sistema desenvolvido pela FNP

**Não contém** senhas, chaves de acesso ou dados sensíveis. Tudo isso fica em variáveis de ambiente (arquivo `.env`) que nunca são enviadas para o repositório.

---

## Estrutura do repositório

```
fnp-documentacao/
│
├── docs/
│   ├── equipe/          ← guias para toda a equipe (sem necessidade de acesso técnico)
│   ├── tecnico/         ← arquitetura, infraestrutura, decisões técnicas
│   ├── banco/           ← schemas, tabelas, roles e acesso ao banco
│   └── sistemas/        ← documentação de cada sistema da FNP
│
├── scripts/
│   ├── sql/             ← criação de banco, tabelas e roles
│   ├── python/          ← worker de ingestão e utilitários
│   └── shell/           ← configuração de servidores
│
├── .env.example         ← modelo de variáveis de ambiente (sem valores reais)
└── .gitignore           ← arquivos que nunca devem ser enviados ao repositório
```

---

## Por onde começar

| Você é... | Leia primeiro |
|-----------|---------------|
| Colega de equipe (analista, gestor, qualquer área) | [`docs/equipe/COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md`](docs/equipe/COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md) |
| Qualquer pessoa que vai salvar arquivos no Drive | [`docs/equipe/GUIA_ARQUIVOS.md`](docs/equipe/GUIA_ARQUIVOS.md) |
| Quer entender a estrutura de pastas do Drive | [`docs/equipe/ESTRUTURA_DRIVE.md`](docs/equipe/ESTRUTURA_DRIVE.md) |
| Desenvolvedor entrando no projeto | [`docs/tecnico/ARQUITETURA.md`](docs/tecnico/ARQUITETURA.md) |
| Precisa acessar o banco de dados | [`docs/banco/BANCO.md`](docs/banco/BANCO.md) |
| Quer documentar um novo sistema | [`docs/sistemas/TEMPLATE_SISTEMA.md`](docs/sistemas/TEMPLATE_SISTEMA.md) |

---

## Sistemas documentados

| Sistema | Arquivo |
|---------|---------|
| Sistema FNP (gestão institucional) | [`docs/sistemas/SISTEMA_FNP.md`](docs/sistemas/SISTEMA_FNP.md) |

---

## Contato técnico

Dúvidas sobre acesso, erros ou solicitações relacionadas a dados e sistemas:
**Pedro Ivo** — pedro.ivo@fnp.org.br
