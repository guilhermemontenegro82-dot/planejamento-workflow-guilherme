# Relatório — coletor e verificador do QuintoAndar (11/10/2026)

Componente: `Skills\scripts\coletar-quintoandar.ps1` e `Skills\scripts\verificar-quintoandar.ps1`.
Pasta de testes: `_trabalho\testes-quintoandar\`. Tudo abaixo foi executado de verdade nesta máquina
(Windows 10, PowerShell 5.1, curl.exe do Windows, sem Python/Node/navegador).

## 1. O que foi feito

### Passo 0 — validar a API (decisivo)
- `POST https://www.quintoandar.com.br/api/yellow-pages/v2/search/list` (o endereço de DESCOBERTAS e do
  `criterios.json`) → **HTTP 404** "Nothing matches the given URI". `/v3/search/list` idem.
  `/v2/search/count` nesse host aceita o corpo (reclamou só de `availability: "ANY"` → `any`), mas devolve
  `count: 73079` (Brasil inteiro), ou seja, **ignora os filtros**. Não serve.
- No código do site (`_trabalho/testes-sites/qa-chunks/c63.js`, módulo 56296) o host base da busca é
  `https://apigw.prod.quintoandar.com.br/house-listing-search`. Testado:
  **`POST https://apigw.prod.quintoandar.com.br/house-listing-search/v2/search/list` → HTTP 200**, filtros
  respeitados: `hits.total.value = 101` no viewport de `criterios.json`; todos os hits com `salePrice` entre
  510.000 e 1.100.000 e `area` entre 35 e 68 (29 `Apartamento` + 1 `StudioOuKitchenette` na 1ª página).
  Também existe `/v2/search/count` no mesmo host (devolve o mesmo total 101).
- `pageSize`: aceito 30, 50, 100, 200, 300 e **500** (todos 200). `offset` funciona, mas a ordenação
  `RELEVANCE` é instável entre páginas: offset 0/30/60/90 com pageSize 30 devolveu 100 ids distintos de 101.
  Solução adotada: página grande (padrão 200) + dedup por id + segunda passada ordenada por `TOTAL_COST`
  se ainda faltar id.
- `fields`: pedindo uma lista ampla, a API devolve no `_source`: `id, type, area, bathrooms, bedrooms,
  suites, parkingSpaces, salePrice, iptu (mensal), totalCost, address (só a rua), city, neighbourhood,
  regionName, location{lat,lon}, coverImage, imageList[], amenities[], installations[], forSale, forRent,
  isPrimaryMarket, isFurnished, visitStatus`; `listingTags` vem fora do `_source`, em `hits[].fields`.
  Não há datas nem número/CEP na busca — vêm da página do anúncio. A coordenada `location` da busca é
  **idêntica** à da página (coordenada exata do imóvel).

**Corpo que funcionou** (gravado também em `<Saida>\corpo-busca-quintoandar.json` a cada coleta):
```json
{"context":{"listShowing":true,"mapShowing":true,"numPhotos":12,"isSSR":false},
 "filters":{"businessContext":"SALE","enableFlexibleSearch":false,
   "location":{"coordinate":{"lat":-22.982,"lng":-43.208},
               "viewport":{"east":-43.178,"north":-22.968,"south":-22.996,"west":-43.238},
               "neighborhoods":[],"countryCode":"BR"},
   "priceRange":[{"costType":"SALE_PRICE","range":{"min":500000,"max":1100000}}],
   "availability":"ANY","occupancy":"ANY","partnerIds":[],"specialConditions":[],"excludedSpecialConditions":[],
   "blocklist":[],"selectedHouses":[],"categories":[],
   "houseSpecs":{"area":{"range":{"min":35,"max":70}},"houseTypes":["Apartamento","StudioOuKitchenette"],
                 "amenities":[],"installations":[],"bathrooms":{"range":{}},"bedrooms":{"range":{}},
                 "parkingSpace":{"range":{}},"suites":{"range":{}}},
   "origin":"HYBRID"},
 "sorting":{"criteria":"RELEVANCE","order":"DESC"},
 "pagination":{"pageSize":200,"offset":0},
 "fields":["id","area","salePrice","iptu","totalCost","address","city","regionName","neighbourhood","type",
           "bedrooms","bathrooms","suites","parkingSpaces","isPrimaryMarket","isFurnished","location",
           "coverImage","imageList","amenities","installations","forSale","forRent","visitStatus","listingTags"],
 "slug":"ipanema-rio-de-janeiro-rj-brasil"}
```
Headers: `Accept: application/json`, `Content-Type: application/json`, `Origin: https://www.quintoandar.com.br`
(Referer opcional), User-Agent de Chrome. Evidências em `_trabalho\testes-quintoandar\passo0\`.

### Página do anúncio (`https://www.quintoandar.com.br/imovel/<id>/comprar`)
- Responde 301 para a URL com slug (`/imovel/<id>/comprar/apartamento-1-quarto-ipanema-rio-de-janeiro`);
  `curl -L` segue e `%{url_effective}` vira o `link` do CSV.
