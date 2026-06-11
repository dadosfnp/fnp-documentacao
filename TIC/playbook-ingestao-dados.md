# Playbook — Ingestão de dados na infra da FNP

> **Propósito:** receita padrão para a **equipe do Núcleo de Dados** entregar datasets (Excel/`.parquet` tratados via R)
> e para a **TIC** colocá-los no banco da FNP de forma rastreável, versionada e documentada.
> **Natureza:** documento **global e genérico** — vale para qualquer dataset, hoje e no futuro.
> **Quando usar:** sempre que um dado novo (ou uma nova versão de um dado) precisar entrar no banco da FNP.

> ⚠️ Este playbook é **diferente** do [`playbook-deploy-novo-sistema.md`](playbook-deploy-novo-sistema.md).
> Aquele sobe **sistemas** (apps com ORM, onde o dicionário é gerado por introspection dos models).
> Este trata de **dados brutos** que chegam de fora (planilhas, Parquet) e **não têm model pra introspectar** —
> por isso o dicionário aqui é **preenchido à mão** (ver [`template-dicionario-dataset.md`](template-dicionario-dataset.md)).

> 🚫 **O que este playbook NÃO cobre — e isso é importante deixar claro:**
> apresentações, PowerPoint, PDFs, atas e documentos em geral **continuam no Google Drive** e são
> indexados só para busca — **nunca** viram tabela no banco e **nada é movido ou removido do Drive**.
> Aqui tratamos **exclusivamente de dados tabulares** (Parquet/planilhas de indicadores tratados no R)
> que você quer **consultar**. Regra mental: **documento você quer _encontrar_** (fica no Drive, o RAG acha) —
> **dado tabular você quer _consultar_** (vira tabela num **schema do Núcleo** no banco do RAG).

---

## 0. A arquitetura de dados da FNP (o mapa mental)

A FNP tem **três camadas de dados**. Entender onde cada coisa vive é o que torna o RAG assertivo.

| Camada | O que é | Onde vive | Quem alimenta |
|---|---|---|---|
| **Núcleo de Dados** | Dados públicos tratados via R (hoje espalhados em Excel/Parquet) | **Schemas do Núcleo** (`economia`, `social`…) no banco do RAG | Equipe do Núcleo de Dados |
| **Bases de aplicação** | Dados operacionais de cada sistema | `fnp` (CRM), `ifem`, próximos — **1 sistema = 1 database** | Cada app, via seu ORM |
| **RAG (mapa/roteador)** | **Não armazena os dados** — indexa os `.md` e cataloga as fontes pra saber **onde** procurar | Schema `rag` (embeddings + catálogo) | Os `.md` deste repositório, do Drive e dos apps |

> **Princípio central:** o RAG é um **índice de onde as coisas estão**, não um cofre de dados.
> Quando alguém pergunta algo, o RAG localiza a fonte (um dataset num schema do Núcleo, uma tabela do `ifem`,
> um arquivo no Drive) e responde **citando de onde veio**. Por isso, todo dataset que entra **precisa**
> de um dicionário — sem dicionário, o RAG não sabe que o dado existe.

### O modelo híbrido — Drive + Spaces + banco

Cada peça do dado mora no lugar onde ela é melhor servida:

| Peça | Onde mora | Por quê |
|---|---|---|
| **Dicionário** (`.md`, leve, texto) | **Google Drive** (e versionado neste repo) | Familiar pra equipe; é o "mapa" que o RAG lê e indexa |
| **Arquivo Parquet** (pesado, binário) | **DO Spaces** (`dados/nucleo/...`) | Storage S3, certo pra blob grande; é a fonte arquivada |
| **Dado consultável** (tabela) | **Schema do Núcleo** no banco do RAG (ex.: `economia`) | É onde se faz query/BI de verdade |

> A **equipe só toca no Google Drive** (um lugar, familiar — segue os mesmos guias de [`docs/equipe/`](../docs/equipe/GUIA_ARQUIVOS.md)).
> Quem faz a parte híbrida (arquivar o Parquet no Spaces e carregar a tabela no banco) é a **TIC**.

---

## 1. Princípios gerais

1. **O dado nunca chega órfão.** Todo arquivo entregue vem acompanhado do seu **dicionário** preenchido.
2. **Parquet por padrão.** Tipado, comprimido, sem "número que virou texto". Excel só quando a fonte é manual mesmo.
3. **Entrega num lugar só (Drive).** A equipe não mexe em Spaces nem em banco — isso é trabalho da TIC.
4. **Versionado por data.** Cada entrega é uma versão datada; nunca sobrescrever silenciosamente o anterior.
5. **Idempotência.** Recarregar a mesma versão duas vezes não pode duplicar linhas (chave + estratégia de upsert/replace).
6. **Dados públicos, mas com responsável.** Mesmo público, todo dataset tem um dono que responde por ele.

