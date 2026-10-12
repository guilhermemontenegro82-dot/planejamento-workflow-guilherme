# Relatório — coletor e verificador do VivaReal / Zap Imóveis (11/10/2026)

Componente: `Skills\scripts\coletar-vivareal.ps1` e `Skills\scripts\verificar-vivareal.ps1`.
Pastas de teste: `_trabalho\testes-vivareal-r2\` (modo com dedup da API, hoje `-DedupApi`: duas coletas ao vivo,
18h30 e 18h37, mais o CSV/log do cache do meio-dia e as probes do construtor) e `_trabalho\testes-vivareal-r3\`
(**modo padrão atual, sem `categoryPage`**, coleta ao vivo das 18h58 — ver a seção "Decisão: sem categoryPage").
Tudo abaixo foi executado de verdade nesta máquina (Windows 10, PowerShell 5.1, curl.exe do Windows, sem
Python/Node/navegador).

## 1. O que foi feito

### Estado em que o componente foi encontrado
O construtor anterior entregou os dois scripts (35 KB + 12 KB) e foi interrompido antes do teste, sem relatório.
O último log (12:08, modo `-Reprocessar`) terminava com **"obtidos 0"** em todas as consultas e CSV vazio, e o
verificador terminava com **ERRO** num id que existe.

### Defeitos encontrados e corrigidos
1. **"obtidos 0" (coletor).** O caminho `search.result.listings[].listing.id` está certo nos JSONs do cache; o
   defeito estava em `Extrair-Listings`, que devolvia o array embrulhado (`return ,@($lista)`): o `@(...)` do
   chamador embrulhava de novo e cada "anúncio" virava o array inteiro, sem a chave `listing`. O arquivo em disco
   (gravado às 12:10:47, dois minutos depois do log) já trazia a troca por `return @($lista)` com o comentário
   explicando, mas nunca tinha sido rodado. Rodei o `-Reprocessar` sobre o mesmo cache: **2.861 linhas, exit 0,
   72,8 s** (não tenho a versão anterior do arquivo para provar o conteúdo exato; o comentário do construtor e o
   comportamento são a evidência).
2. **ERRO no verificador.** Colisão de nomes: o parâmetro `[string]$Ids` e a variável interna
   `$ids = $idsLista.ToArray()` são a mesma variável no PowerShell (não distingue maiúsculas); o array de 4 ids
   virava o texto `"2477017979 2909025223 2916040185 9999999999"` (a chave no CSV antigo mostra isso), o lote
   pedia 1 "id" e o resumo dizia "1 ids | ERRO 1". Renomeada para `$listaIds`. Reteste: 3 ATIVO + 1
   NAO_ENCONTRADO, exit 0.
3. **Cobertura truncada em silêncio (coletor).** Página vazia antes do totalCount só gerava uma linha de log.
   Agora cada faixa precisa alcançar **97 % do totalCount**, senão entra na lista de falhas e o script termina
   com `exit 2` (folga de 3 % para o totalCount oscilar durante a coleta).
4. **Base do IPTU (coletor).** O construtor tratava `iptuPeriod` como verdade (MONTHLY = mensal; YEARLY e sem
   período = anual ÷ 12). Medindo nos 2.901 anúncios do cache: `yearlyIptu` e `iptu` são sempre o mesmo valor cru;
   **394 de 1.189 "YEARLY" tinham valor ≤ 300** (cota mensal típica de 35–70 m² na Zona Sul; anual ≤ 300 é
   implausível) e **33 de 1.558 "MONTHLY" tinham valor > 700** (típico de anual); os 154 sem período tinham
   mediana 220. A página HTML (que mostraria a base) é 403 do Cloudflare. Adotei a **regra pelo valor**, a mesma
   do Chaves na Mão: ≤ `iptu_limite_mensal` (700, novo campo no bloco VIVAREAL do `criterios.json`) = cota mensal;
   acima = anual ÷ 12. O rótulo do site fica em `iptu_informado` (ex.: `1140/ano`, `81/ano no site; lido como
   mensal pelo valor`, `220 (sem período no site; lido como mensal pelo valor)`). Com `iptu_limite_mensal = 0`
   volta a valer só o rótulo (regra do construtor).
5. Revisão geral (tarefa F): nenhum `Invoke-WebRequest`/`.NET` (só curl.exe); decimais sempre com ponto
   (cultura invariante); `exit 2` só com falha real; cache do `-Reprocessar` usa exatamente os nomes gravados ao
   vivo (`<Bairro>_<pmin>-<pmax>_pNN.json`, `_zap.json`, `total_*.json`, `detalhe_NNN.json` — mesmo código nos
   dois modos); nenhuma outra colisão parâmetro/variável (varredura dos 9 parâmetros dos dois scripts); BOM UTF-8
   nos quatro `.ps1`.

### `coletar-vivareal.ps1 -Saida <pasta> [-Criterios <json>] [-LimiteFatia 900] [-SemFotos] [-Reprocessar] [-DedupApi]`
1. Lê `criterios.json` (preço, área, bairros, api, x_domain, page_size 30, offset_max 1000, faixas de preço,
   `iptu_limite_mensal`, user-agent).
2. Para cada bairro (Ipanema, Leblon, Copacabana): pega o `totalCount` (size=1); acima de `LimiteFatia` fatia
   pelas 4 faixas do `criterios.json` e, se ainda passar, divide ao meio (recursivo); pagina de 30 em 30 com
   `sort=createdAt ASC`. Query: `addressType=neighborhood&business=SALE&listingType=USED&
   usableAreasMin/Max&unitTypes=APARTMENT,KITNET&unitTypesV3=APARTMENT,KITNET&unitSubTypes=UnitSubType_NONE,
   DUPLEX,LOFT,STUDIO,TRIPLEX&usageTypes=RESIDENTIAL` — **sem `categoryPage=RESULT` (padrão)**: todos os
   anúncios, ids estáveis. Com `-DedupApi` a query leva `categoryPage=RESULT` (a API deduplica os irmãos) e
   cada página é pedida duas vezes (x-domain VivaReal com `link`; x-domain Zap só `id` + `link`).
   Dedup por id. Pausa 0,4 s; 3 tentativas; timeout 40 s.
3. Detalhe em lotes de 30 ids (`listings?id=a,b,c&size=30`, sem categoryPage): `title`, `description`,
   `updatedAt`, `iptuPeriod`, `unitSubTypes`, `acceptExchange`, `contractType`, `medias` (fotos).
3b. (padrão) Links em lotes de 30 ids com `categoryPage=RESULT` + `page` no includeFields — a única forma de
   obter `link` para todos os ids (sem `categoryPage`, `page` dá HTTP 500 e sem `page` o `link` não vem):
   uma chamada com x-domain VivaReal (`link`) e outra com x-domain Zap (`link_alt`), com `includeFields`
   diferentes porque a API guarda o `page` em cache pela URL ignorando o x-domain; o log avisa se algum slug
   sair no formato do outro portal. Arquivos `link_NNN.json` / `link_NNN_zap.json`.
4. Reconfere preço/área localmente (a API deixa passar área fora: 40 descartados, listados no log) e
   normaliza conforme `CONTRATO-DADOS.md`.
5. Grava `bruto-vivareal.csv` (34 colunas do contrato + `bruto_json` com o nome do JSON de origem; UTF-8 com
   BOM; `;`; ponto decimal; datas ISO), `json\vivareal\*.json` (uma resposta por página/lote) e
   `coletar-vivareal.log` (tabela consulta × totalCount × obtidos, distribuições, descartes, falhas).
   `exit 0` se completou; `exit 2` se alguma página/lote falhou nas 3 tentativas ou uma faixa ficou abaixo
   de 97 %.
`-Reprocessar`: não vai à internet; relê os JSONs já gravados (mesmos nomes) e refaz só a normalização
(baixa apenas o que faltar ou estiver inválido). Serve para ajustar regras sem nova coleta.

Normalização: `chave = VIVAREAL_<id>`; `tipo` por `unitTypes` (APARTMENT/KITNET/PENTHOUSE/FLAT) refinado por
`unitSubTypes` STUDIO/KITNET e por "kitnet/conjugado/studio/cobertura" no título; `precisao_coord = exata`
quando `address.point.lat/lon` existe, `aproximada` quando só `approximateLat/Lon`; `preco` =
`pricingInfos[SALE].price`; `condominio_mes` = `monthlyCondoFee` (0 → vazio); IPTU como acima; `andar` =
`unitFloor` quando > 0; `anunciante` = `account.name`; `tipo_anunciante` por `contractType` OWNER → Particular,
CRECI/REAL_ESTATE/nome → Imobiliária; `publicado_em` = `createdAt`, `atualizado_em` = `updatedAt` (data local);
`fotos` = `medias` do tipo IMAGE; `destaques` = amenities mapeadas + `acceptExchange` + regex no título e
descrição (só os termos do contrato); `descricao_resumo` = 300 caracteres sem HTML/quebras; `link` =
`https://www.vivareal.com.br` + `link.href`; `link_alt` = `https://www.zapimoveis.com.br` + href da página Zap.

