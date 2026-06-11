# RAG Soberano — plano futuro (dado não sai da FNP)

> **Status: PLANO FUTURO / proposta.** Não é o que está implementado hoje. É a rota para tornar o
> assistente **zero-egress** — nenhum dado pessoal saindo para fora da infraestrutura da FNP — e os
> requisitos/custos para eventual aquisição. Decidir com o eval na mão (ver [`AVALIACAO_RAG.md`](AVALIACAO_RAG.md)).

## Por que (e o que NÃO é)
Hoje, para gerar embeddings e respostas, trechos de texto saem por HTTPS para **OpenAI** e
**Anthropic** (operadores de dados nos EUA — ver "Privacidade e fronteira de dados" em
[`ARQUITETURA.md`](ARQUITETURA.md)). O RAG soberano elimina isso: tudo roda na infra da FNP.

> ⚠️ **Não se faz isso para economizar.** Uma chamada de API custa centavos; uma GPU dedicada custa
> centenas de reais/mês. A justificativa é **soberania, LGPD e controle** — poder afirmar, de verdade,
> que o dado não sai. Para o volume atual (~100 perguntas/dia) a API é mais barata. É escolha de política.

---

## As duas metades (dificuldades muito diferentes)

### Metade 1 — Embeddings locais → **fácil, sem GPU, fazer cedo**
- Modelo aberto multilíngue (BGE-M3 ou multilingual-e5-large), forte em PT-BR.
- Roda **em CPU** (indexação é batch; embedar a pergunta é rápido). Só exige mais RAM.
- Remove o egress da **indexação e da busca** — que é o maior volume de texto que sai.
- ⚠️ Muda a dimensão do vetor (BGE-M3 = 1024, não 1536) → recriar a coluna `VECTOR`. **Decidir antes de
  indexar o acervo**, senão reindexar tudo depois.

### Metade 2 — Modelo de resposta self-hosted → **exige GPU; é o custo real**
Substituir o Claude por um modelo aberto rodando na infra da FNP. Como é RAG (o modelo só resume/cita
o trecho que já recebeu), **não precisa de um 70B** — um modelo médio aterrado costuma bastar.

| Faixa | Modelo | GPU (VRAM) | Qualidade vs Claude | Quando |
|---|---|---|---|---|
| Pequeno | Qwen2.5-7/14B, Llama-3.1-8B | 1× 24GB (L4 / RTX 4090) | bom para responder citando o contexto | piloto / volume baixo |
| Médio | Qwen2.5-32B | 1× 48GB (L40S / RTX 6000 Ada) | perto do Claude em tarefa aterrada | produção provável |
| Grande | Llama-3.3-70B (quantizado) | ~48–80GB (A100/H100) | bem perto | só se o eval exigir |

Servir: **Ollama** (simples, ideal para TIC de 1 pessoa) ou vLLM (mais performático).

---

## Custos — realidade (estimativas, **confirmar cotação**)

Valores aproximados, câmbio e cotação a validar na DigitalOcean / fornecedor de hardware.

### Linha de base (hoje, via API — dado sai)
| Item | Custo/mês |
|---|---|
| Embeddings OpenAI + respostas Claude (~100 q/dia) | ~US$ 25–35 |
> Barato e sem hardware — mas o dado sai. É o ponto de comparação.

### Cenário A — Embeddings locais, resposta ainda via API
| Item | Custo/mês |
|---|---|
| Upgrade do droplet (RAM p/ rodar embeddings em CPU, ~8GB) | ~+US$ 35 |
| Resposta via Claude (mantém) | ~US$ 20–30 |
> Tira o egress da indexação/busca **sem GPU**. Meio-caminho barato. A resposta ainda sai.

### Cenário B — Soberano total, **alugando GPU** (OPEX)
| Faixa | GPU 24/7 (aluguel cloud) |
|---|---|
| Pequeno (7–14B, 24GB) | ~US$ 350–750/mês |
| Médio (32B, 48GB) | ~US$ 700–1.400/mês |
| Grande (70B, 80GB) | ~US$ 1.800–3.000/mês |
> O custo é a **GPU ligada 24/7**, não o modelo (é grátis). Bom para **pilotar** sem comprar nada.

### Cenário C — Soberano total, **comprando hardware** (CAPEX) — o que "dura aqui dentro"
| Item | Investimento único | Custo recorrente |
|---|---|---|
| Workstation/servidor + GPU 24GB (ex.: RTX 4090) | ~R$ 20–35 mil | energia + hosting (~R$ 150–500/mês) |
| Idem com GPU 48GB (RTX 6000 Ada / L40S) | ~R$ 60–110 mil | energia + hosting |
> Em 2–3 anos, comprar costuma **sair mais barato** que alugar GPU 24/7, e é o caminho mais alinhado a
> "soberano e duradouro". Custo extra: hospedar a máquina (sala/colo) e mantê-la.

### Opção do meio (honesta) — provedor **no Brasil**
| Item | Nota |
|---|---|
| Modelo PT-BR hospedado no BR (ex.: Maritaca/Sabiá) | dado **não sai do território nacional**, contrato BR/LGPD — bem mais simples que EUA, sem GPU própria |
> Não é zero-egress (sai da FNP), mas resolve a maior parte da história de conformidade a um custo
> próximo do da API. Bom degrau enquanto não há GPU.

---

## Requisitos para aquisição (procurement)
Se for o **Cenário C** (comprar):
- GPU NVIDIA com **≥24GB VRAM** (48GB para folga de modelo médio) — RTX 4090 / RTX 6000 Ada / L40S.
- Servidor: CPU recente, **≥64GB RAM**, SSD NVMe ≥1TB, fonte e refrigeração adequadas à GPU.
- Local: tomada/UPS, rede na VPC da FNP, refrigeração. Ou colocation.
- Software (grátis/aberto): Ubuntu + Docker + driver NVIDIA + **Ollama/vLLM** + o modelo aberto.

---

## Caminho faseado (decidir por dados, não por fé)
1. **Embeddings locais já** (Cenário A) — fundação, sem GPU, decide a dimensão do vetor.
2. **Montar o eval** ([`AVALIACAO_RAG.md`](AVALIACAO_RAG.md)) — é ele que prova se o modelo local serve.
3. **Piloto de geração** (Cenário B, GPU alugada barata + Ollama + Qwen2.5-14B/32B): rodar o eval contra
   o modelo local **e** contra o Claude, lado a lado.
4. Passou no eval → decidir **alugar (B)** ou **comprar (C)** conforme volume e orçamento.
   Não passou → saber o gap exato e escolher (modelo maior / esperar / opção do meio).

> Regra: **não comprar GPU grande antes de o eval provar que precisa.** Pilotar alugado é barato.