- `__NEXT_DATA__` → `props.pageProps.initialState.house.houseInfo`: `address{street, neighborhood, zipCode,
  lat, lng}`, **número em `condominium.number`** (não em `address`), `salePrice`, `area`, `condoPrice`,
  `iptu` (mensal; `iptuType`), `rangeFloor{min,max}` (o site só informa a faixa de andares; `floor` não vem),
  `constructionYear` (raro), `remarks` (descrição, com entidades HTML como `&#13;`), `photos[]`,
  `listings[]` com `businessContext` SALE/RENT, `status` (`publicado`/`suspenso`/`despublicado`),
  `statusReason`, `firstPublicationDate`, `lastPublicationDate`; `lastPublishedDate`;
  `condominium.region.center` (centroide do bairro). Flags: `amenities`, `comfortCommodities`,
  `practicalityCommodities`, `installations` (listas de `{key,text,value:"SIM"/"NAO"}`),
  `condominium.features.installations/doorman`, `isNewOrRenovated`, `acceptsPets`, `hasFurniture`,
  `isNearSubway`, `APARTAMENTO_COBERTURA`.
- **Id inexistente**: HTTP 200, sem redirect, `houseInfo.id` vazio e HTML "Esse imóvel está indisponível :(".
- **Armadilha descoberta no teste real**: esse mesmo template "indisponível" aparece **de forma intermitente
  para anúncios no ar** (1ª coleta: 3 de 101 páginas vieram vazias e minutos depois estavam completas; no
  teste do verificador um id que tinha vindo completo veio vazio). Os dois scripts repetem a leitura até 3
  vezes (pausa de 2 s) quando o houseInfo vem vazio. Na 2ª coleta, 4 páginas precisaram da 2ª rodada e
  nenhuma ficou sem dados.

### `coletar-quintoandar.ps1 -Saida <pasta> [-Criterios <json>] [-PageSize 200] [-LimitePaginas N] [-SemPaginas]`
1. Lê `criterios.json` (preço, área, tipos, viewport, user-agent).
2. Busca na API com viewport único, pagina por offset até `hits.total.value`, dedup por id, segunda passada
   `TOTAL_COST` se faltar id. Pausa 0,4 s entre páginas; 3 tentativas; timeout 40 s.
3. Reconfere localmente preço/área/tipo (exclui e loga o que estiver fora).
4. Abre cada página de anúncio (`curl -L`), salva o `__NEXT_DATA__` bruto em `<Saida>\json\quintoandar\<id>.json`,
   extrai os campos; pausa 0,5 s; até 3 rodadas de leitura se vier "indisponível". Se a página falhar, a linha
   fica com os campos da busca e o log registra.
5. Grava `<Saida>\bruto-quintoandar.csv` (35 colunas, ordem exata do contrato; UTF-8 com BOM; `;`; ponto
   decimal; datas ISO), `<Saida>\coletar-quintoandar.log` e `<Saida>\corpo-busca-quintoandar.json`.
   `exit 0` se completou; `exit 2` se alguma chamada falhou nas 3 tentativas ou a busca não cobriu o total.

Normalização: `chave = QUINTOANDAR_<id>`, `fonte = QUINTOANDAR`, `tipo` por `houseTypes` (`Apartamento`,
`StudioOuKitchenette` → `Kitnet/Studio`; `APARTAMENTO_COBERTURA = SIM` → `Cobertura`), `titulo` = `<title>`
da página sem o sufixo " - QuintoAndar", `precisao_coord` = `exata` quando a coordenada não coincide (±2 m)
com o centroide do bairro/cidade/viewport, `iptu_mes` já mensal, `andar` = faixa `min-max` do `rangeFloor`,
`anunciante = QuintoAndar`, `tipo_anunciante = Plataforma`, `publicado_em`/`atualizado_em` =
`listings[SALE].firstPublicationDate/lastPublicationDate` (data local), `fotos = photos.Count`, `destaques`
pelas flags da página/busca + regex na descrição (só os termos do contrato), `descricao_resumo` = 300 chars
da `remarks` sem entidades HTML.