### `verificar-vivareal.ps1 (-Chaves <csv> | -Ids a,b,c) -Saida <pasta>`
Lotes de até 30 ids (`listings?id=...&size=N`); quem não vier no lote é confirmado um a um. `status ACTIVE` →
**ATIVO**; outro status → **INATIVO**; `totalCount 0` na consulta individual → **NAO_ENCONTRADO**; falha de
rede/API nas 3 tentativas → **ERRO** (exit 2). Gera `verificacao-vivareal.csv`
(`chave;status_site;preco_atual;verificado_em;evidencia`), `json\vivareal-verificacao\*.json` e
`verificar-vivareal.log`. Com `-Chaves`, lê a coluna `chave` e ignora outras fontes.

## 2. Como testar
```powershell
# coleta completa ao vivo, modo padrão sem categoryPage (≈ 13 min; 711 chamadas; 45 MB; 5.177 linhas)
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\Skills\scripts\coletar-vivareal.ps1" -Saida "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_trabalho\testes-vivareal-r3"
# modo antigo, com a dedup da API (≈ 4,6 min; 306 chamadas; 23 MB; 2.865 linhas; ids trocam entre rodadas)
powershell -NoProfile -ExecutionPolicy Bypass -File "...\coletar-vivareal.ps1" -Saida "...\_trabalho\testes-vivareal-r2" -DedupApi
# só renormalizar a partir dos JSONs já baixados (≈ 73 s, sem internet)
powershell -NoProfile -ExecutionPolicy Bypass -File "...\coletar-vivareal.ps1" -Saida "...\_trabalho\testes-vivareal-r2" -Reprocessar
# verificador
powershell -NoProfile -ExecutionPolicy Bypass -File "...\verificar-vivareal.ps1" -Ids "2649867490,2477017979,2430869022,2" -Saida "...\_trabalho\testes-vivareal-r2\verificar"
powershell -NoProfile -ExecutionPolicy Bypass -File "...\verificar-vivareal.ps1" -Chaves "...\bruto-vivareal.csv" -Saida "...\_dados\2026-10-11"
# conferência do CSV contra o contrato e comparação de 6 linhas com a API ao vivo (scripts de teste)
powershell -NoProfile -ExecutionPolicy Bypass -File "...\_trabalho\conferir-bruto-vivareal.ps1" -Csv "...\_trabalho\testes-vivareal-r2\bruto-vivareal.csv"
powershell -NoProfile -ExecutionPolicy Bypass -File "...\_trabalho\comparar-6-linhas-vivareal.ps1" -Csv "...\_trabalho\testes-vivareal-r2\bruto-vivareal.csv"
```
Conferir: exit code 0, log com "Cobertura completa. exit 0", 35 colunas no CSV, BOM `EF BB BF`,
`conferencia-bruto.txt` com "RESULTADO: CONFORME o contrato".

