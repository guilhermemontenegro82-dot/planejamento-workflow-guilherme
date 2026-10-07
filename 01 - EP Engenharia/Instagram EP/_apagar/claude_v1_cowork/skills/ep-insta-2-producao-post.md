---
name: ep-insta-2-producao-post
description: Produz um post aprovado do Instagram da EP Engenharia - cria a pasta numerada, brief, textos do carrossel/reels, legenda, stories e os prompts de imagem para o ChatGPT. Use após a aprovação de um tema ("produz o post", "monta o tema 2").
---

# Produção de post — Instagram EP

Pasta raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP` (pasta conectada "Instagram EP").
Leia antes: `00-Marca/voz-e-tom.md`, `00-Marca/identidade-visual.md`, `CALENDARIO.md` e o arquivo da pesquisa em `02-Pesquisa-temas/` que contém o tema aprovado. Leia também a `legenda.txt` de 1 post anterior em `01-Posts/` pra manter o padrão.

## 1. Criar a pasta do post
- Próximo número = maior `Pnn` em `01-Posts/` + 1.
- Nome: `Pnn_AAAA-MM-DD_tema-curto` (data de publicação aprovada; tema em minúsculas, sem acento, hífens; campanha paga → sufixo `_campanha-paga`).
- Copie `01-Posts/_modelo-post/` inteiro pra dentro dela.

## 2. Brief (`01-brief/brief.md`)
Preencha todos os campos do modelo com base na pesquisa e na decisão do Guilherme. Marque se há fotos reais (pergunte a ele só se for decisivo; senão assuma "gerar imagem").

## 3. Textos (`02-textos/`)
**carrossel.md** — slide a slide, 6 a 9 slides:
- Slide 1 capa: tag do pilar, título (máx. 2 linhas, 1 palavra em destaque), apoio curto.
- Slides internos: badge numerado, título bold (máx. 2 linhas), corpo máx. 3 linhas (~160 caracteres). Um argumento por slide. Explicar o porquê técnico de forma simples.
- Penúltimo slide: posicionamento EP (como a gente faz) sem se gabar.
- Último slide CTA: frase + "(21) 98355-0728 · epengenharia.eng.br" + "primeira visita é gratuita" quando couber.
- Se for reels: escreva roteiro com cenas numeradas (texto na tela + fala/legenda), 30–45 s.

**legenda.txt** — mesmo formato dos posts anteriores: cabeçalho com nº/data/título, bloco "TEXTO PARA COLAR", bloco "HASHTAGS" (18–24, fixas + do tema), bloco "COMO POSTAR" (ordem das imagens e horário).

**stories.txt** — 1 story principal (pergunta/provocação em 3 linhas curtas, frase de virada, ponte "Expliquei tudo no feed") + 1 alternativa. Indicar sticker de link/enquete se fizer sentido.

Regras de texto: `voz-e-tom.md` é lei. "Empresa", nunca "empreiteiro". Frases curtas. Poucos emojis.

## 4. Prompts de imagem (`03-prompts-imagem/prompts.md`)
Um prompt por slide que precise de imagem + um por story. Em inglês (o ChatGPT gera melhor), seguido de 1 linha em português dizendo o que é.
Cada prompt deve conter:
- Cena concreta de obra/ambiente brasileiro de alto padrão (apartamento no Rio, canteiro organizado, estrutura de concreto, etc.), realista, fotográfico, luz natural.
- Proporção: `4:5 vertical` para slides, `9:16 vertical` para stories.
- Composição com **área livre** onde entra o texto (ex.: "lower two-thirds slightly darker and uncluttered for text overlay").
- Paleta: tons frios azulados, sombras profundas, nada de laranja/amarelo forte (exceto campanha "dor real").
- **Sem texto, sem logos, sem marcas d'água, sem pessoas reconhecíveis** na imagem.
- Nome do arquivo esperado (slide-01.png, story-01.png…).
Para slides de fundo claro (estilo "lista"), escreva "SEM IMAGEM — fundo claro padrão" em vez de prompt.

## 5. Fechar
- Atualize `CALENDARIO.md`: status → `textos`, coluna Pasta.
- No chat, mostre: título da capa, lista dos slides em 1 linha cada, a legenda completa e o story. Pergunte se aprova os textos ou quer ajustes.
- Depois do OK, diga: "Próximo passo: gerar as imagens — cole os prompts de `03-prompts-imagem/prompts.md` no ChatGPT e salve em `04-imagens-brutas/`" (ou rode a skill `ep-insta-3-imagens` quando existir).

## Não faça
- Não altere posts anteriores.
- Não gere a arte final nem agende — são skills seguintes.
