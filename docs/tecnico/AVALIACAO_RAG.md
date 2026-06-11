# Avaliação do RAG — antes de declarar "100%"

> "Funcional" sem medição é achismo. Antes de dizer que o assistente está pronto (fase 6 de
> [`FASES.md`](FASES.md)), monte um conjunto de perguntas reais com resposta esperada e **meça o acerto**.
> Este documento é o método + o gabarito.

---

## Como medir

1. Reúna **~20 perguntas reais** que a equipe faria de verdade — não perguntas fáceis inventadas.
2. Cubra os **três tipos** (o roteador precisa acertar o caminho, ver RDA-006):
   - **Documento** (busca semântica): "o que foi decidido na ata X?"
   - **Dado** (text-to-SQL): "PIB dos 10 maiores municípios filiados?"
   - **Sistema** (`app`/`ifem`): "o município Y está adimplente?"
3. Para cada pergunta, registre: resposta esperada, **fonte esperada** e o **caminho esperado** (documento/dado/sistema).
4. Rode e classifique cada resposta:
   - ✅ **Correta** — resposta certa **e** fonte certa.
   - ⚠️ **Parcial** — resposta certa, fonte errada/ausente (ou vice-versa).
   - ❌ **Errada** — resposta incorreta, ou alucinação, ou roteou para o caminho errado.
5. **Meta inicial sugerida:** ≥ 80% ✅ e **zero** ❌ por vazamento de acesso (RDA-007).

### Métricas a registrar por rodada

| Métrica | Como calcular |
|---|---|
| Acerto de resposta | ✅ / total |
| Acerto de roteamento | quantas vezes escolheu documento/dado/sistema certo |
| Acerto de fonte | citou a fonte correta |
| Vazamento de acesso | respondeu com chunk acima do nível do usuário (**tem que ser 0**) |
| Latência p50 / p95 | de `rag.historico_perguntas.latencia_ms` |

---

## Gabarito (preencher com perguntas reais)

| # | Pergunta | Tipo esperado | Resposta esperada | Fonte esperada | Resultado |
|---|---|---|---|---|---|
| 1 | *ex.: O que foi decidido na 89ª Reunião Geral?* | documento | *…* | *ata no Drive* | ⏳ |
| 2 | *ex.: Qual o PIB dos 10 maiores municípios filiados?* | dado | *ranking* | `economia.pib_municipal` | ⏳ |
| 3 | *ex.: O município X está adimplente?* | sistema | *…* | `app` (adimplência) | ⏳ |
| 4 | *(pergunta de pasta restrita feita por usuário sem acesso — deve recusar)* | acesso | *recusa/omite* | — | ⏳ |
| … | | | | | |
| 20 | | | | | |

---

## Quando repetir

- Antes de cada marco grande (ligar text-to-SQL, abrir para a equipe).
- Depois de reindexar o acervo ou trocar modelo de embedding/resposta.
- Sempre que a equipe relatar uma resposta ruim — vira um caso novo no gabarito (não some).