### `verificar-quintoandar.ps1 (-Chaves <csv> | -Ids a,b,c) -Saida <pasta>`
Abre `/imovel/<id>/comprar` e classifica: **ATIVO** (`listings[SALE].status = publicado` e `forSale`),
**INATIVO** (houseInfo presente mas venda `suspenso`/`despublicado`/outro ou `forSale = false`),
**NAO_ENCONTRADO** (404, redirecionamento para a busca, ou houseInfo vazio em 3 leituras),
**ERRO** (curl falhou nas 3 tentativas, 5xx, sem `__NEXT_DATA__`, JSON ilegível). Gera
`verificacao-quintoandar.csv` (`chave;status_site;preco_atual;verificado_em;evidencia`) e
`verificar-quintoandar.log`. `exit 2` se houver ERRO. Com `-Chaves`, lê a coluna `chave` e ignora outras fontes.

## 2. Como testar
```powershell
# coleta completa (≈ 4,5 min para 101 anúncios)
powershell -ExecutionPolicy Bypass -File "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\Skills\scripts\coletar-quintoandar.ps1" -Saida "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_trabalho\testes-quintoandar"
# teste rápido (só 3 páginas de anúncio, ≈ 11 s)
powershell -ExecutionPolicy Bypass -File "...\coletar-quintoandar.ps1" -Saida "...\_trabalho\testes-quintoandar\smoke" -LimitePaginas 3
# verificador
powershell -ExecutionPolicy Bypass -File "...\verificar-quintoandar.ps1" -Ids 894849326,895783557,894974126,123456789 -Saida "...\_trabalho\testes-quintoandar\verificar2"
powershell -ExecutionPolicy Bypass -File "...\verificar-quintoandar.ps1" -Chaves "...\bruto-quintoandar.csv" -Saida "...\_dados\2026-10-11"
```
Conferir: `exit code` 0, `coletar-quintoandar.log` com "RESULTADO: COMPLETO", 35 colunas no CSV, BOM `EF BB BF`.

## 3. Contagens e tempos obtidos (teste real)
| Medida | 1ª coleta (11:55) | 2ª coleta (12:05, com repetição de leitura) |
|---|---|---|
| `hits.total.value` da API | 101 | 101 |
| ids distintos na busca (1 chamada, pageSize 200) | 101 | 101 |
| fora dos critérios na reconferência local | 0 | 0 |
| linhas em `bruto-quintoandar.csv` | 101 | 101 |
| páginas de anúncio ok / falha / sem dados | 98 / 0 / 3 | **101 / 0 / 0** (4 ok só na 2ª rodada) |
| com número | 89 | **91** |
| com CEP | 98 | **101** |
| com coordenada exata | 100 | **101** |
| tempo total | 262,5 s | 253,8 s |
| exit | 0 | 0 |

Distribuição da 2ª coleta: `bairro_site` Copacabana 83, Leblon 7, Ipanema 4, Gávea 4, Vidigal 2, Lagoa 1
(o viewport de `criterios.json` cobre tudo isso; o recorte pelo polígono é do consolidador); `tipo`
Apartamento 90, Cobertura 6, Kitnet/Studio 5; preço 510.000–1.100.000; área 35–70; `publicado_em` de
2021-02-11 a 2026-10-10; vazios: número 10, condomínio 2, IPTU 7 (todos `0/mês` no site → tratados como não
informado, registrados em `iptu_informado`), descrição 17 (a página não traz `remarks`). `andar` sempre em
faixa (`0-3` 39, `4-7` 27, `8-11` 28, `12-15` 2, `20-23` 1, `28-31` 1, vazio 3). Destaques mais frequentes:
portaria 24h 94, pet 86, elevador 84, mobiliado 69, sol da manhã 61, vista livre 56, varanda 35.

Volume para a tabela de DESCOBERTAS: **QuintoAndar, viewport Ipanema/Leblon/Arpoador, critérios → 101**.

### Comparação de 3 linhas com as páginas ao vivo
Feita duas vezes (após cada coleta), com extração independente do `__NEXT_DATA__` ao vivo. Na 2ª, 16 campos
por linha (número, CEP, lat, lon, preço, área, condomínio, IPTU, quartos, banheiros, vagas, fotos, andar,
publicado_em, atualizado_em, link): resultado em `_trabalho\testes-quintoandar\comparacao\comparacao-3-linhas.txt`.
- 894849326 — Rua Alberto de Campos, 25 (Ipanema): nº 25, CEP 22411-030, -22.9811248/-43.2030681,
  R$ 880.000, 45 m², cond. 750, IPTU 82, 22 fotos, andar 4-7, pub 2026-06-13, atu 2026-06-16 → confere.