---

## 2. Onde os dados ficam — schemas do Núcleo no banco do RAG

> ⚠️ **Atenção (RDA-002):** dado tabular do Núcleo **não** é um database separado — é **schema no
> banco único** do RAG. Isso permite ao assistente cruzar `rag` × dado na mesma query, sem
> `postgres_fdw`. Database dedicado é só para **app com ORM próprio** (ex.: IFEM), pelo
> [`playbook-deploy-novo-sistema.md`](playbook-deploy-novo-sistema.md). Regra: *dado consultável = schema; app = database*.

Os schemas e o role de carga já são criados pelo
[`01_setup_banco.sql`](../scripts/sql/01_setup_banco.sql). Para um **tema novo** (ainda não previsto),
com a credencial admin (`doadmin`), no **banco do RAG**:

```sql
-- 1) schema do tema (só uma vez por tema)
CREATE SCHEMA IF NOT EXISTS economia;

-- 2) permissões: carga escreve, assistente e analistas leem
GRANT USAGE ON SCHEMA economia TO nucleo_carga, app_write, readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA economia TO nucleo_carga;
GRANT SELECT ON ALL TABLES IN SCHEMA economia TO app_write, readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE nucleo_carga IN SCHEMA economia
  GRANT SELECT ON TABLES TO app_write, readonly;
```

- **Um schema por tema** (ex.: `economia`, `social`, `eleitoral`) — mantém a base navegável.
- **Uma tabela por dataset.** Nome em PT-BR, `snake_case`, prefixado pelo tema: `economia.pib_municipal`.
- A **carga** usa o role `nucleo_carga` (privilégio mínimo: escreve só nos schemas do Núcleo). A senha
  é gerada **no servidor** (`openssl rand -hex 24`) e vive só no `.env` do droplet + cofre Bitwarden.

---

## 3. Fluxo de entrega (Núcleo de Dados → TIC)

### Passo 1 — Preparar o dataset (Núcleo de Dados)
- Exportar de R direto para Parquet — preserva tipo e é leve:
  ```r
  arrow::write_parquet(df, "pib_municipal_2026-06-11.parquet")
  ```
- Garantir que **cada coluna tem um nome claro** e que existe uma **chave** que identifica a linha sem ambiguidade.
- Conferir o **grão**: 1 linha representa exatamente o quê? (ex.: "1 município por ano").

### Passo 2 — Preencher o dicionário (Núcleo de Dados)
- Copiar [`template-dicionario-dataset.md`](template-dicionario-dataset.md) e preencher **todas** as seções.
- O dicionário acompanha o arquivo de dados, com o **mesmo nome base**.
- **Para o text-to-SQL (TIC):** ao registrar no mapa do RAG (Passo 7), gerar também a versão
  estruturada [`template-dicionario-dataset.yaml`](template-dicionario-dataset.yaml) — é ela que o
  roteador lê de forma programática (tabela, colunas, tipos, chave) para montar a query. O `.md`
  é para humano; o `.yaml` é para a máquina. Mantenha os dois em sincronia.

### Passo 3 — Entregar no Google Drive (Núcleo de Dados)
Tudo num lugar só, na pasta de dados já monitorada (ver [`ESTRUTURA_DRIVE.md`](../docs/equipe/ESTRUTURA_DRIVE.md)):

```
📁 FNP — Base de Conhecimento/
└── 📁 Planilhas e Dados/
    └── 📁 <nome-do-dataset>/
        ├── <slug>_AAAA-MM-DD.parquet        ← os dados (Excel como fallback)
        └── <slug>_AAAA-MM-DD.dicionario.md  ← o dicionário daquela versão
```

- **Nomenclatura:** `slug_AAAA-MM-DD` — a data é a do **conteúdo** (referência), não a do upload. Sem espaço, sem acento.
- A equipe **para por aqui**. Os próximos passos são da TIC.

### Passo 4 — Validar (TIC)
- Conferir que o dicionário bate com o arquivo: nº de colunas, tipos, chave.
- Conferir **contagem de linhas** e ausência de duplicatas na chave declarada.
- Conferir que não há dado sensível indevido (mesmo sendo base pública — CPF, e-mail pessoal etc.).

### Passo 5 — Arquivar o Parquet no Spaces (TIC)
- Copiar o Parquet validado para o Spaces como fonte arquivada:
  `dados/nucleo/<slug>/<slug>_AAAA-MM-DD.parquet`.
- É daqui que o worker lê o conteúdo para indexar — e fica o blob de origem versionado.

