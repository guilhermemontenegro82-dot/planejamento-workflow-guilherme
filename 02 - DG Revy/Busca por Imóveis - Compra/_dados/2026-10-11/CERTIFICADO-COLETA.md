CERTIFICADO DE COLETA — rodada 2026-10-11
Emitido por: busca-imoveis-atualizar (primeira rodada real, executada passo a passo pelo Claude Code em 11/10/2026)

Fontes (exit code do coletor | linhas no bruto | cobertura declarada pelo site):
- VIVAREAL    exit 0 | 5177 linhas | 100 % em todas as consultas (Ipanema 475/476, Leblon 182/182, Copacabana 4520 em 8 faixas, todas completas) | 19:12–19:28, 615 s
- QUINTOANDAR exit 0 | 101 linhas  | hits.total.value 101 = 101 obtidos; 101 páginas de anúncio ok | 19:17–19:21, 252 s
- CHAVESNAMAO exit 0 | 581 linhas  | caixa Ipanema_Arpoador 603/603, caixa Leblon 132/132, complemento level3 (trava do site, só +novos); 716 únicos, 135 excluídos por tipo não residencial, 581 aceitos; detalhes 581/581 | 19:17–19:25, 487 s
Fontes indisponíveis: nenhuma

Consolidação (consolidar.ps1, regras de área v2, 20:58–21:01):
- aceitos: 5826 (VIVAREAL 5168 | QUINTOANDAR 95 | CHAVESNAMAO 563); fora dos critérios na reconferência local: 33 (todos por tipo: Cobertura 15, Flat 18 — tipos_incluidos = Apartamento, Kitnet/Studio)
- área: SIM 787 | LIMITE 169 | A CONFIRMAR 65 | NAO 4805
- vão para a planilha (≠ NAO): 1021
- duplicatas: 83 grupos por endereço+número (D) e 88 só por rua/CEP sem número (P)

Arquivos: coleta.csv (5826 linhas, SHA256 5406D62B00B7), bruto-vivareal.csv, bruto-quintoandar.csv, bruto-chavesnamao.csv, coletar-*.log, consolidar.log, consolidar-resumo.json, json\<fonte>\

Premissas desta rodada:
1. VivaReal coletado SEM o agrupamento da API (categoryPage=RESULT desligado): ids estáveis; anúncios irmãos entram como linhas separadas e o consolidador marca POSSÍVEL DUPLICATA (decisão registrada no CLAUDE.md).
2. IPTU sem rótulo confiável (VivaReal e Chaves na Mão): valor <= 700 lido como cota mensal, > 700 como anual (÷12); iptu_informado guarda o cru.
3. Regras de área v2 (CONTRATO-DADOS.md): a lista de ruas pesa como conferência; rua incluída + coordenada dentro ou até 50 m fora = SIM; via pendente = LIMITE; rua não listada dentro do polígono a mais de 50 m da borda = SIM.
4. Cobertura e Flat ficaram fora por tipo (33 anúncios): a confirmar com o Guilherme.
5. Av. N. S. de Copacabana (trecho final) e Rua Francisco Sá seguem como vias pendentes (LIMITE / A CONFIRMAR): decisão do Guilherme.