- 895752349 — Av. N. S. de Copacabana, 1369: nº 1369, CEP 22070-011, -22.9852199/-43.1899819, R$ 780.000,
  50 m², cond. 1478, IPTU 129, 20 fotos, andar 8-11, pub/atu 2026-09-29 → confere (na 1ª comparação a
  minha regex de conferência não achou o número; o parser achou `condominium.number = "1369"`).
- 895684014 — Rua Barata Ribeiro, 630: nº 630, CEP 22051-002, -22.97249/-43.190538, R$ 830.000, 61 m²,
  cond. 1200, IPTU 0 → vazio, 19 fotos, andar 4-7, pub/atu 2026-08-25 → confere.

### Verificador
- `-Ids 894849326,895783557,894974126,123456789`: ATIVO, ATIVO, ATIVO, NAO_ENCONTRADO ("houseInfo vazio
  em 3 leitura(s); página diz 'Esse imóvel está indisponível'"); 12,7 s; exit 0. Evidência inclui status,
  datas e `salePrice`.
- `-Chaves` com CSV misto (3 QUINTOANDAR reais + 1 VIVAREAL + 1 QUINTOANDAR inventada): a linha VIVAREAL
  foi ignorada; 2 ATIVO + 2 NAO_ENCONTRADO — uma das "NAO_ENCONTRADO" (894974126) era a instabilidade do
  site (antes da repetição de leitura ser implementada; no reteste veio ATIVO). Pasta `verificar-chaves\`.
- Não encontrei anúncio de venda com `status` ≠ `publicado` para exercitar o INATIVO ao vivo; a lógica foi
  escrita a partir do JSON real de um anúncio com listing RENT `suspenso` (`statusReason RENTED`) e
  `despublicado` (`OWNER_REQUESTED_TERMINATION`) — mesma estrutura.

## 4. Premissas adotadas (sem confirmação do Guilherme)
1. Host da API trocado para `apigw.prod.quintoandar.com.br/house-listing-search` (o do `criterios.json`
   dá 404). O script usa o host fixo e **não** altera `criterios.json`; vale atualizar o campo `api` lá.
2. `pageSize` padrão 200 (a API aceita até 500); busca por viewport único de `criterios.json`.
3. `andar` = faixa `min-max` do `rangeFloor` (o site não dá o andar exato); vazio quando `max = 0` sem `min`.
4. `iptu_mes`/`condominio_mes` = `0` no site → vazio (não informado); o `0/mês` fica em `iptu_informado`.
5. `tipo = Cobertura` quando a amenidade `APARTAMENTO_COBERTURA` é `SIM` (6 casos); `Casa`/outros → `Outro`.
6. `precisao_coord = exata` quando a coordenada da página (ou da busca) não coincide com centroide
   (tolerância 0,00002° ≈ 2 m); nunca `aproximada` (o site não informa esse conceito).
7. `destaques`: flags do site + regex na descrição; `andar alto` só por texto ou faixa começando no 10º.
8. Datas convertidas de UTC para data local.
9. Página "indisponível" persistente após 3 leituras não conta como falha de transporte (não gera `exit 2`);
   a linha fica com os dados da busca e o log lista o id.
10. JSON salvo em `json\quintoandar\<id>.json` é o `__NEXT_DATA__` inteiro da página (≈ 30 KB cada),
    para auditoria fiel.
11. DESCOBERTAS-TECNICAS.md recebeu uma nota de correção datada na seção 2 (host real, campos da página,
    intermitência). Não fiz commit no git (deixo para o fechamento da etapa pelo orquestrador).

## 5. Pendências
- Atualizar `criterios.json` → `sites.QUINTOANDAR.api` para o host real (decisão do orquestrador).
- INATIVO não exercitado ao vivo em venda (ver acima).
- `descricao_resumo` vazia em 17 anúncios: a página não traz `remarks`; a API de busca também não tem
  descrição. Sem alternativa sem navegador.
- Só 4 anúncios com `bairro_site = Ipanema` e 7 Leblon nos critérios; 83 são Copacabana (parte fora do
  Arpoador). O recorte fica a cargo do consolidador (polígono + ruas).
- A pasta `_trabalho\testes-quintoandar\` contém a saída real (CSV, 101 JSONs, log) e as evidências do
  passo 0; a pasta `_tmp-quintoandar` é removida ao fim de cada coleta completa sem falhas.
