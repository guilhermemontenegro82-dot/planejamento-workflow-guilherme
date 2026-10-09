---
name: ep-insta-3-imagens
description: Etapa 3 da rotina Instagram EP. Modo A - confere as imagens que o Guilherme gerou no ChatGPT e salvou em 04-imagens-brutas. Modo B - copia e recorta as fotos reais escolhidas para 04-imagens-brutas. Roda o chequer de imagens e grava o certificado que libera a arte final. Use quando ele avisar que as imagens estão na pasta ("imagens já estão na pasta", "fotos escolhidas").
---

# Etapa 3 — Imagens · Instagram EP

Anuncie-se: `▶ ep-insta-3-imagens — Etapa 3 iniciada (Pnn)`.
Raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`. Leia o `01-brief/brief.md` (modo), `03-prompts-imagem/prompts.md` (Modo A) ou `fotos-escolhidas.md` (Modo B).

## 0. Trava de entrada
`00-certificados/02-textos.decisao-guilherme.md` existe (ele aprovou os textos). Sem ele, pare.

## 1. Modo A — imagens geradas pelo Guilherme
1. Liste `04-imagens-brutas/` (PowerShell + System.Drawing: nome, largura, altura, KB). Esperado: um arquivo para cada `## slide-NN.png` / `## story-01.png` de `prompts.md` que tenha prompt (os `SEM IMAGEM` não contam).
2. Abra (Read) **cada** imagem e anote em 1 linha o que mostra. Reprove na hora, antes do chequer, se houver texto, letras, logo, marca d'água ou rosto reconhecível: peça ao Guilherme para gerar de novo aquela imagem com o mesmo prompt mais "absolutely no text or letters anywhere".
3. Proporção: slides ≈ 4:5 (largura/altura entre 0,78 e 0,82) ou 2:3 (0,66 a 0,68, padrão do ChatGPT; a arte final recorta); story ≈ 9:16 (0,54 a 0,60). Largura mínima 1000 px (slides) e 900 px (story). Fora disso: pedir nova geração.
4. Não renomeie, não converta, não edite as imagens. O recorte é da etapa 4.

## 2. Modo B — fotos reais
1. Para cada linha de `fotos-escolhidas.md` (`slide-NN.png ← <caminho>`): confira que o arquivo de origem existe; abra (Read) e confirme o que a foto mostra e que não há rosto reconhecível, documento, placa ou nome de cliente legível.
2. Copie a foto para `04-imagens-brutas/<alvo>` com PowerShell `Copy-Item` (**origem nunca é alterada; nada é criado, movido ou apagado no OneDrive**). Se o enquadramento pedir recorte, recorte **a cópia** com System.Drawing (4:5 para slides, 9:16 para story), gravando por cima da cópia.
3. Registre em `04-imagens-brutas/origem.md`: alvo ← origem, data, recorte aplicado.

## 3. Conferência (obrigatória)
Agent → `agente-insta-chequer-imagens` (pasta do post). Grava `00-certificados/03-imagens.certificado.md`. REPROVADO → corrija só o apontado (Modo A: pedir nova geração ao Guilherme; Modo B: trocar foto ou recorte) e invoque de novo. Máximo 2 rodadas.

## 4. Fechar
`CALENDARIO.md`: status → `imagens`. No chat: lista das imagens (1 linha cada, o que mostram) e "Certificado de imagens: APROVADO (rodada n)". Diga: "Próximo passo: `ep-insta-4-arte-final`."

## Prestação de contas
```
=== ETAPA 3 — PRESTAÇÃO DE CONTAS (Pnn) ===
Trava: decisão de textos OK · Modo: A|B · Imagens esperadas n / presentes n / abertas n
Modo B: copiadas n · recortadas n · OneDrive intocado: sim
Chequer de imagens: INVOCADO rodada n → APROVADO | NÃO INVOCADO (motivo)
CALENDARIO: imagens
=== FIM ===
```

## Não faça
- Não gere imagem, não edite a imagem gerada, não escolha foto diferente da listada sem avisar.
- Nunca escreva, mova ou apague nada no OneDrive. Copiar DE lá PARA o post é o único movimento.
