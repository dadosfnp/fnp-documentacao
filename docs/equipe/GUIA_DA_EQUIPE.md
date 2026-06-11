# Guia da Equipe — como entregar e nomear seus arquivos

> **Para quem é:** toda a equipe da FNP. **O que muda no seu dia a dia:** quase nada — você continua
> usando o Google Drive. Só seguindo algumas convenções simples, o assistente de busca acha tudo
> rápido e cita a fonte certa, e os dados ficam organizados num banco limpo.
>
> Leitura de 5 minutos. Em dúvida em qualquer passo, fala com o **Pedro Ivo** (pedro.machado@fnp.org.br)
> **antes** de mandar — é mais fácil ajustar agora do que depois.

---

## A regra de ouro: dois tipos de material

Antes de tudo, saiba qual dos dois você tem em mãos — porque o caminho é diferente:

| | 📄 **Documento** | 📊 **Dado / base** |
|---|---|---|
| O que é | apresentação, ata, PDF, regulamento, ofício | planilha de indicadores, série histórica, base tratada (PIB, etc.) |
| Você quer… | **encontrar** ("o que foi decidido na reunião?") | **consultar/cruzar** ("PIB dos 10 maiores municípios?") |
| O que fazer | salvar no Drive bem nomeado (Partes 1 e 2) | entregar **com a ficha** (Parte 3) |
| Para onde vai | é lido e indexado para a busca | vira **tabela no banco**, pra cálculo e cruzamento |

> 🟢 **Nada sai do Drive.** O sistema só **lê** para indexar — nunca move, nunca apaga, nunca altera
> seus arquivos. Eles continuam exatamente onde você colocou.

---

## Parte 1 — Onde salvar (as pastas oficiais)

Dentro do Drive compartilhado, salve nestas pastas — **só o que está aqui dentro entra na busca**:

```
📁 FNP — Base de Conhecimento/
├── 📁 Regulamentos e Resoluções/   resoluções, portarias, normas
├── 📁 Apresentações/                slides de reuniões, programas, eventos
├── 📁 Relatórios e Estudos/         relatórios técnicos, estudos, notas
├── 📁 Atas e Reuniões/              atas e memórias de reunião
├── 📁 Administrativo/  🔒            contratos, convênios, documentos institucionais
└── 📁 Planilhas e Dados/  📊         bases e indicadores (caminho da Parte 3)
```

- 🔒 **Administrativo** é tratado como **acesso restrito** — o conteúdo dela não aparece para quem não
  tem permissão. Coloque ali só o que é mesmo administrativo/sensível.
- **Criou uma subpasta nova?** Nome em português, sem abreviação, sem data no nome (a data fica no
  arquivo). Bons: `Programa Mobilidade Urbana`, `Reuniões 2025`. Ruins: `Misc`, `Outros`, `Temp`.
- **Não sei onde colocar?** Põe em `Relatórios e Estudos/` e avisa o Pedro. Melhor no lugar errado do
  que fora da pasta monitorada (fora dela, o assistente não enxerga).

---

## Parte 2 — Como nomear os arquivos

Um bom nome tem **data + assunto + versão (se houver)**:

| ✅ Bom | ❌ Evitar |
|--------|-----------|
| `2025-05_relatorio_municipios_nordeste.pdf` | `relatorio FINAL (2).pdf` |
| `2024-11_ata_reuniao_geral_89.docx` | `ata reunião.docx` |
| `2025_resolucao_programa_x_v2.pdf` | `resolucao (cópia).pdf` |
| `2025-05_apresentacao_programa_mobilidade.pptx` | `apresentação pedro.pptx` |

**As regras (valem para qualquer arquivo):**
- 📅 **Data no início:** `AAAA-MM` ou só `AAAA` — é a data do **conteúdo**, não a do upload.
- ⎵ **Sem espaços** — use underscore `_`.
- 🔤 **Sem acentos** no nome do arquivo.
- 🏷️ **Assunto claro** no nome — quem lê o nome entende o que é (inclua número/edição quando fizer
  sentido: `reuniao_geral_89`).
- 🔁 **Versão:** final fica sem sufixo (ou `_final`); rascunhos `_v1`, `_v2`. Quando sair a final,
  **deixe só ela** — apague as antigas.

> Por que importa: `2024-11_ata_reuniao_geral_89.pdf` o assistente entende na hora e cita a fonte
> certinha. `reunião (1) - versão Pedro - FINAL mesmo.pdf` ele até acha, mas a resposta fica imprecisa.