## 3. Contagens e tempos obtidos (teste real)

### Cobertura por consulta (coleta r2, modo com dedup da API = hoje `-DedupApi`, 18h37–18h42)
| Consulta | totalCount | obtidos | novos | páginas |
|---|---:|---:|---:|---:|
| Ipanema, R$ 500.000–1.100.000 | 203 | 203 | 203 | 7 |
| Leblon, R$ 500.000–1.100.000 | 93 | 93 | 93 | 4 |
| Copacabana, inteiro (2.507 > 900 → fatiado) | 2.507 | — | — | — |
| Copacabana, R$ 500.000–650.000 | 719 | 719 | 719 | 24 |
| Copacabana, R$ 650.001–800.000 (961 > 900 → dividido ao meio) | 961 | — | — | — |
| Copacabana, R$ 650.001–725.000 | 441 | 441 | 441 | 15 |
| Copacabana, R$ 725.001–800.000 | 547 | 547 | 547 | 19 |
| Copacabana, R$ 800.001–950.000 | 619 | 619 | 619 | 21 |
| Copacabana, R$ 950.001–1.100.000 | 283 | 283 | 283 | 10 |
| **Total** | | **2.905 únicos** | | 100 páginas × 2 domínios |

Cobertura 100 % em todas as faixas (≥ 97 % exigido). **totalCount refeito por mim com curl.exe** (18h21, fora do
script): Ipanema **203**, Leblon **93**, Copacabana **2.507** — iguais aos do coletor (o cache do meio-dia tinha
202/90/2.506). A soma das fatias de Copacabana (2.610) passa do totalCount do bairro (2.507) porque a dedup da API
é diferente em faixas largas; o dedup por id deixou 2.609 únicos em Copacabana. Bordas de preço inclusivas
(`priceMin=priceMax=650000` → 158; `650001` → 0): as faixas não se sobrepõem.

