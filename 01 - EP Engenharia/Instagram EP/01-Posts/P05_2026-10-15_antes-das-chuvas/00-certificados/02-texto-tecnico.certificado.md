VEREDITO: APROVADO
Chequer: agente-insta-chequer-texto-tecnico
Alvo: 01-Posts/P05_2026-10-15_antes-das-chuvas
Data: 2026-10-09 16:43 · Rodada: 3 · Modo: A

[1 PASS P05 (regex ok; maior anterior P04 + 1; 1 ocorrência, sem duplicata)] [2 PASS 5/5 (brief 1.644 · carrossel 2.073 · legenda 2.275 · stories 413 · prompts 3.939 chars; fotos-escolhidas.md fica como modelo, Modo A)] [3 PASS 0 placeholders nos 5 arquivos preenchidos (carrossel, legenda e stories re-medidos nesta rodada: 0)] [4 PASS data 2026-10-15 = pasta; Modo A] [5 PASS 8 slides] [6 PASS máx. título 52 / corpo 174 (slide 7, limite 180)] [7 PASS Tag/Título/Apoio na capa; 1 trecho em ** no título da capa; último slide = Slide 8 — CTA com (21) 98355-0728 e epengenharia.eng.br] [8 PASS 3/3 blocos] [9 PASS 22 hashtags, 0 inválidas, 0 duplicadas] [10 PASS telefone e site na legenda] [11 PASS 1.470 chars (texto 1.151 + hashtags 319; 1.472 contando a quebra entre os blocos)] [12 PASS 157 chars (Tag + 5 linhas de texto; 133 sem a Tag; 183 se contar a linha "Sticker:", que é instrução, não texto do story); contém "feed"] [13A PASS 6 prompts = 5 slides foto gerada (1, 3, 5, 7, 8) + 1 story; 3 slides SEM IMAGEM = 3 "fundo claro" (2, 4, 6)] [14A PASS 6/6 com 4:5 ou 9:16, "no text", "no logo", "no watermark"; arquivo alvo nomeado no cabeçalho `## slide-NN.png` / `## story-01.png` de cada prompt (0 dentro do bloco de código)] [15 PASS 0 ocorrências das 8 expressões da rubrica (4 gerais + 4 do Modo A) em brief, carrossel, legenda, stories, prompts e nos 3 LEIA-ME] [16 PASS status textos · modo A · Pasta = 01-Posts/P05_2026-10-15_antes-das-chuvas] [17 PASS 02-Pesquisa-temas/2026-S41_temas.certificado.md existe, VEREDITO: APROVADO (rodada 3)]

Falhas: nenhuma

Rodada 3 — o que foi re-medido (scripts _trabalho/medir-p05-r2.ps1 e _trabalho/medir-p05-r3.ps1), após as alterações pedidas pelo chequer de conteúdo em carrossel.md (slides 6, 7 e 8), legenda.txt (linhas 3️⃣ e 5️⃣, parágrafo "Na EP", CTA) e stories.txt (bloco ALTERNATIVA):
- Item 6 · corpos: 164, 159, 161, 166, 160, 174, 81 (slide 6 = 160, slide 7 = 174, slide 8 = 81). Títulos/Frase: 52, 25, 38, 18, 23, 27, 22, 43. Máximo corpo caiu de 179 para 174.
- Item 7 · frase do Slide 8 mudou ("Viu algum desses pontos? **Chame a gente.**"); linha "- Contato:" mantém telefone e site; capa inalterada (1 trecho em **).
- Item 9 · bloco HASHTAGS inalterado: 22 válidas, 0 duplicadas.
- Item 11 · texto subiu de 1.123 para 1.151 chars; hashtags 319; total 1.470 (limite 2.200).
- Item 12 · STORY PRINCIPAL = 157 chars (Tag + 5 linhas, sem "Sticker:"), contém "feed". ALTERNATIVA = 124 chars sem "Sticker:" (não entra no limite).
- Item 15 · varredura bruta de todos os .md/.txt do post: 0 ocorrências nos arquivos de conteúdo (brief, carrossel, legenda, stories, prompts, 3 LEIA-ME). As 5 ocorrências encontradas estão só em 00-certificados/02-texto-conteudo.certificado.md (o chequer de conteúdo cita as expressões por extenso para dizer que não aparecem); certificado não é texto do post, mesmo critério das rodadas 1 e 2.
- Item 2 · tamanhos atualizados (carrossel 2.106 → 2.073; legenda 2.247 → 2.275; stories 410 → 413). brief.md e prompts.md sem alteração (1.644 e 3.939, iguais à rodada 2), por isso as evidências de 4, 13A e 14A foram mantidas.
- Itens 1, 3, 5, 8, 10, 16 e 17 re-conferidos nesta rodada com os valores acima.

Premissas de medição: contagem = .Length após Trim(), leitura com Get-Content -Raw -Encoding UTF8; emoji conta como 2-3 unidades. Story principal = bloco entre "STORY PRINCIPAL" e "ALTERNATIVA", linhas de texto sem o cabeçalho; a linha "Sticker:" é indicação de recurso, por isso o número de referência é 157. Nenhum arquivo do post foi alterado além deste certificado.