**Tipos de documento aceitos:** `.pdf`, `.docx`, `.doc`, `.pptx`, `.ppt`, `.md`, `.txt`.
*(Planilhas e dados têm um caminho próprio — Parte 3.)*

---

## Parte 3 — Se for DADO (planilha / base de indicadores)

Aqui é o pulo do gato pro **banco ficar certo e bonito**. Dado tabular **não** é lido como texto —
ele vira **tabela** no banco, pra dar pra calcular e cruzar. Para isso, ele precisa chegar arrumado e
**acompanhado de uma ficha**. Você entrega **duas coisas**: o arquivo **+** a ficha.

### 3.1 — O arquivo de dados
Prefira **Parquet** (o que o R já gera: `arrow::write_parquet(df, "...")`). Excel serve, mas siga as regras:

- ✅ **Uma tabela, uma aba só.** Um arquivo = uma tabela.
- ✅ **Primeira linha = cabeçalho** (nomes das colunas) e só ela. Sem título/logo/data acima.
- ✅ **Nomes de coluna simples:** minúsculo, sem acento, sem espaço, com `_`. Ex.: `cod_municipio`, `pib`.
- ✅ **Uma informação por coluna.** Separe `municipio` e `uf` — não `"São Paulo - SP"` numa só.
- ✅ **Número é número.** Sem `R$`, sem ponto de milhar. `829840`, não `R$ 829.840`.
- ✅ **Data num formato só:** `AAAA-MM-DD`. Nunca misture `01/02/26` com `2026-02-01`.
- 🚫 Sem células mescladas, cor com significado, totais no meio, ou linhas em branco separando blocos.

> 💡 Teste mental: a tabela tem que poder ser lida de cima a baixo como uma lista, sem você precisar
> explicar o layout.

### 3.2 — A ficha (dicionário)
Copie o modelo **`template-dicionario-dataset.md`** (o Pedro te passa) e preencha. Não precisa entender
de banco — só explicar o que você já sabe. Os 4 campos que mais importam:

1. **Grão** — "cada linha é um(a) ___ por ___". Ex.: *"um município por ano"*.
2. **Chave** — o que não pode repetir. Ex.: (`cod_municipio`, `ano`).
3. **Colunas** — liste todas, com **a unidade** (PIB em reais? mil reais? — essa é a dúvida nº 1 depois).
4. **O que o dado NÃO responde** — ex.: *"tem PIB total, mas não tem PIB per capita"* (evita o
   assistente citar pra coisa errada).

E liste **as perguntas reais** que esse dado responde — quanto mais, mais o assistente acerta.

> Detalhes e exemplos (ficha ruim × boa) em [`COMO_DOCUMENTAR_SEUS_DADOS.md`](COMO_DOCUMENTAR_SEUS_DADOS.md).

### 3.3 — Entregue os dois juntos
Coloque **o arquivo + a ficha** na pasta **`Planilhas e Dados/`**, com o mesmo nome base e a data do
conteúdo:

```
Planilhas e Dados/pib_municipal/
├── pib_municipal_2026-06-11.parquet        ← os dados
└── pib_municipal_2026-06-11.dicionario.md  ← a ficha
```

Pronto — **o Pedro cuida de subir no banco.**

---

## O que NÃO colocar nas pastas

- 🔐 **Dados pessoais sensíveis** (CPF, telefone, dados de pessoas físicas) **sem aprovação prévia** —
  regra da LGPD. Na dúvida, pergunte antes.
- 🗑️ Rascunhos que não estão prontos para a equipe consultar.
- 📂 Arquivos pessoais ou provisórios.
- 🕰️ Versões antigas quando já existe a final (mantenha só a final).

---

## Checklist rápido (antes de salvar/mandar)

**Documento:**
- [ ] Está na pasta certa do Drive.
- [ ] Nome no padrão: `AAAA-MM_assunto`, sem espaço, sem acento.

**Dado / base:**
- [ ] Arquivo com **uma aba só**, cabeçalho na 1ª linha, sem células mescladas; números sem `R$`; datas `AAAA-MM-DD`.
- [ ] Nome `nome-do-dado_AAAA-MM-DD` (data do conteúdo).
- [ ] **Ficha preenchida**: grão, chave, todas as colunas com unidade, o que não responde, perguntas reais.
- [ ] Arquivo **e** ficha juntos em `Planilhas e Dados/`.

---

## Dúvidas

**Pedro Ivo** — pedro.machado@fnp.org.br
Quer entender *por que* tudo isso importa? → [`COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md`](COMO_FUNCIONA_A_BASE_DE_CONHECIMENTO.md)
