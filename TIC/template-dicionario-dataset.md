# Dicionário de dados — [Nome do Dataset]

> Copie este arquivo para `<slug>_AAAA-MM-DD.dicionario.md` e preencha **todas** as seções.
> Ele acompanha o arquivo de dados na entrega (ver [`playbook-ingestao-dados.md`](playbook-ingestao-dados.md))
> e é **a fonte que o RAG indexa** para saber que este dataset existe, onde está e o que ele responde.
> Campo em branco = o RAG não sabe responder sobre aquilo. Preencha com capricho.
>
> 🤖 **Versão para a máquina:** existe um espelho estruturado deste dicionário em
> [`template-dicionario-dataset.yaml`](template-dicionario-dataset.yaml). É o `.yaml` que o
> **text-to-SQL** lê para montar a query (tabela, colunas, tipos, chave). Este `.md` é para humano;
> o `.yaml`, para a máquina — os dois precisam ficar em sincronia.

---

## 1. Identificação

| Campo | Valor |
|---|---|
| Nome do dataset | *ex.: PIB municipal* |
| Slug (nome técnico) | *ex.: `pib_municipal` — snake_case, sem acento* |
| Versão (data de referência) | *AAAA-MM-DD* |
| Responsável (dono do dado) | *Nome — e-mail* |
| Equipe | Núcleo de Dados |
| Periodicidade de atualização | *anual / mensal / eventual* |

---

## 2. O que é e para que serve

*2 a 3 frases: o que este dataset contém e para que a FNP usa.*

**Exemplo:** Contém o Produto Interno Bruto de cada município brasileiro por ano, na série oficial do IBGE.
A FNP usa para comparar o porte econômico dos municípios filiados e embasar estudos.

---

## 3. Onde está fisicamente

| Campo | Valor |
|---|---|
| Entregue no Drive | *ex.: `Planilhas e Dados/pib_municipal/`* (equipe) |
| Arquivo arquivado (Spaces) | *ex.: `dados/nucleo/pib_municipal/pib_municipal_2026-06-11.parquet`* (TIC) |
| Database | `nucleo_dados` |
| Schema.tabela | *ex.: `economia.pib_municipal`* (schema por tema dentro do `nucleo_dados`) |
| Formato | Parquet / Excel |

---

## 4. Grão e cobertura

| Campo | Valor |
|---|---|
| **Grão** (1 linha = ?) | *ex.: 1 município por ano* |
| Período coberto | *ex.: 2010 a 2024* |
| Abrangência geográfica | *ex.: todos os 5.570 municípios* |
| Nº aproximado de linhas | *ex.: ~78.000* |

---

## 5. Dicionário de colunas

> Liste **todas** as colunas, na ordem do arquivo. Marque a(s) que compõem a chave.

| Coluna | Tipo | Unidade / Formato | Chave? | Descrição | Exemplo |
|---|---|---|---|---|---|
| `cod_municipio` | inteiro | código IBGE 7 dígitos | ✅ | Identificador oficial do município | `3550308` |
| `ano` | inteiro | AAAA | ✅ | Ano de referência | `2024` |
| `nome_municipio` | texto | — | | Nome do município | `São Paulo` |
| `uf` | texto | sigla 2 letras | | Unidade da federação | `SP` |
| `pib` | decimal | R$ mil correntes | | PIB total do ano | `829840000` |
| `...` | | | | | |

---

## 6. Chave e unicidade

- **Chave primária:** *ex.: (`cod_municipio`, `ano`)*
- **Como detectar duplicata:** *ex.: não pode haver duas linhas com o mesmo município e ano*
- **Estratégia de carga:** *substituição total (TRUNCATE+COPY) / upsert pela chave*

---

## 7. Origem e tratamento

| Campo | Valor |
|---|---|
| Fonte pública original | *ex.: IBGE — SIDRA tabela 5938* |
| Link da fonte | *URL* |
| Tratamento aplicado (R) | *ex.: filtra anos < 2010, converte PIB para mil reais, padroniza UF* |
| Script de extração | *ex.: `R/extrai_pib.R` no repo do Núcleo* |

---

## 8. Para o RAG — roteamento e busca

> Estas seções são o que tornam o RAG **assertivo**. Pense em como a equipe pergunta de verdade.

**Assuntos / tags:** *ex.: economia, PIB, município, IBGE, indicadores econômicos*

**Perguntas que este dataset responde:**
- *ex.: Qual o PIB do município X em 2024?*
- *ex.: Quais os 10 municípios filiados de maior PIB?*
- *ex.: Como o PIB de X evoluiu nos últimos 10 anos?*

**O que este dataset NÃO responde** *(evita o RAG citar a fonte errada)*:
- *ex.: PIB per capita (não está aqui — ver dataset `populacao`)*

---

## 9. Histórico de versões

| Data de referência | Mudança | Responsável |
|---|---|---|
| *AAAA-MM-DD* | *ex.: primeira carga* | *Nome* |
| *AAAA-MM-DD* | *ex.: incluído ano de 2024* | *Nome* |
