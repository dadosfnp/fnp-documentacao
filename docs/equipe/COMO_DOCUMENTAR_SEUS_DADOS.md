# Como documentar os dados que você domina

> **Para quem é este guia:** a equipe do Núcleo de Dados — você que conhece os dados de perto
> (extrai, trata no R, mantém as planilhas), mas **não precisa mexer no banco**.
> **O que você faz:** entrega o dado **bem mapeado**. Quem coloca no banco da FNP é o Pedro.
> **Por que isso importa:** o que você documenta vira a "ficha" que o assistente de busca (RAG) usa
> para achar a informação e **dizer de onde ela veio**. Dado sem ficha, ninguém encontra depois.

> 📌 Este guia é só para **dados tabulares** (planilhas/Parquet de indicadores, séries, bases que você trata no R).
> Para **documentos comuns** — apresentações, atas, PDFs — o caminho é mais simples e está em
> [`GUIA_DA_EQUIPE.md`](GUIA_DA_EQUIPE.md). Em dúvida sobre o desenho todo? → [`VISAO_GERAL_E_PROXIMOS_PASSOS.md`](VISAO_GERAL_E_PROXIMOS_PASSOS.md).

---

## A ideia em uma frase

> Para cada conjunto de dados que você mantém, você entrega **duas coisas**:
> **(1)** o arquivo com os dados e **(2)** uma ficha que explica o que tem dentro dele.

Essa ficha é o **dicionário**. É ela que faz seu trabalho render: depois de documentado uma vez,
qualquer pessoa da FNP consegue perguntar sobre aquele dado e receber a resposta certa, com a fonte.

---

## Parte 1 — O arquivo de dados

### Prefira Parquet (o que o R já gera)
Se você trata no R, exporte em **Parquet**. É mais leve e não estraga os números nem as datas:

```r
arrow::write_parquet(seu_dataframe, "pib_municipal_2026-06-11.parquet")
```

Se o dado só existe em **Excel**, tudo bem — mas siga as regras abaixo, senão ele "quebra" na hora de subir.

### Regras de ouro do arquivo (vale pra Excel e pra Parquet)

✅ **Uma tabela só, uma aba só.** Nada de várias abas no mesmo arquivo. Um arquivo = uma tabela.
✅ **A primeira linha é o cabeçalho** (os nomes das colunas) e **só ela**. Nada de título, logo ou data acima.
✅ **Nomes de coluna simples:** sem acento, sem espaço, em minúsculo — use `_`. Ex.: `cod_municipio`, `pib`.
✅ **Uma informação por coluna.** Não junte "São Paulo - SP" numa coluna só; separe `municipio` e `uf`.
✅ **Número é número.** Sem `R$`, sem ponto de milhar, sem texto no meio. `829840` e não `R$ 829.840`.
✅ **Data num formato só:** `AAAA-MM-DD` (ex.: `2026-06-11`). Nunca misture `01/02/26` com `2026-02-01`.

🚫 **Evite:** células mescladas, cores como significado, totais no meio da tabela, linhas em branco separando blocos.

> 💡 Regra mental: a tabela tem que poder ser lida "de cima a baixo" como uma lista, sem você precisar explicar o layout.

---

## Parte 2 — A ficha (dicionário)

Para cada conjunto de dados, copie o modelo **`template-dicionario-dataset.md`**
e preencha. Não precisa entender de banco — precisa explicar **o que você já sabe** sobre o dado.

Abaixo, os 4 conceitos que mais confundem. Se você acertar esses, o resto é fácil.

### 1. O grão — "uma linha é o quê?"
A pergunta mais importante. Complete a frase: **"cada linha do meu dado representa um(a) ___ por ___"**.

- ✅ *"Cada linha é um município por ano."*
- ✅ *"Cada linha é um aluno matriculado."*
- ❌ "Sei lá, são os dados do IBGE." ← isso não diz o grão.

### 2. A chave — "o que não pode repetir?"
É a combinação de colunas que **identifica a linha sem ambiguidade**.

- Se o grão é "município por ano", a chave é (`cod_municipio`, `ano`) — **não pode** haver duas linhas iguais nisso.
- Pense: "se eu encontrasse duas linhas com o mesmo ___ e ___, isso seria um erro?". O que você preencher aí é a chave.

### 3. As colunas — "o que é cada uma?"
Liste **todas** as colunas, na ordem do arquivo. Para cada uma, diga em palavras simples:

| Coluna | O que é (em português de gente) | Exemplo |
|---|---|---|
| `cod_municipio` | Código do IBGE do município, 7 dígitos | `3550308` |
| `ano` | Ano a que o dado se refere | `2024` |
| `pib` | PIB total do município, em **mil reais** | `829840` |

> ⚠️ **Sempre diga a unidade.** "PIB" não basta — é em reais? Mil reais? Milhões? Essa é a dúvida nº 1 de quem usa o dado depois.

### 4. O que o dado NÃO responde
Tão importante quanto o que ele responde. Evita que o assistente cite seu dado pra coisa errada.

- *"Este dado tem o PIB total, mas **não** tem PIB per capita."*
- *"Tem matrículas, mas **não** tem frequência nem nota."*

---

## Parte 3 — Ajude a busca a te encontrar

No fim da ficha tem uma seção "Para o RAG". É onde você pensa **como as pessoas perguntam de verdade**.
Escreva as perguntas reais que esse dado consegue responder:

- *"Qual o PIB de São Paulo em 2024?"*
- *"Quais os 10 municípios filiados de maior PIB?"*
- *"Como o PIB de Recife evoluiu nos últimos 10 anos?"*

Quanto mais perguntas reais você listar, mais o assistente acerta.

---

## Exemplo: ficha ruim × ficha boa

**❌ Ruim**
> "Planilha do PIB. Tem os municípios e os valores. Atualizo quando sai o IBGE."

Ninguém sabe o grão, a unidade, o período, nem a chave. O dado fica inútil pra busca.

**✅ Boa**
> "PIB municipal, fonte IBGE/SIDRA. **Cada linha é um município por ano**, de 2010 a 2024, todos os 5.570 municípios.
> Chave: código IBGE + ano. Colunas: `cod_municipio` (código de 7 dígitos), `ano`, `nome_municipio`, `uf`,
> `pib` (em **mil reais**). **Não** tem PIB per capita. Atualizo todo ano quando o IBGE publica a série nova."

---

## Antes de mandar pro Pedro — checklist

- [ ] O arquivo tem **uma aba só**, cabeçalho na primeira linha, sem células mescladas.
- [ ] Nomes de coluna sem acento/espaço; números sem `R$` nem ponto de milhar; datas em `AAAA-MM-DD`.
- [ ] O arquivo está nomeado `nome-do-dado_AAAA-MM-DD` (a data é a do **conteúdo**, ex.: `pib_municipal_2026-06-11`).
- [ ] A ficha está preenchida: **grão**, **chave**, **todas as colunas com unidade**, o que **não** responde.
- [ ] Listei as **perguntas reais** que esse dado responde.
- [ ] Coloquei o arquivo **e** a ficha juntos na pasta **`Planilhas e Dados/`** do Google Drive. **Pronto** — o Pedro cuida de subir no banco.

> Dúvida em qualquer passo? Fala com o Pedro (pedro.machado@fnp.org.br) **antes** de mandar —
> é mais rápido ajustar agora do que depois que já entrou no banco.