### Resultado
| Medida (modo com dedup da API) | cache meio-dia (`-Reprocessar`) | 1ª coleta ao vivo (18h30) | coleta r2 (18h37) |
|---|---:|---:|---:|
| ids únicos | 2.901 | 2.905 | 2.905 |
| descartados na reconferência (área 29–34 ou 80 m²) | 40 | 40 | 40 |
| linhas em `bruto-vivareal.csv` | 2.861 | 2.865 | **2.865** |
| chamadas HTTP / baixado | 0 (304 do disco) | 306 / 23,0 MB | 306 / 23,0 MB |
| tempo (busca + detalhe + normalização) | 72,8 s | 354,3 s | **277,8 s** (142,8 + 66,8 + 68,2) |
| exit | 0 | 0 | 0 |

Distribuição da coleta definitiva (de `conferencia-bruto.txt`): `bairro_site` Copacabana 2.571, Ipanema 201,
Leblon 93; `tipo` Apartamento 2.593, Kitnet/Studio 265, Cobertura 7 (Flat 0, Outro 0); `precisao_coord` exata
1.873, aproximada 992, nenhuma 0; com número 1.866 / sem 999; sem rua 19; CEP 2.865; `publicado_em` 2.865
(2013-08-29 a 2026-10-11); `atualizado_em` 2.865 (2026-04-17 a 2026-10-11); `link_alt` (Zap) 2.621 / sem 244;
IPTU: mensal pelo rótulo 1.464, anual pelo rótulo 549 (÷12), rótulo anual lido como mensal pelo valor 440,
rótulo mensal lido como anual pelo valor 32, sem período → mensal 103, sem período → anual 42, vazio 235
(`iptu_mes` preenchido em 2.630); condomínio 2.800 / vazio 65; `tipo_anunciante` Imobiliária 2.851,
Particular 14; título 2.865; descrição 2.864; fotos > 0 em 2.864; andar informado 476; quartos 1 = 1.925,
2 = 892, 3 = 32, 0 = 14, 4 = 1, **14 = 1** (erro do anunciante); vagas vazio 1.339, 0 = 1.081, 1 = 436, 2 = 7,
5 = 1, **40 = 1** (idem). Preço 500.000–1.100.000; área 35–70. Destaques mais frequentes: elevador 2.303,
portaria 24h 2.204, pet 1.721, mobiliado 1.092, reformado 819, dependência 532, sol da manhã 502.
Regras do contrato: BOM ok; 34 colunas na ordem exata (+ `bruto_json`); chave `VIVAREAL_<id>` única e igual a
`VIVAREAL_`+`codigo`; 0 fora de preço/área; 0 vírgulas decimais; 0 datas fora do ISO; `status_site` = ATIVO
em todas; `link` sempre `https://www.vivareal.com.br/imovel/...-id-<codigo>/`.