Detalhe dos logs:
VIVAREAL:
2026-10-11 19:20:00     obtidos 505 (505 novos) de totalCount 505 em 17 pagina(s)
2026-10-11 19:28:02   Ipanema     R$    500000-  1100000: totalCount   476 | obtidos   476 | novos   475 | paginas  16
2026-10-11 19:28:02   Leblon      R$    500000-  1100000: totalCount   182 | obtidos   182 | novos   182 | paginas   7
2026-10-11 19:28:02   Copacabana  R$    500000-   575000: totalCount   305 | obtidos   305 | novos   305 | paginas  11
2026-10-11 19:28:02   Copacabana  R$    575001-   650000: totalCount   761 | obtidos   761 | novos   761 | paginas  26
2026-10-11 19:28:02   Copacabana  R$    650001-   725000: totalCount   768 | obtidos   768 | novos   768 | paginas  26
2026-10-11 19:28:02   Copacabana  R$    725001-   762500: totalCount   458 | obtidos   458 | novos   458 | paginas  16
2026-10-11 19:28:02   Copacabana  R$    762501-   800000: totalCount   535 | obtidos   535 | novos   535 | paginas  18
2026-10-11 19:28:02   Copacabana  R$    800001-   875000: totalCount   565 | obtidos   565 | novos   565 | paginas  19
2026-10-11 19:28:02   Copacabana  R$    875001-   950000: totalCount   623 | obtidos   623 | novos   623 | paginas  21
2026-10-11 19:28:02   Copacabana  R$    950001-  1100000: totalCount   505 | obtidos   505 | novos   505 | paginas  17
QUINTOANDAR:
2026-10-11 19:21:59  total informado pela API (hits.total.value): 101
2026-10-11 19:21:59  linhas gravadas em bruto-quintoandar.csv: 101
2026-10-11 19:21:59  RESULTADO: COMPLETO (exit 0)
CHAVESNAMAO:
19:18:17 Caixa Ipanema_Arpoador: totalResults(site)=603 | itens recebidos=603 | novos (não vistos antes)=603 | lotes ok=41 falha=0
19:18:24 Caixa Leblon: totalResults(site)=132 | itens recebidos=132 | novos (não vistos antes)=110 | lotes ok=9 falha=0
19:18:35   level3-ipanema pg=16 veio com 'similares' da cidade (pageBreak=[251,0,5097], totalListing=5348): fim dos resultados reais
19:18:35 Escopo level3-ipanema: totalListing(site)=251 (reais=251) | itens recebidos=225 | fora da caixa=0 | novos=2 | páginas ok=15 falha=0 | pg=16 veio com 'similares' da cidade (pageBreak=[251,0,5097], totalListing=5348): fim dos resultados reais
19:18:35   AVISO: recebidos < resultados reais declarados em level3-ipanema (o endpoint 'lista' mistura 'similares' nas últimas ~2 páginas e perde ~25 anúncios; use -Endpoint mapa)
19:18:38   level3-leblon pg=5 veio com 'similares' da cidade (pageBreak=[76,0,5319], totalListing=5395): fim dos resultados reais
19:18:38 Escopo level3-leblon: totalListing(site)=76 (reais=76) | itens recebidos=60 | fora da caixa=0 | novos=1 | páginas ok=4 falha=0 | pg=5 veio com 'similares' da cidade (pageBreak=[76,0,5319], totalListing=5395): fim dos resultados reais
19:18:38   AVISO: recebidos < resultados reais declarados em level3-leblon (o endpoint 'lista' mistura 'similares' nas últimas ~2 páginas e perde ~25 anúncios; use -Endpoint mapa)
19:18:39 Aceitos: 581 | excluídos: fora de área=0, fora de preço=0, não é venda=0, sem preço/área=0, tipo não residencial=135
19:25:55   Caixa Ipanema_Arpoador: totalResults(site)=603 | itens recebidos=603 | novos (não vistos antes)=603 | lotes ok=41 falha=0
19:25:55   Caixa Leblon: totalResults(site)=132 | itens recebidos=132 | novos (não vistos antes)=110 | lotes ok=9 falha=0
19:25:55   Escopo level3-ipanema: totalListing(site)=251 (reais=251) | itens recebidos=225 | fora da caixa=0 | novos=2 | páginas ok=15 falha=0 | pg=16 veio com 'similares' da cidade (pageBreak=[251,0,5097], totalListing=5348): fim dos resultados reais
19:25:55   Escopo level3-leblon: totalListing(site)=76 (reais=76) | itens recebidos=60 | fora da caixa=0 | novos=1 | páginas ok=4 falha=0 | pg=5 veio com 'similares' da cidade (pageBreak=[76,0,5319], totalListing=5395): fim dos resultados reais
19:25:55   Únicos na busca: 716 | aceitos (critérios): 581 | linhas no CSV: 581
19:25:55   Falhas de rede após 3 tentativas: 0 | escopos com cobertura truncada: 0
19:25:55 RESULTADO: COMPLETO (exit 0)