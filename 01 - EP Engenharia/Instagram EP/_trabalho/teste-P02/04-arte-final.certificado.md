VEREDITO: REPROVADO
Chequer: agente-insta-chequer-arte-final
Alvo: D:\12- Claude - works\01 - EP Engenharia\Instagram EP\_trabalho\teste-P02
Data: 2026-10-08 18:07 · Rodada: 1 · Modo: B

[1 PASS 7 slides + story] [2 PASS 1080x1350 ×7, 1080x1920] [3 FAIL mín 65,7 KB / máx 1,3 MB] [4 PASS 7/7 idênticos] [5 PASS] [6 PASS] [7 PASS] [8 PASS] [9 FAIL] [10 PASS] [11 PASS] [12 n/a]
Peças abertas: 8/8
Falhas:
- Item 3, slide-04.png: 67.283 bytes (65,7 KB) — abaixo do mínimo de 150 KB. Visualmente a peça está completa (badge 3, título, corpo, barra, logo); o peso baixo vem do fundo claro liso sem foto, não de peça vazia. Pela rubrica, FAIL.
- Item 3, slide-06.png: 68.708 bytes (67,1 KB) — abaixo do mínimo de 150 KB. Mesma situação: peça completa, fundo claro liso sem foto. Pela rubrica, FAIL.
- Item 9, story-01.png: o texto "ARRASTE P/ CIMA" ocupa as linhas y 1700–1739 e invade a faixa inferior protegida (últimos ~220 px = y ≥ 1700). Faixa realmente livre abaixo do último texto: 190 px. Falta subir o rótulo ~40 px (ou removê-lo). O restante do story está em ordem: logo, pílula "⚠ SINAL DE ALERTA", título em 3 linhas, "no feed", círculo com mão.

Observações (não bloqueantes, para a skill 4 avaliar):
- Item 4: título e corpo de todos os 7 slides aparecem literalmente no HTML (7/7). Dois campos secundários divergem da forma escrita no carrossel.md: (a) Badge "01…05" no .md é renderizado como "1…5" (sem zero à esquerda) nos slides 2–6; (b) Contato do CTA no .md é uma linha única "(21) 98355-0728 · epengenharia.eng.br · Primeira visita é gratuita." e no HTML vira duas linhas, sem o segundo "·" (o arte.json já traz assim). Nenhum dos dois é título ou corpo, por isso não derrubam o item 4.
- Item 7: o slide-05 (layout interno-foto) não tem barra de progresso; mostra só "SINAL 4 DE 5" em texto. Os slides claros (2, 3, 4, 6) têm barra coerente com 1/5, 2/5, 3/5 e 5/5. Se a barra for obrigatória em todo interno, o template interno-foto precisa recebê-la.
- Item 11: os caminhos do arte.json (../../01-Posts/P03_…/Fotos Campanha/Slide N.png) resolvem a partir da raiz da pasta de teste (onde o arte.json está); 6/6 existem. Resolvidos a partir de arte-final/ não existiriam — num post real, com arte.json em 05-arte-final/, conferir qual é a base de resolução.
- Item 10: "Caso real · obra EP" aparece nos slides 2, 3 e 5 (os três com foto no painel/fundo) e em nenhum outro, conforme o carrossel.md. Capa e CTA usam fundo "foto gerada" segundo o .md, sem legenda — correto.
- edge-stderr.log registra apenas avisos internos do Edge headless; nenhum erro de renderização.