### Passo 6 — Carregar no banco (TIC)
- Criar/atualizar a tabela no schema do tema (ex.: `economia.<dataset>`) conforme o dicionário (tipos vindos do Parquet), usando o role `nucleo_carga`.
- Carga **idempotente**: `TRUNCATE`+`COPY` para substituição total, ou upsert pela chave para incremento.
- **Validar contagens** origem (Parquet) × destino (tabela). Só dar como concluído se baterem.

### Passo 7 — Registrar no mapa do RAG (TIC)
- Versionar o `.dicionario.md` neste repositório (ou no caminho que o ingestor do RAG varre).
- A partir daí o RAG **sabe que o dataset existe**, onde está e quais perguntas ele responde.

---

## 4. O mapa do Drive — catálogo no banco, não varredura ao vivo

O RAG precisa saber **o que existe no Drive** (ex.: "esse relatório já foi colocado lá?"). A resposta certa
**não** é o RAG percorrer o Drive a cada pergunta — é manter um **catálogo no banco** que um worker sincroniza.

- A tabela [`rag.arquivos_indexados`](../docs/banco/BANCO.md) **já é esse catálogo**: `caminho`, `hash_sha256`, `tipo`, `status`, `ultima_ingestao`.
- Um **worker** lê o Drive (**cron diário + polling** — não webhook; o worker não tem IP público, ver RDA-003), calcula o **SHA-256** de cada arquivo e atualiza o catálogo.
- O RAG, ao responder, **consulta o catálogo no banco** — rápido, com busca semântica sobre o conteúdo já indexado.

**Por que não varrer o Drive ao vivo:** é lento, esbarra no *rate limit* da API do Google e — principalmente —
busca semântica exige o embedding **já calculado e guardado** no banco. O Drive é a **fonte**; o banco é o **índice**.
Não são dois trabalhos: é um só, e já está previsto na [arquitetura](../docs/tecnico/ARQUITETURA.md) e no [`ingestor.py`](../scripts/python/ingestor.py).

---

## 5. Parquet vs. Excel — por que Parquet

| Critério | Parquet | Excel (`.xlsx`) |
|---|---|---|
| Tipo das colunas | Preservado (número é número, data é data) | Frágil (número vira texto, data vira número) |
| Tamanho | Comprimido | Pesado |
| Saída do R | Nativa (`arrow::write_parquet`) | Requer pacote e formatação |
| Múltiplas abas | Não tem (1 arquivo = 1 tabela = bom) | Convida à bagunça (várias abas, células mescladas) |

**Regra:** se o R gera, gere Parquet. Excel só quando a origem é uma planilha mantida à mão.

---

## 6. Armadilhas conhecidas

- **Planilha com células mescladas / cabeçalho em 2 linhas** → não é dado, é layout. Pedir extração tabular limpa.
- **"Número" com separador de milhar ou `R$`** → vira texto. Tratar no R antes de exportar.
- **Datas em formatos mistos** (`01/02/26`, `2026-02-01`) → padronizar para ISO `AAAA-MM-DD` na origem.
- **Mesma versão recarregada** → sem chave/estratégia de carga, duplica tudo. Definir a chave no dicionário.
- **Dataset sem dicionário** → o RAG não enxerga. Sem dicionário, **não carrega**.
- **Acentos/encoding em Excel** → exportar como UTF-8; Parquet não tem esse problema.

---

## 7. Checklist final (Definition of Done)

- [ ] Dataset em Parquet (ou Excel justificado), nomeado `slug_AAAA-MM-DD`.
- [ ] Dicionário preenchido por completo, na mesma pasta do Drive.
- [ ] Entregue pela equipe no Drive, em `Planilhas e Dados/<dataset>/`.
- [ ] TIC validou colunas, tipos, chave e contagem.
- [ ] Parquet arquivado no Spaces (`dados/nucleo/<slug>/`).
- [ ] Tabela criada/atualizada no schema do tema (ex.: `economia.<dataset>`); contagens origem × destino batem.
- [ ] Dicionário versionado e indexado pelo RAG; catálogo do Drive atualizado.
- [ ] Inventário TIC atualizado (dataset, tabela, dono, última versão).

---

## 8. Resumo dos aprendizados (uma frase cada)

- **O dado nunca chega órfão** — sempre acompanhado do dicionário.
- **Parquet por padrão** — tipo preservado, leve, nativo do R.
- **Equipe entrega só no Drive** — Spaces e banco são trabalho da TIC.
- **Carga idempotente** — recarregar não pode duplicar.
- **Sem dicionário, sem RAG** — o que não está documentado, o RAG não encontra.
- **RAG é mapa, não cofre** — cataloga as fontes no banco e cita de onde veio; nunca varre o Drive ao vivo.