### Fatia de Copacabana que interessa (ruas do Arpoador) — anúncios no CSV
Francisco Otaviano 3 (Copacabana), Bulhões de Carvalho 31, Rainha Elizabeth 8 (6 Copacabana + 2 Ipanema),
Raul Pompéia 47, **Francisco Bhering 0** (a API devolve 0 para essa rua mesmo sem filtro de preço/área; Francisco
Otaviano sem filtro dá 320 e Joaquim Nabuco 130), Joaquim Nabuco 7, Gomes Carneiro 20 (Ipanema) — **116** no total.

### Comparação de 6 linhas sorteadas com a API ao vivo (`comparacao\comparacao-6-linhas.txt`, seed 20261011)
`listings?id=<id>&includeFields=search(result(listings(listing(id,status,pricingInfos,usableAreas,address,
updatedAt,bedrooms,parkingSpaces),link)),totalCount)` — **74/74 campos iguais** (status, preço, área, rua,
número, bairro, condomínio, IPTU normalizado, quartos, vagas, data de atualização, link, e link_alt em 2):
- 2913764338 — Rua Alberto de Campos, s/nº (Ipanema): R$ 880.000, 36 m², cond. 750, IPTU 1140/ano → 95/mês,
  1 quarto, vagas vazio, atu 2026-10-11; link_alt Zap conferido (13/13).
- 2771988613 — Rua Alberto de Campos (Ipanema): R$ 890.000, 50 m², cond. 962, IPTU 0 → vazio, 1 quarto, atu
  2026-09-03 (12/12).
- 2806438826 — Rua Mário Ribeiro, 91 (Leblon): R$ 860.000, 63 m², cond. 1.230, IPTU 267/mês, 2 quartos, 0 vagas,
  atu 2026-08-14; link_alt Zap conferido (13/13).
- 2796534131 — Av. Bartolomeu Mitre (Leblon): R$ 1.080.000, 59 m², cond. 1.100, IPTU 2960/ano → 247/mês,
  1 quarto, 1 vaga, atu 2026-10-06 (12/12).
- 2688694636 — Av. N. S. de Copacabana: R$ 800.000, 50 m², cond. 500, IPTU 1699/ano → 142/mês, 2 quartos (12/12).
- 2906115154 — Rua Bulhões de Carvalho, 560: R$ 850.000, 49 m², cond. 1.400, IPTU 180/mês, 2 quartos (12/12).
Links HTML: **403** em todos (VivaReal e Zap; Cloudflare barra robô — aceitável, o link serve para o Guilherme).
Na consulta por id a API **não devolve `link`** (e `page` no includeFields dá HTTP 500), então o link foi
conferido pelo padrão `/imovel/...-id-<id>/`.

**Por que 244 linhas (8,5 %) ficam sem `link_alt`:** todos os 244 estão no Zap (`portals = OLX,VIVAREAL,ZAP`,
conferido id a id), mas as páginas pedidas com `x-domain www.zapimoveis.com.br` trazem **249 ids que não
aparecem nas páginas VivaReal** (e vice-versa): a dedup do `categoryPage=RESULT` escolhe um representante
diferente por portal entre os anúncios "irmãos" (mesmo imóvel, filiais da mesma rede). Ex.: 2916040565 (Nova
Inova Filial, Praça Vereador Rocha Leão 130) não está na página Zap; lá aparece 2916044045 (Nova Inova Matriz),
o mesmo imóvel. Não dá para testar se o Zap resolve um link montado só com o id (403 em qualquer variante).

