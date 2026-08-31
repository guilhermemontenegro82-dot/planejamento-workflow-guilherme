# Skills — Lançamento de Notas DG Revy

Esta pasta é o **backup local e a fonte da verdade** das skills do fluxo de lançamento
de notas do DG Revy. Toda alteração/melhoria é feita aqui primeiro; depois o Guilherme
leva o texto para o Claude Cowork.

Mesmo padrão já usado em `01 - EP Engenharia/Lançamento de Notas/Skills/`.

## O que já está aqui

| Arquivo | O que é | Status |
|---|---|---|
| `skill-notas-fiscais-ml.md` | Busca a NF-e oficial das compras do Mercado Livre, atualiza a planilha e baixa/organiza os PDFs | Rodando no Cowork |

**Por que essa skill é do DG e não da EP**: no fluxo DG o número oficial da nota é
obrigatório — vai para o imposto de renda do Diogo. No fluxo EP, compra do Mercado
Livre só precisa de data e valor (confirmado pelo Guilherme em 05/08/2026), por isso
essa skill foi removida do pipeline da EP.

## ⚠️ O que ainda falta trazer do Cowork

O backup está **incompleto**. Pelo mapa mental, o DG Revy tem pelo menos mais isto
rodando no Cowork, sem cópia local:

- **Controle financeiro das 4 obras** (cada obra com seu próprio grupo de WhatsApp) —
  marcado como "rodando, com alguns erros pequenos" no mapa mental.
- **Skill/supervisor de lançamento de notas do DG** — o `ep-leitor-notas` cita uma
  "skill irmã do DG (`supervisor-lancamento-dg`)"; não sabemos se já existe com esse
  nome ou outro.

Para completar o backup, o Guilherme precisa colar o texto dessas skills numa sessão
do Claude Code — aí elas passam a viver aqui, versionadas no Git, e qualquer correção
futura é feita nesta pasta.

## Temas do DG ainda não desenvolvidos

Pastas irmãs criadas e vazias, aguardando desenvolvimento: `Compras/`, `Cronograma/`,
`Auditoria de Notas/`.
