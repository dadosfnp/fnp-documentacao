# Guia de Arquivos — FNP

> Versão curta: **continue usando o Google Drive normalmente.** Este guia explica só o que muda e como nomear arquivos para facilitar a busca.

---

## O que mudou (e o que não mudou)

**Não mudou nada no seu dia a dia.** Você continua salvando arquivos no Google Drive como sempre fez.

O que estamos fazendo é criar um sistema de busca inteligente que lê automaticamente os arquivos do Drive. Para que esse sistema funcione bem, só precisamos seguir algumas convenções simples de organização.

---

## Pastas oficiais no Google Drive

Dentro do Drive compartilhado da FNP, as pastas abaixo são monitoradas automaticamente pelo sistema:

```
📁 FNP — Base de Conhecimento/
   ├── 📁 Regulamentos e Resoluções/
   ├── 📁 Apresentações/
   ├── 📁 Relatórios e Estudos/
   ├── 📁 Administrativo/
   ├── 📁 Atas e Reuniões/
   └── 📁 Planilhas e Dados/
```

> Arquivos fora dessas pastas **não são indexados** — não aparecem na busca.

---

## Como nomear seus arquivos

Um bom nome de arquivo tem três partes: **data + assunto + versão (se houver)**.

| ✅ Bom | ❌ Evitar |
|--------|----------|
| `2025-05_relatorio_municipios_nordeste.pdf` | `relatorio FINAL (2).pdf` |
| `2025-06_ata_reuniao_geral_89.docx` | `ata reunião.docx` |
| `2025_resolucao_programa_x_v2.pdf` | `resolucao (cópia).pdf` |
| `2025-05_apresentacao_programa_mobilidade.pptx` | `apresentação pedro.pptx` |

**Regras simples:**
- Use data no início: `AAAA-MM` ou só `AAAA`
- Sem espaços — use underscore `_`
- Sem acentos no nome do arquivo
- Versões finais: sem sufixo ou `_final`. Rascunhos: `_v1`, `_v2`

---

## Tipos de arquivo aceitos

| Tipo | Extensão | Observação |
|------|----------|------------|
| Documentos | `.pdf`, `.docx`, `.doc` | Todos aceitos |
| Apresentações | `.pptx`, `.ppt` | Todos aceitos |
| Planilhas | `.xlsx`, `.xls` | Google Sheets: exportar como .xlsx |
| Dados | `.parquet`, `.csv` | Para arquivos de análise |
| Textos | `.md`, `.txt` | Documentação técnica |

**Google Sheets:** o sistema lê diretamente do Drive sem precisar exportar. Mas se quiser garantir uma versão estática, exporte como `.xlsx` na mesma pasta.

---

## Quero adicionar um arquivo que não está no Drive

Se o arquivo está na rede local ou em outro lugar, manda para o Pedro Ivo que ele sobe no lugar certo. Não precisa se preocupar com isso por enquanto.

---

## O que o sistema faz com meus arquivos

- **Lê** o conteúdo para indexar na busca
- **Não modifica** nenhum arquivo
- **Não move** nenhum arquivo
- **Não apaga** nada

O arquivo continua exatamente onde você colocou, do mesmo jeito.

---

## Dúvidas

**Pedro Ivo** — pedro.machado@fnp.org.br
