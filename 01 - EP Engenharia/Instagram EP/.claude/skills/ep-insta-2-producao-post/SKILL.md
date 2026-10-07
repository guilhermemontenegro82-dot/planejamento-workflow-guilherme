---
name: ep-insta-2-producao-post
description: Etapa 2 da rotina Instagram EP. Produz um post aprovado - cria a pasta numerada, brief, carrossel slide a slide, legenda, stories e, conforme o modo, os prompts de imagem (Modo A) ou a seleção de fotos reais da obra (Modo B). Roda os 2 chequers de texto e apresenta ao Guilherme. Use após a aprovação registrada ("produz o P05", "monta o tema 2").
---

# Etapa 2 — Produção do post · Instagram EP

Anuncie-se: `▶ ep-insta-2-producao-post — Etapa 2 iniciada (Pnn)`.
Raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`.
Leia antes: `ROTINA.md`, `00-Marca/voz-e-tom.md`, `00-Marca/identidade-visual.md`, `CALENDARIO.md`, o arquivo de `02-Pesquisa-temas/` com a decisão, e a `legenda.txt` de `01-Posts/P02_2026-07-02_sinais-estruturais/` (padrão de referência da legenda).

## 0. Trava de entrada (recuse se faltar qualquer um)
1. `02-Pesquisa-temas/AAAA-Snn_temas.certificado.md` existe com `VEREDITO: APROVADO`.
2. A seção `## Decisão do Guilherme` do arquivo de temas está preenchida e cita o tema que você vai produzir.
3. `CALENDARIO.md` tem a linha do `Pnn` com status `aprovado`, data e modo.
Se faltar: pare e diga exatamente o que falta. Não produza "mesmo assim".

## 1. Criar a pasta
- `Pnn` = o número da linha do CALENDARIO. Nome: `Pnn_AAAA-MM-DD_tema-curto` (data de publicação; tema em minúsculas, sem acento, hífens; campanha paga → sufixo `_campanha-paga`).
- Copie `01-Posts/_modelo-post/` inteiro (PowerShell `Copy-Item -Recurse`). Mantenha `00-certificados/`.

## 2. Brief — `01-brief/brief.md`
Preencha todos os campos do modelo com a pesquisa e a decisão. Campo **Modo** obrigatório. Modo B: obra, semana (`Sxx`) e caminho da pasta de fotos.

## 3. Textos — `02-textos/`
**carrossel.md** — 6 a 9 slides, um cabeçalho `## Slide n` por slide:
- Slide 1 capa: `Tag:` (pilar, caixa alta), `Título:` (máx. 2 linhas, 1 palavra marcada com **asteriscos** = destaque em ciano), `Apoio:` (1 linha), `Fundo:` (foto gerada / foto real `<arquivo>` / fundo claro).
- Slides internos: `Badge:` (01, 02…), `Título:` (máx. 2 linhas), `Corpo:` (máx. 3 linhas, ~160 caracteres), `Fundo:`. Um argumento por slide. Sempre o porquê técnico em linguagem simples.
- Penúltimo: como a EP faz, sem se gabar.
- Último (CTA): `Frase:` + `Contato: (21) 98355-0728 · epengenharia.eng.br` + "primeira visita é gratuita" quando couber.
- **Modo B**: cada slide com foto real recebe `Legenda da foto: Caso real · obra EP`. Descreva o que a foto mostra de verdade (abra a foto com Read antes de escrever). Nunca invente etapa que a foto não mostra.
- **Modo A**: nenhum slide ou legenda diz "obra nossa", "nossa equipe fez", "antes e depois da EP" ou similar.

**legenda.txt** — mesmo formato da legenda de referência (P02): cabeçalho `LEGENDA — Carrossel "<título>"` + `(EP Engenharia · @engenharia.ep · post de DD/MM)`, bloco `TEXTO PARA COLAR NO INSTAGRAM`, bloco `HASHTAGS`, bloco `COMO POSTAR`. Estrutura do texto: `voz-e-tom.md` (gancho → contexto → lista 1️⃣… → posicionamento → CTA com `(21) 98355-0728` e `epengenharia.eng.br`).
Hashtags: 18 a 24, **somente letras sem acento, números e underline** (`#construcaocivil`, nunca `#construçãocivil`; nunca ponto: `#engenhariaep`, não `#engenharia.ep`). Mistura fixa + do tema (`voz-e-tom.md`).
Bloco COMO POSTAR: ordem das imagens (`slide-01.png` … ), data e horário do CALENDARIO, "programar no Business Suite" e, se houver, o story a publicar no mesmo dia.

