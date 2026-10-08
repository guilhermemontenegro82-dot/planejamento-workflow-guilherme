VEREDITO: APROVADO
Chequer: agente-insta-chequer-arte-final
Alvo: D:\12- Claude - works\01 - EP Engenharia\Instagram EP\_trabalho\teste-P02
Data: 2026-10-08 18:12 · Rodada: 2 · Modo: B

[1 PASS 7 slides + story] [2 PASS 1080x1350 ×7, 1080x1920] [3 PASS mín 65,7 KB / máx 1,3 MB] [4 PASS 7/7 idênticos] [5 PASS] [6 PASS] [7 PASS] [8 PASS] [9 PASS] [10 PASS] [11 PASS] [12 n/a]
Peças abertas: 8/8
Falhas: nenhuma

Medições (rodada 2):
- Item 3 (piso 40 KB): slide-01 829,3 KB · slide-02 459,0 KB · slide-03 481,8 KB · slide-04 65,7 KB · slide-05 1.311,9 KB · slide-06 67,1 KB · slide-07 805,0 KB · story-01 1.176,8 KB. Os dois slides claros sem foto (04 e 06) ficam em ~66 KB, acima do piso de 40 KB e dentro do esperado para fundo liso.
- Item 4: título e corpo dos 7 slides (e Frase/Botão do CTA; Apoio/Tag da capa) aparecem literalmente nos HTMLs, sem `**`. Story: as 6 linhas do STORY PRINCIPAL (tag, 3 perguntas, apoio, ponte) aparecem literalmente. Badge "01…05" do .md renderiza como "1…5" (não é divergência, conforme item 7). Contato do CTA quebra em 2 linhas sem o segundo "·" (campo secundário, não bloqueia).
- Item 7: badges 1–5 corretos; títulos em 2 linhas; corpos em 3–4 linhas; painéis de foto inteiros nos slides 2 e 3; logo pequeno no rodapé. Barra de progresso nos interno-claro (2, 3, 4, 6) batendo com 1/5, 2/5, 3/5 e 5/5; slide 5 (interno-foto) sem barra, com "SINAL 4 DE 5" em texto, conforme a rubrica.
- Item 9: último pixel de texto do rodapé do story ("ARRASTE P/ CIMA") em y = 1656; de 1657 a 1919 nenhum pixel claro (luminância máxima 71). Faixa livre: 263 px (exigido ~220). Corrigido em relação à rodada 1 (era 190 px, texto em y 1700–1739).
- Item 10: "Caso real · obra EP" nos slides 2, 3 e 5 (os três com foto real); ausente nos slides 4 e 6 (fundo claro) e na capa/CTA (fundo "foto gerada" no .md).
- Item 11: 6/6 caminhos do arte.json existem, resolvidos a partir da pasta do arte.json, todos em 01-Posts\P03_2026-07-02_empresa-sumiu_campanha-paga\Fotos Campanha\ (Slide 2, 3, 4, 5, 6, 7.png).
- edge-stderr.log: só avisos internos do Edge headless; 1.205.050 bytes gravados no story, sem erro de renderização.
