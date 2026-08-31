# Estrutura de pastas — 12 Claude Works

Última reorganização: 30/08/2026

Organização por **linha de trabalho**, espelhando o mapa mental do ecossistema.
Mapa mental online: https://claude.ai/code/artifact/92fa999b-b579-4627-ad11-18f6ea74317a

## Regra geral

Cada tema de trabalho tem sua própria pasta. Quando o tema tem skills/agentes
desenvolvidos, eles ficam numa subpasta **`Skills\`** dentro do próprio tema — é ali
que o Claude busca para alterar/atualizar, e de lá que sai o texto para colar no
Claude Cowork.

```
<Linha de trabalho>\<Tema>\Skills\          ← definições de skills e agentes
<Linha de trabalho>\<Tema>\<material>\      ← planilhas, projetos, fotos, testes
```

## Mapa da raiz

```
12- Claude - works\
│
├── 01 - EP Engenharia\
│   ├── Orçamentos\                 Skills\ (6 skills + 2 chequers + orquestrador) · Obras (teste)\
│   ├── Lançamento de Notas\        Skills\ (3 skills + 2 chequers + supervisor) · Planilhas (teste)\
│   ├── Relatórios Fotográficos\    (a desenvolver)
│   ├── Relatórios Técnicos\        (a desenvolver)
│   ├── Fechamento Financeiro Semanal\  (a desenvolver)
│   ├── Recibos Semanais\           (a desenvolver)
│   ├── Instagram EP\               campanhas: Antes de começar · Sinais estruturais ·
│   │                               Empresa Sumiu · Obra Limpa Obra Séria
│   ├── Folha de Ponto\             planilhas de ponto e extração
│   ├── Cotações\Granitos\          escopos Leme · Prudente · Rainha · Visconde
│   └── Análises Financeiras\       análise financeira obras MC
│
├── 02 - DG Revy\
│   ├── Notas Fiscais Mercado Livre\   Skills\ (skill-notas-fiscais-ml)
│   ├── Lançamento de Notas\        (a desenvolver)
│   ├── Compras\                    (a desenvolver)
│   ├── Cronograma\                 (a desenvolver)
│   └── Auditoria de Notas\         (a desenvolver)
│
├── 03 - GAM Soluções\
│   ├── Identidade Visual\          logo, briefing de identidade
│   ├── Site\                       (a desenvolver)
│   ├── Instagram\                  (a desenvolver)
│   ├── YouTube\                    (a desenvolver)
│   └── Documentos-Base\            (a desenvolver)
│
├── 04 - Pessoal\
│   ├── Investimentos\              (a desenvolver)
│   └── Contas a Pagar\             (a desenvolver)
│
└── 🔒 PASTAS FIXAS — não mover, não renomear (ver abaixo)
```

## 🔒 Pastas fixas — caminho travado por skill

Estas quatro pastas têm o caminho **escrito dentro de uma skill instalada**. Mover ou
renomear qualquer uma delas quebra a skill silenciosamente — ela vai procurar num
caminho que não existe mais.

| Pasta | Travada por | Onde está o caminho |
|---|---|---|
| `Base dados financeiros obras EP\` | Skill global `base-de-dados-financeiros-EP` | `~/.claude/skills/base-de-dados-financeiros-EP/SKILL.md`, linha 15 |
| `Darf MEI Equipe\` | Skill empacotada `darf-mei-equipe.skill` | "Pasta de trabalho" no SKILL.md |
| `E-Mails - G-Mail e Yahoo\` | Skill agendada `limpeza-semanal-inbox-boletos` | passo 4 — destino dos PDFs de boleto |
| `Planejamento WorkFlow Guilherme\` | Projeto do Claude Code (este repositório) | a memória do projeto depende deste nome exato |
| `Scheduled\` | Agendador (rotina semanal de e-mail) | convenção do agendador |

**Se algum dia precisar mover uma delas**: primeiro atualize o caminho dentro da
skill, reinstale a skill, e só depois mova a pasta. Nunca na ordem inversa.

## O que fica no repositório `Planejamento WorkFlow Guilherme\`

- `CLAUDE.md` — contexto permanente do projeto (versionado no Git/GitHub)
- `Mapa mental\` — imagens e pptx do ecossistema
- Documentos de planejamento de alto nível

As skills saíram daqui para as pastas de tema (ver regra geral acima). Isso significa
que elas **não estão mais sob controle de versão do Git** — o histórico antigo
continua no repositório, mas alterações novas não são mais versionadas
automaticamente.