### Verificador
- `-Ids 2649867490,2477017979,2430869022,2`: ATIVO, ATIVO, ATIVO, NAO_ENCONTRADO (`totalCount=0`); 2 chamadas;
  1,9 s; exit 0; CSV com BOM e as 5 colunas.
- `-Chaves` com CSV misto (2 VIVAREAL + QUINTOANDAR + CHAVESNAMAO): 2 ignoradas, 1 ATIVO, 1 NAO_ENCONTRADO; exit 0.
- **254 ids** que estavam no CSV do meio-dia e não no das 18h30 (`ids-que-sairam-desde-meio-dia.txt`):
  251 ATIVO (mesmo preço/área), 3 NAO_ENCONTRADO, 0 ERRO; 12 chamadas; 11,6 s; exit 0. Ou seja, 8,9 % dos ids
  **rotacionam** entre rodadas sem sair do ar (ver pendência 1).
- INATIVO não exercitado: não achei anúncio com `status` ≠ ACTIVE (anúncio retirado some da consulta por id →
  NAO_ENCONTRADO). A lógica é direta (`status` ≠ `ACTIVE`).

## 3b. Decisão: sem categoryPage (padrão desde 11/10/2026 — coleta r3, 18h58–19h11)
Decisão do Guilherme, transmitida pelo orquestrador: "uma linha por anúncio, com marcação de possível
duplicata". A busca passou a rodar **sem `categoryPage=RESULT`** (ids estáveis; a rotação de 8,9 % dos ids em
6 h no modo com dedup geraria falsos NOVO/removido a cada rodada); `-DedupApi` restaura o modo antigo. O
consolidador agrupa os irmãos por rua+nº (ou CEP) + área ±2 m² + preço ±2 %.

Conferências antes de mudar o padrão: sem `categoryPage` o filtro de tipo/uso continua valendo (Leblon: 182
ids, todos APARTMENT/RESIDENTIAL/ACTIVE, nenhum fora de preço/área); `title`/`description`/`updatedAt`
continuam vindo (o lote de detalhe já cobria; a busca sem categoryPage até devolve `title`/`updatedAt`
direto); `link` **não** vem sem `categoryPage` (e `page` dá HTTP 500) → passo 3b de links por lote de ids
(testado com 30 ids por lote nos dois domínios: 30/30 hrefs, slugs no formato certo).

| Consulta (r3) | totalCount | obtidos | páginas |
|---|---:|---:|---:|
| Ipanema | 475 | 476 (475 únicos) | 16 |
| Leblon | 182 | 182 | 7 |
| Copacabana inteiro → fatiado pelas 4 faixas; 3 delas divididas ao meio (uma, duas vezes) | 4.520 | — | — |
| Copacabana 500.000–575.000 | 305 | 305 | 11 |
| Copacabana 575.001–650.000 | 761 | 761 | 26 |
| Copacabana 650.001–725.000 | 768 | 768 | 26 |
| Copacabana 725.001–762.500 | 458 | 458 | 16 |
| Copacabana 762.501–800.000 | 535 | 535 | 18 |
| Copacabana 800.001–875.000 | 565 | 565 | 19 |
| Copacabana 875.001–950.000 | 623 | 623 | 21 |
| Copacabana 950.001–1.100.000 | 505 | 505 | 17 |

Cobertura 100 % em todas as faixas; nenhuma fatia chegou perto do limite de 1.000 (maior: 768) — o
fatiamento recursivo deu conta sozinho. **5.177 ids únicos, 0 descartados** na reconferência (sem a dedup a
API respeita a área à risca; os 40 descartes do modo com dedup eram representantes com área diferente do
irmão que casava com o filtro), **5.177 linhas** no CSV, conforme o contrato (`conferencia-bruto.txt`).
Tempo **781,5 s** (busca 183,6 + detalhe 160,4 + links 316,9 + normalização 121); **711 chamadas**
(15 totais + 154 páginas Copacabana + 16 Ipanema + 7 Leblon + 173 detalhe + 346 links); 44,6 MB; exit 0.
`link` e `link_alt` preenchidos em **5.177/5.177** (no modo com dedup faltavam 244 `link_alt`).