**stories.txt** — bloco `STORY PRINCIPAL` (pergunta/provocação em 3 linhas curtas, frase de virada, ponte com a palavra `feed`, ≤ 160 caracteres) + bloco `ALTERNATIVA`. Indicar sticker (link / enquete) se fizer sentido.

Regras de texto: `voz-e-tom.md` é lei. "Empresa", nunca "empreiteiro". Frases curtas. Poucos emojis. Nada de "incrível", "maravilhoso", "barato".

## 4. Imagens-fonte — `03-prompts-imagem/`
**Modo A → `prompts.md`.** Um prompt por slide que precisa de imagem + um por story. Em inglês, seguido de 1 linha em português dizendo o que é. Cada prompt contém: cena concreta de obra/ambiente brasileiro de alto padrão, realista, fotográfica, luz natural; `portrait` com proporção `4:5` (slides) ou `9:16` (story); área livre para texto ("lower two-thirds darker and uncluttered for text overlay"); paleta fria azulada (exceto campanha "dor real"); as palavras `no text`, `no logo`, `no watermark`, `no recognizable faces`; e o nome do arquivo alvo `slide-NN.png` / `story-NN.png`. Slides de fundo claro: escreva `SEM IMAGEM — fundo claro padrão`.
Deixe `fotos-escolhidas.md` como está (modelo vazio).

**Modo B → `fotos-escolhidas.md`.** Origem das fotos: a pasta liberada `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP\<obra>\<Sxx>\Fotos\` (só leitura), ou `04-imagens-brutas/candidatas/` se o Guilherme tiver copiado fotos para o post. Abra (Read) as fotos da obra/semana indicadas na decisão dele antes de escolher.
Para cada slide com foto: `slide-NN.png ← <caminho completo da foto>`, o que ela mostra, e o enquadramento sugerido (`centro`, `topo`, `base`; o recorte 4:5 é feito na etapa 3). Escolha fotos nítidas, sem rosto reconhecível em primeiro plano, sem documento, placa de rua, nome de cliente ou número de apartamento legível. **Só cite o caminho; não copie nem mova a foto da origem** (a etapa 3 faz isso).
Deixe `prompts.md` como está (modelo vazio).

## 5. Calendário
`CALENDARIO.md`: status do `Pnn` → `textos`, coluna Pasta = nome da pasta.

## 6. Conferência (obrigatória, nesta ordem)
1. Agent → `agente-insta-chequer-texto-tecnico` (pasta do post, `CALENDARIO.md`). Grava `00-certificados/02-texto-tecnico.certificado.md`.
2. Só com o técnico APROVADO: Agent → `agente-insta-chequer-texto-conteudo` (pasta do post, arquivo de temas, `00-Marca/*.md`, legenda de referência). Grava `00-certificados/02-texto-conteudo.certificado.md`.
REPROVADO → corrija só o apontado e invoque de novo o mesmo chequer. Máximo 2 rodadas por chequer; depois pare e mostre ao Guilherme o que foi apontado.

## 7. Apresentar (Decisão 2 do Guilherme)
No chat: título da capa, lista dos slides em 1 linha cada, a legenda completa, o story, e (Modo B) as fotos escolhidas em miniatura por nome. Linha final: "Certificados: técnico APROVADO (rodada n) · conteúdo APROVADO (rodada n)". Pergunte: **"Aprova os textos ou quer ajustes?"**
Quando ele aprovar, grave `00-certificados/02-textos.decisao-guilherme.md` com a data e o texto literal da resposta. Ajustes pedidos → aplique, rode de novo os 2 chequers, apresente de novo.
Depois, diga o próximo passo: Modo A → "cole os prompts de `03-prompts-imagem/prompts.md` no ChatGPT e salve em `04-imagens-brutas/` com os nomes indicados; depois peça `ep-insta-3-imagens`". Modo B → "peça `ep-insta-3-imagens`".

## Prestação de contas (sempre, no fim)
```
=== ETAPA 2 — PRESTAÇÃO DE CONTAS (Pnn) ===
Trava de entrada: certificado pesquisa OK · decisão OK · calendário OK
Pasta criada: … · Modo: A|B · Slides: n · Hashtags: n · Fotos reais lidas: n
Chequer técnico: INVOCADO rodada n → APROVADO | NÃO INVOCADO (motivo)
Chequer conteúdo: INVOCADO rodada n → APROVADO | NÃO INVOCADO (motivo)
Decisão do Guilherme: registrada | aguardando
=== FIM ===
```

## Não faça
- Não altere P01 a P04 nem qualquer post anterior.
- Não gere arte final, não copie fotos, não agende (etapas 3 e 4).
- Não escreva o certificado dos chequers você mesmo. Se o Agent não rodou, a prestação de contas diz NÃO INVOCADO.
