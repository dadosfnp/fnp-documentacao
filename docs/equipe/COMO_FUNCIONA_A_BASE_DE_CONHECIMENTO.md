# Base de Conhecimento FNP — O que é e por que documentar bem

Este documento explica, em linguagem acessível, o que é o sistema de busca inteligente que estamos construindo para a FNP, como ele funciona, e por que a forma como a equipe organiza e nomeia os arquivos faz toda a diferença na qualidade das respostas.

---

## O problema que estamos resolvendo

Hoje na FNP, o conhecimento institucional está espalhado:

- Resoluções em PDF em uma pasta do Drive
- Apresentações em outra pasta, com nomes como `apresentação FINAL (3).pptx`
- Planilhas de acompanhamento que só quem fez sabe onde estão
- Documentação de sistemas que existe só na cabeça de quem desenvolveu
- Regulamentos de programas que ninguém lembra onde salvou

O resultado é que responder uma pergunta como _"quais são os critérios de elegibilidade do Programa X?"_ vira uma caçada por arquivos, às vezes sem sucesso.

**O sistema que estamos construindo resolve isso.** Você digita a pergunta e recebe a resposta, com indicação exata de qual documento a embasou.

---

## O que é o sistema de busca inteligente (RAG)

RAG é a sigla em inglês para _Retrieval-Augmented Generation_ — em português: **geração de resposta com recuperação de contexto**. O nome técnico é complicado, mas o funcionamento é simples.

Pense assim: imagine que você tem um assistente que leu todos os documentos da FNP, e quando você faz uma pergunta, ele:

1. Vai até os documentos mais relevantes para aquela pergunta
2. Lê os trechos relacionados
3. Formula uma resposta baseada no que está escrito, citando a fonte

**Não é um ChatGPT genérico.** É um assistente que conhece especificamente os documentos, regulamentos, sistemas e dados da FNP.

---

## Como funciona, passo a passo

### Etapa 1 — Indexação (acontece nos bastidores, automaticamente)

Quando um arquivo é adicionado às pastas monitoradas do Google Drive ou enviado para o servidor, o sistema faz o seguinte:

```
Arquivo (PDF, DOCX, PPTX, Planilha...)
    ↓
Extrai o texto do arquivo
    ↓
Divide o texto em pedaços menores (chamados "chunks")
    ↓
Transforma cada pedaço em um código numérico (chamado "embedding")
    ↓
Guarda esse código no banco de dados
```

O código numérico representa o **significado** do texto — não as palavras exatas, mas o que aquele trecho quer dizer. Dois trechos que falam sobre o mesmo assunto com palavras diferentes vão ter códigos parecidos.

### Etapa 2 — Resposta (quando alguém faz uma pergunta)

```
Usuário faz uma pergunta
    ↓
O sistema transforma a pergunta no mesmo tipo de código numérico
    ↓
Busca os trechos dos documentos com código mais parecido
    ↓
Envia os trechos + a pergunta para a inteligência artificial (Claude)
    ↓
A IA formula a resposta baseada nos documentos encontrados
    ↓
Usuário recebe a resposta com as fontes citadas
```

---

## Por que isso é diferente de uma busca comum

Uma busca comum (como a do Google Drive) procura **palavras exatas**. Se você escrever "elegibilidade", ela não vai encontrar um documento que usa a palavra "critérios" para dizer a mesma coisa.

O sistema de busca semântica entende **significado**. Então:

| Você pergunta | O sistema encontra mesmo que o documento use |
|---------------|----------------------------------------------|
| "elegibilidade para o programa" | "requisitos", "critérios de participação", "quem pode se inscrever" |
| "município inadimplente" | "falta de pagamento", "débito em aberto", "situação irregular" |
| "como funciona o engajamento" | "pontuação", "participação", "nível de envolvimento" |

---

## Por que a documentação e o mapeamento importam

**O sistema só responde bem sobre o que foi indexado.** E a qualidade do que está indexado depende diretamente de como os arquivos estão organizados e nomeados.

### Exemplo prático

Imagine que alguém pergunta: _"Qual foi o resultado da 89ª Reunião Geral?"_

**Cenário ruim** — o arquivo está salvo como:
```
reunião (1) - versão Pedro - FINAL mesmo.pdf
```
O sistema pode até encontrar o arquivo, mas não sabe que é a 89ª Reunião Geral. A resposta fica imprecisa.

**Cenário bom** — o arquivo está salvo como:
```
2024-11_ata_89_reuniao_geral_fnp.pdf
```
O sistema encontra imediatamente e a resposta indica exatamente a fonte.

### O que o mapeamento resolve

Quando a equipe segue as convenções de nomenclatura e organização de pastas:

- O sistema sabe **o que é cada arquivo** (regulamento, ata, apresentação, dado)
- Sabe **quando foi produzido** (pelo ano no nome)
- Sabe **a qual assunto pertence** (pela pasta onde está)
- Consegue **citar a fonte com precisão** na resposta

Sem esse mapeamento, o sistema funciona, mas as respostas são menos precisas e as fontes menos claras.

---

## O que o sistema vai conseguir fazer quando estiver completo

- _"Quais municípios do Nordeste estão inadimplentes?"_ → busca nos dados de adimplência
- _"Qual é a política de engajamento vigente?"_ → busca nas resoluções e regulamentos
- _"Como funciona o credenciamento para a próxima reunião geral?"_ → busca nas atas e apresentações
- _"O que é o campo 'nível de engajamento' no sistema?"_ → busca na documentação técnica do Sistema FNP
- _"Quais foram os temas discutidos na última missão?"_ → busca nas atas de missões

Tudo isso sem precisar abrir um único arquivo manualmente.

---

## O que a equipe precisa fazer (e é pouco)

A equipe **não precisa aprender nenhuma ferramenta nova**. Só precisa:

1. **Salvar arquivos nas pastas certas** do Google Drive (ver `ESTRUTURA_DRIVE.md`)
2. **Nomear os arquivos seguindo o padrão** — data + assunto, sem espaços, sem acentos no nome (ver `GUIA_ARQUIVOS.md`)

O Pedro cuida de tudo o mais: configuração do servidor, indexação automática, manutenção do sistema.

---

## Segurança e privacidade

- O sistema só está disponível para pessoas com acesso autorizado à rede da FNP
- Nenhum arquivo é compartilhado externamente
- Os documentos originais não são modificados nem movidos
- Dados pessoais sensíveis (CPFs, dados de pessoas físicas) **não devem ser colocados nas pastas monitoradas** sem aprovação prévia, seguindo as regras da LGPD

---

## Resumo em uma frase

> Quanto melhor organizados e nomeados estiverem os arquivos da FNP, mais útil e preciso será o assistente de perguntas que a equipe vai poder usar.

---

## Dúvidas

**Pedro Ivo** — pedro.machado@fnp.org.br