Volume por bairro/tipo: `bairro_site` Copacabana 4.520, Ipanema 475, Leblon 182; `tipo` Apartamento 5.011,
Kitnet/Studio 157, Cobertura 9; coordenada exata 3.582 / aproximada 1.595; com número 3.572 / sem 1.605;
IPTU mensal pelo rótulo 2.713, anual pelo rótulo 894, rótulo anual lido como mensal pelo valor 912, rótulo
mensal lido como anual 65, sem período → mensal 130 / anual 63, vazio 400. Ruas do Arpoador: Francisco
Otaviano 3, Bulhões de Carvalho 46, Rainha Elizabeth 18, Raul Pompéia 83, Francisco Bhering 0, Joaquim Nabuco
14, Gomes Carneiro 156 (lançamento no nº 130 vendido por dezenas de imobiliárias) — 320. Comparação de 6
linhas sorteadas com a API ao vivo repetida sobre o r3: ver `testes-vivareal-r3\comparacao\`.

**Tamanho do efeito na planilha — grupos de "irmãos"** (`contar-irmaos-vivareal.ps1` → `irmaos.txt`):

| Bairro | anúncios (r3, sem dedup) | regra do consolidador: grupos com 2+ | anúncios nesses grupos | maior grupo | imóveis distintos | (r2, com dedup: anúncios → distintos) |
|---|---:|---:|---:|---:|---:|---:|
| Ipanema | 475 | 69 | 317 | 43 | **227** | 201 → 157 |
| Leblon | 182 | 27 | 88 | 6 | **121** | 93 → 83 |
| Copacabana | 4.520 | 831 | 2.784 | 37 | 2.567 | 2.571 → 2.226 |

Com a chave exata (rua+nº+área+preço iguais): Ipanema 72 grupos / 294 anúncios / 253 distintos; Leblon 23 /
78 / 127. Leitura: em Ipanema e Leblon, **2 de cada 3 anúncios têm pelo menos um irmão**; os grupos maiores
são (a) a mesma unidade na carteira de 5–6 filiais da mesma rede (Invicta Arpoador/Leme/Flamengo/Ipanema/
Botafogo/Copacabana; Nova Inova Matriz/Filial; Kiffer 1/2/3; Styllus Alfa/Beta/Delta) e (b) lançamentos sem
número, agrupados só por rua+CEP (Gomes Carneiro, CEP 22071-110, 50 m², R$ 949.000: 43 anúncios de 40
imobiliárias — podem ser unidades diferentes do mesmo prédio; a marcação é "possível duplicata", não
certeza). Mesmo o modo com dedup já tinha irmãos entre imobiliárias diferentes (Ipanema 27 grupos / 71
anúncios), porque a API só deduplica dentro da mesma rede.

## 4. Premissas adotadas (sem confirmação do Guilherme)
Do construtor anterior (cabeçalho `.NOTAS TÉCNICAS` do script e código):
1. HTTP só por `curl.exe`; `x-domain: www.vivareal.com.br`; UA de Chrome; 0,4 s entre páginas; 3 tentativas; 40 s.
2. Filtro de tipo = `unitTypes` + `unitTypesV3` + `unitSubTypes` juntos; `KITNET` devolve 0, então kitnets/studios
   vêm como APARTMENT e são classificados por `unitSubTypes` (STUDIO/KITNET) ou pelo título.
3. `categoryPage=RESULT` (o que o site usa: filtra e deduplica) nas páginas; título/descrição/updatedAt/iptuPeriod
   pelo lote de ids sem categoryPage.
4. `link` pedido com `page` no includeFields; href do Zap por chamada separada com `x-domain` do Zap.
5. `sort=createdAt ASC`; `LimiteFatia` 900 (faixas do `criterios.json`, depois divisão ao meio); `offset_max` 1000.
6. `medias` pedido por padrão para contar fotos (`-SemFotos` para resposta 5× menor).
7. `precisao_coord = exata` sempre que há `point.lat/lon` (inclusive `precision: RANGE_INTERPOLATED`);
   `aproximada` quando só `approximateLat/Lon`.
8. `andar` só quando `unitFloor > 0`; condomínio 0 → vazio; `tipo_anunciante` por `contractType`, CRECI e nome.
9. Datas convertidas de UTC para data local; `bruto_json` = nome do JSON de página de origem.
Minhas:
10. **IPTU pela regra do valor** (≤ 700 mensal, > 700 anual ÷ 12), configurável em
    `criterios.json → sites.VIVAREAL.iptu_limite_mensal` (0 = só o rótulo). Rótulo preservado em `iptu_informado`.
11. Faixa abaixo de 97 % do totalCount = falha (`exit 2`).
12. Padrão **sem `categoryPage=RESULT`** (decisão do Guilherme via orquestrador, 11/10) — ver seção 3b; o modo
    antigo fica em `-DedupApi`. Links por lote de ids com `categoryPage=RESULT` + `page`; sem href (lote falhou),
    o link é montado no padrão do site (`.../imovel/apartamento-<q>-quartos-<bairro>-...-venda-RS<preco>-id-<id>/`)
    e contado como "sem link" no log (0 casos no r3).
13. Acrescentei `iptu_limite_mensal` e `_iptu_nota` ao bloco VIVAREAL do `criterios.json`; DESCOBERTAS-TECNICAS.md
    ganhou a subseção 1.1 e as linhas do VivaReal na tabela da seção 5. Não fiz commit no git (fechamento da etapa
    pelo orquestrador).
14. Scripts de teste (`_trabalho\conferir-bruto-vivareal.ps1`, `_trabalho\comparar-6-linhas-vivareal.ps1`) ficam
    no workspace para repetir a conferência em rodadas futuras.

## 5. Pendências
1. ~~Decisão: dedup da API ou não~~ — **decidida** (sem `categoryPage`, seção 3b). Fica para o consolidador/
   planilha: a marcação "possível duplicata" junta também unidades diferentes de um lançamento sem número
   (grupos por rua+CEP); e a coleta leva 13 min e 45 MB por rodada (era 4,6 min / 23 MB).
2. ~~`link_alt` vazio em 244 linhas~~ — resolvido pelo passo 3b (5.177/5.177 no r3). Resta a dúvida teórica de o
   site aceitar um link montado só com o id (só acontece se um lote de links falhar; 0 casos).
3. Regra do IPTU a validar pelo Guilherme abrindo 2–3 anúncios: ex. 2913764338 (site diz 1140/ano → 95/mês) e
   2806438826 (267/mês). Se preferir o rótulo do site, `iptu_limite_mensal: 0`.
4. INATIVO não exercitado ao vivo (ver verificador).
5. Erros de digitação do site passam como estão (quartos 14, vagas 40 e 5) — o consolidador/planilha pode
   sinalizar valores absurdos.
6. Rua Francisco Bhering: 0 na API mesmo sem critérios; conferir se o site a cadastra com outro nome.
7. Os contadores de IPTU do log cobrem os 2.905 únicos (antes dos 40 descartes); os do CSV estão em
   `conferencia-bruto.txt` (cosmético).
8. Copacabana entra inteira (2.571 linhas); o recorte pelo polígono é do consolidador — a maior parte vai cair.
9. `_trabalho\testes-vivareal\` (cache do meio-dia, 24 MB) foi apagada a pedido do orquestrador; o CSV e o log
   reprocessados do meio-dia e as probes do construtor foram guardados em `testes-vivareal-r2\`
   (`bruto-vivareal-meio-dia-reprocessado.csv`, `probes-construtor-meio-dia\`). `testes-vivareal-r2\` = evidência
   do modo com dedup (CSV, 306 JSONs, logs das duas rodadas, `verificar*\`, `comparacao\`, `probe-sem-dedup\`,
   `probe-sem-zap\`); `testes-vivareal-r3\` = evidência do modo padrão (CSV de 5.177 linhas, 711 JSONs, log,
   `conferencia-bruto.txt`, `irmaos.txt`, `comparacao\`).
