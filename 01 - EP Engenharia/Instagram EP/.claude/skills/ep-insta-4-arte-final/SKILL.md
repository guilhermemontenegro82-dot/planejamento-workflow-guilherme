---
name: ep-insta-4-arte-final
description: Etapa 4 da rotina Instagram EP. Monta o arte.json a partir dos textos aprovados e das imagens do post, renderiza os PNGs 1080x1350 (slides) e 1080x1920 (story) com os templates HTML e o Edge headless, roda o chequer de arte final e monta o pacote de publicação em 03-Fila-publicacao. Use quando as imagens do post estiverem prontas ("gera a arte do P05", "arte final").
---

# Etapa 4 — Arte final · Instagram EP

Anuncie-se: `▶ ep-insta-4-arte-final — Etapa 4 iniciada (Pnn)`.
Raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`. Leia antes `00-Marca/identidade-visual.md` e os arquivos do post: `01-brief/brief.md`, `02-textos/carrossel.md`, `02-textos/stories.txt`, `02-textos/legenda.txt`.
Ferramentas: `00-Marca/templates/render-arte.ps1` (PowerShell + Edge headless; não precisa de Python). Templates: `capa`, `interno-claro`, `interno-foto`, `cta`, `story`.

## 0. Trava de entrada (recuse se faltar)
1. `00-certificados/02-textos.decisao-guilherme.md` existe (ele aprovou os textos).
2. `00-certificados/03-imagens.certificado.md` com `VEREDITO: APROVADO` (etapa 3 conferiu as imagens).
3. `04-imagens-brutas/` tem `slide-NN.png` para cada slide que pede imagem e `story-01.png`.
Se faltar: pare e diga o que falta. Exceção única: teste de mesa em `_trabalho/`, nunca dentro de `01-Posts/`.

## 1. Montar `05-arte-final/arte.json`
Um objeto por slide, na ordem do `carrossel.md`:
- `tag` da capa = `Tag:` do slide 1 (caixa alta, o template cuida). `handle` = `@ENGENHARIA.EP`. `rotulo` = palavra usada no post para numerar (ex.: `Sinal`, `Passo`, `Mito`). `secao` = etiqueta do canto (ex.: `ATENÇÃO`, `BASTIDORES`).
- Mapa `Fundo:` → tipo de template:
  - slide 1 → `capa` com `fundo` = `04-imagens-brutas/slide-01.png`
  - `Fundo: fundo claro` → `interno-claro` (sem foto, ou com `foto` = `04-imagens-brutas/slide-NN.png` se existir)
  - `Fundo: foto gerada` ou `Fundo: foto real <arquivo>` em slide interno → `interno-foto` com `fundo` = a imagem; `legenda_foto` = `Caso real · obra EP` **só em Modo B** (foto real). Em Modo A deixe `legenda_foto` vazio.
  - último slide → `cta` com `fundo` = `04-imagens-brutas/slide-NN.png`, `contato` = `**(21) 98355-0728** · epengenharia.eng.br` + linha `Primeira visita é gratuita.` quando o carrossel.md tiver, `botao` = `Chame no direct · @engenharia.ep`.
- Destaque do título: o trecho entre `**` no carrossel.md vai como está (o renderizador pinta de ciano). Negrito no corpo também usa `**`.
- `n` e `total` dos slides internos = numeração do badge (não conta capa nem CTA).
- `story`: `tag`, `titulo` (3 linhas curtas, última palavra entre `**`), `apoio`, `ponte` (`Expliquei tudo **no feed**`), `fundo` = `04-imagens-brutas/story-01.png`.
Caminhos no JSON são relativos à pasta do `arte.json` (ex.: `../04-imagens-brutas/slide-01.png`).

## 2. Renderizar
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\00-Marca\templates\render-arte.ps1" -Json "<post>\05-arte-final\arte.json" -OutDir "<post>\05-arte-final"
```
Saída: `slide-01.png … slide-NN.png`, `story-01.png` e a pasta `_html/` (HTML de cada peça, usada pelo chequer). Leva ~4 s por peça. Abra (Read) **todas** as peças e olhe: texto cortado, título em 4+ linhas, foto errada, logo ausente. Corrija o `arte.json` (quebra de linha com `\n` no título, texto mais curto só com aprovação do Guilherme) e renderize de novo.

## 3. Conferência (obrigatória)
Agent → `agente-insta-chequer-arte-final` (pasta do post). Grava `00-certificados/04-arte-final.certificado.md`. REPROVADO → corrija só o apontado e invoque de novo. Máximo 2 rodadas; depois pare e mostre ao Guilherme.

## 4. Pacote de publicação — `03-Fila-publicacao/Pnn_AAAA-MM-DD_tema/`
Só com certificado APROVADO. Copie para lá: os PNGs na ordem (`01.png`, `02.png`… para facilitar a seleção no Business Suite), `story-01.png`, `legenda.txt` e um `agendamento.md`:
```
# Agendamento — Pnn · <título>
Conta: @engenharia.ep (Meta Business Suite → Criar publicação → Instagram)
Data/hora: AAAA-MM-DD (quinta) 18:30   ← do CALENDARIO
Carrossel: 01.png … NN.png nesta ordem · Legenda: colar o bloco TEXTO + HASHTAGS de legenda.txt
Story: story-01.png no mesmo dia, 19:00, com sticker de link para o post
Depois de programar, responda "agendado" no chat.
```
`CALENDARIO.md`: status → `arte-final`.

## 5. Apresentar (Decisão 3 do Guilherme)
No chat: caminho do pacote, lista das peças, 1 linha "Certificado de arte: APROVADO (rodada n)". Peça: **"Abra a pasta, veja a prévia e diga 'pode agendar' ou o que ajustar."**
Quando ele disser "pode agendar": grave `00-certificados/04-arte.decisao-guilherme.md` com data e texto literal. Quando ele disser "agendado": acrescente a data/hora programada ao mesmo arquivo e mude o `CALENDARIO.md` para `agendado`.

## Prestação de contas
```
=== ETAPA 4 — PRESTAÇÃO DE CONTAS (Pnn) ===
Trava: decisão textos OK · certificado imagens OK · imagens brutas n/n
arte.json: n slides + story · Render: n peças ok em t s · Peças abertas e vistas: n/n
Chequer arte final: INVOCADO rodada n → APROVADO | NÃO INVOCADO (motivo)
Pacote: 03-Fila-publicacao/… (n arquivos) · CALENDARIO: arte-final
Decisão do Guilherme: aguardando | "pode agendar" DD/MM | agendado DD/MM HH:MM
=== FIM ===
```

## Não faça
- Não altere textos aprovados para "caber": se não couber, reduza o tamanho no `arte.json` (`\n`) ou peça ao Guilherme.
- Não publique nem agende: isso é ele, no Business Suite.
- Não escreva o certificado do chequer você mesmo.
