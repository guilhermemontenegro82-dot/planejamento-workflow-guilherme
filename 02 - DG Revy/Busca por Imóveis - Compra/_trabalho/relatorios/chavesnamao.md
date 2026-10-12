# Chaves na Mão — coletor e verificador (relatório de construção, 11/10/2026)

Componentes: `Skills\scripts\coletar-chavesnamao.ps1` e `Skills\scripts\verificar-chavesnamao.ps1`.
Teste real em `_trabalho\testes-chavesnamao\` (CSV, JSONs, logs e saída de console).

## 1. O que foi feito

### coletar-chavesnamao.ps1
1. Lê `criterios.json` (preço 500k–1,1M, área 35–70, caixas de mapa, user-agent e os campos técnicos novos do bloco `CHAVESNAMAO`).
2. **Busca** nas duas caixas pela API do mapa `search-map-items` (paginação por `cursor`, completa) com `level1=imoveis-a-venda`
   e `filtro=pmin:..,pmax:..,amin:..,amax:..`; depois **complementa** com `level3=ipanema` e `level3=leblon` na API
   `listing/items` (pega os anúncios com lat/lon trocados no site, que nenhuma caixa alcança). Dedup por `id`.
3. **Filtro local**: preço e área dentro dos limites (inclusivos), `transaction=SELL`, tipo residencial
   (Apartamento, Kitnet/Stúdio, Loft, Flat, Cobertura); salas/lojas/casas comerciais são descartadas e contadas no log.
4. **Detalhes** por anúncio em `/api/realestate/details/?id=` (0,5 s de pausa; 3 tentativas; 40 s): é o mesmo objeto que a
   página renderiza (`active`, `updatedAt`, `createdAt`, preços, descrição completa, fotos, vagas, coordenadas). O trecho útil
   vai para `<Saida>\json\chavesnamao\<id>.json` (sem `proximities`, `breadcrumb`, lista de fotos).
5. **Conferência de páginas HTML** (`-ConferirPaginas 3`, padrão): abre 3 páginas de anúncio, desfaz as aspas escapadas,
   lê o ld+json (`datePublished`/`dateModified`) e a tabela de preços (rótulo do Condomínio e do IPTU) e compara com a API;
   grava `pagina-<id>.json`.
6. **Normalização** para as 35 colunas do contrato, na ordem exata; CSV `;`, UTF-8 com BOM, decimal com ponto, datas ISO.
7. Log `coletar-chavesnamao.log` com totais por caixa × recebidos × novos, páginas/lotes ok e falha, excluídos por motivo,
   detalhes ok/vazio/falha, contagens de número/coordenada/precisão/IPTU, tempos. `exit 0` só sem falha de rede; `exit 2` se
   algum lote/página/detalhe falhou nas 3 tentativas **ou se uma caixa entregou menos do que o site declarou** (2ª rodada).

Parâmetros: `-Saida`, `-Criterios`, `-Endpoint mapa|lista`, `-Level3 <bairros>` (busca só por bairro, teste de cobertura),
`-Complemento <bairros>` / `-SemComplemento`, `-Level1`, `-SemDetalhes`, `-ConferirPaginas N`.

### verificar-chavesnamao.ps1
- Entrada: `-Chaves <csv>` (linhas `CHAVESNAMAO_<id>`, usa a coluna `link` se houver) ou `-Ids 1,2,3`.
- Para cada id: `/api/realestate/details/?id=` → `active=true` → **ATIVO** (preco_atual = `rawPrice`); `active=false` →
  **INATIVO**; `{}`/`{"digest":..}` → **NAO_ENCONTRADO**; HTTP ≠ 200 nas 3 tentativas → **ERRO**.
  Para INATIVO/NAO_ENCONTRADO abre também a página do anúncio e anota na evidência o que o site mostrou
  ("Ops! Esta página não existe" / redirecionamento para a home). `-SemPagina` desliga; `-ConferirAtivos` abre também os ATIVO.
- Saída `verificacao-chavesnamao.csv` (`chave;status_site;preco_atual;verificado_em;evidencia`) + log. `exit 2` se houve ERRO.

## 2. Como testar
```
powershell.exe -ExecutionPolicy Bypass -File "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\Skills\scripts\coletar-chavesnamao.ps1" -Saida "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_trabalho\testes-chavesnamao"
powershell.exe -ExecutionPolicy Bypass -File "...\Skills\scripts\coletar-chavesnamao.ps1" -Saida "...\_trabalho\testes-chavesnamao\mapa-rapido" -SemDetalhes -ConferirPaginas 0      (≈45 s, só a busca)
powershell.exe -ExecutionPolicy Bypass -File "...\Skills\scripts\coletar-chavesnamao.ps1" -Saida "...\lista"  -Endpoint lista -SemDetalhes -ConferirPaginas 0                                (comparação de endpoint)
powershell.exe -ExecutionPolicy Bypass -File "...\Skills\scripts\coletar-chavesnamao.ps1" -Saida "...\level3" -Level3 ipanema,leblon -SemDetalhes -ConferirPaginas 0                        (comparação level3)
powershell.exe -ExecutionPolicy Bypass -File "...\Skills\scripts\verificar-chavesnamao.ps1" -Ids 46625539,12037455,18272012,99999999999,38000000 -Saida "...\verificacao-ids"
powershell.exe -ExecutionPolicy Bypass -File "...\Skills\scripts\verificar-chavesnamao.ps1" -Chaves "...\verificacao-chaves\amostra.csv" -Saida "...\verificacao-chaves"
powershell.exe -ExecutionPolicy Bypass -File "...\_trabalho\testes-chavesnamao\comparar-3-linhas.ps1"                                                                                        (3 linhas × página)
```
Conferir: código de saída, `coletar-chavesnamao.log` (resumo no fim), cabeçalho do CSV igual ao contrato, BOM `EF BB BF`.

## 3. Contagens obtidas (teste real)
Rodada final de 11/10/2026, 18:40–18:48, com o script já corrigido (ver seção 7). Saída em `_trabalho\testes-chavesnamao\`
(`bruto-chavesnamao.csv`, `coletar-chavesnamao.log`, `json\chavesnamao\<id>.json`, `json\chavesnamao\_lotes\`).

**Busca (716 anúncios únicos em 49 s)**
| Escopo | Declarado pelo site | Recebido | Novos | Lotes/páginas |
|---|---|---|---|---|
| Caixa Ipanema_Arpoador (`search-map-items`, cursor) | 603 | **603** | 603 | 41 lotes, 0 falha |
| Caixa Leblon (`search-map-items`, cursor) | 132 | **132** | 110 | 9 lotes, 0 falha |
| Complemento `level3=ipanema` (`listing/items`, pg) | 251 | 225 (trava dos "similares" na pg 16) | 2 | 15 páginas |
| Complemento `level3=leblon` (`listing/items`, pg) | 76 | 60 (trava na pg 5) | 1 | 4 páginas |

**Filtro local**: aceitos **581**; excluídos **135**, todos por tipo não residencial (70 Conj. Comercial/Sala, 55 Loja/Comércio,
5 Casa/Sobrado, 5 Casa/Sobrado Comercial — reconstruído dos lotes por `excluidos-tipo.ps1`); 0 fora de preço, 0 fora de área,
0 "não é venda", 0 sem preço/área (o filtro do site já aplica preço e área; o local só confirma).

**Detalhes (`/details/`)**: 581 ok, 0 vazios, 0 falhas, 0 `active=false`, em 438 s. **3 páginas HTML** conferidas
(46055090, 42996251, 20021472): `dateModified` = `updatedAt` da API; Condomínio com rótulo "/mês"; IPTU sem base; `active:true`;
404 = False; título com o id = True.

**CSV**: 581 linhas × 35 colunas (34 do contrato + `bruto_json`), BOM, `;`, ponto decimal, datas ISO, chaves únicas.
| Contagem | Valor |
|---|---|
| `bairro_site` | Copacabana 308, Ipanema 164, Leblon 63, Gávea 45, Lagoa 1 |
| `tipo` | Apartamento 535, Kitnet/Studio 28, Flat 18 (Cobertura 0) |
| `precisao_coord` | aproximada 485, exata 75, nenhuma 21 |
| número | com 75, sem 506 |
| coordenada | com 560, sem 21 (lat/lon trocados pelo site e corrigidos: 3; 44 pontos repetidos por 2+ anúncios) |
| preenchimento | rua 562, CEP 523, condomínio 550, IPTU 517, andar 14, destaques 552, fotos 581, `publicado_em`/`atualizado_em` 581 |
| quartos | 1 = 424, 2 = 135, 3 = 2, vazio 20 |
| vagas | 1 = 155, vazio 426 |
| `tipo_anunciante` | Imobiliária 580, Particular 1 |
| `status_site` | ATIVO 581 |
| IPTU por base | ano (descrição) 8, ano (descrição: cota mensal × 10/12) 4, ano (estimado pelo valor) 231, mês (descrição) 4, mês (estimado pelo valor) 270, sem IPTU 64 |
| IPTU cru (R$), histograma | 1–100: 16, 101–300: 222, 301–500: 33, 501–700: 3, 701–1000: 12, 1001–2000: 135, 2001–4000: 94, > 4000: 2 |
| IPTU anualizado ÷ preço | mín 0,02 %, mediana 0,23 %, máx 0,88 %; nenhum acima de 1 % |

Preço mín/máx 510 000 / 1 100 000; área mín/máx 35 / 70.

## 4. Tempo de execução
| Execução | Tempo |
|---|---|
| Coleta completa, rodada final (busca 49 s + detalhes 438 s + 3 páginas 5 s + CSV 7 s) | **501 s (8,4 min)**, exit 0 |
| Coleta completa, 1ª rodada desta verificação (antes das correções de IPTU/404) | 556 s, exit 0 |
| Só busca (`-SemDetalhes -ConferirPaginas 0`) | ≈ 50 s |
| `-Level3 leblon -SemDetalhes -ConferirPaginas 0` | 3 s (4 páginas) |
| `verificar-chavesnamao.ps1` com 4 ids (3 ativos sem página + 1 inventado com página) | 3 s |
| `verificar-chavesnamao.ps1` com `-ConferirAtivos` (3 ids, 3 páginas) | ≈ 5 s |
| Endpoint inexistente (teste do `exit 2`): 2 caixas × 3 tentativas | 10 s, exit 2 |

O custo está no `/details/` (≈ 0,75 s por anúncio: 0,5 s de pausa + rede). Para rodadas quinzenais, ver pendência 6.

## 5. Decisões tomadas (premissas)
1. **Endpoint principal = `search-map-items` (cursor), não `listing/items` (pg).** O `listing/items` trava: depois dos
   resultados reais o site preenche as páginas com "similares" da cidade inteira (`pageBreak` `[400]` → `[400,0,53711]`,
   `totalListing` 400 → 54 111) e as últimas ~2 páginas (≈25 anúncios) já vêm misturadas — perdeu 25/535 e 24/129 nas caixas,
   e certas caixas (metade oeste de Ipanema) só devolvem "similares" desde a pg 1. O endpoint do mapa devolveu 400/400 e 535/535.
   O `-Endpoint lista` continua disponível, com detecção do `pageBreak`.
2. **`level1=imoveis-a-venda` + filtro de tipo local**, para incluir kitnet/stúdio/flat/loft (critério do Guilherme inclui
   kitnet/studio). `kitnet-a-venda` ignora a caixa e o level3 no site (devolve a cidade inteira) e não serve.
3. **`level3=ipanema,leblon` como complemento** (não como alternativa): cobre menos que as caixas (sem Arpoador/Copacabana e
   perde os últimos 25 pela trava), mas trouxe anúncios com **lat/lon trocados** no site (ex.: `lat=-43.19, lon=-22.98`) que
   as caixas não alcançam. O coletor corrige a troca ao ler. `level3=copacabana` (1 348 apartamentos, ~90 páginas) ficou fora
   por custo × ganho — ver pendências.
4. **Detalhes pela API `/details/` em vez de abrir as ~570 páginas HTML** (670 KB cada). É o mesmo objeto que a página mostra,
   40× mais leve; as 3 páginas HTML da conferência provam a equivalência (datas do ld+json = `createdAt`/`updatedAt`; rótulos).
5. **Base do IPTU**: o site **não** informa (Condomínio sai "R$ 1.600/mês", IPTU sai só "R$ 330"; o JS renderiza o valor cru).
   Regra adotada: dica explícita na descrição ("10 cotas de R$330" → mês; "anual" → ano) prevalece; sem dica, valor
   **≤ 700 = cota mensal**, **> 700 = anual** (`iptu_limite_mensal` em criterios.json). A distribuição é bimodal
   (161 anúncios entre 101–300 e 186 acima de 1 000; só 14 entre 501–1 000). `iptu_informado` guarda o valor cru e a origem
   da base (`330/mês (descrição)`, `1100/ano (estimado pelo valor)`) para auditoria e eventual recálculo.
   **Corrigido na 2ª rodada (seção 7, item E):** a "dica da descrição" agora **casa os números da descrição com o valor do site**:
   valor igual → a base que acompanha o número; cota mensal × 10 ou × 12 = valor do site → ano (`1053/ano (descrição: cota
   mensal x 10 ou 12)`); anual ÷ 10 ou ÷ 12 = valor do site → mês; a janela de leitura começa em "IPTU" e para em "Condom"
   (o "/mês" do condomínio vinha sendo lido como base do IPTU) e atravessa o ponto de milhar ("R$ 3.600/ano" não era lido).
   Só sem número que case é que vale a base por palavra, e só então o limite de R$ 700. Isso corrigiu 6 anúncios que
   estavam como "mês" com R$ 1.053–3.600 (IPTU anualizado de até 4,7 % do preço — impossível).
6. **Coordenadas**: ao contrário do anotado nas descobertas, há coordenada por anúncio. Com número e endereço público →
   `exata`; sem número → `aproximada` (é o ponto da rua: vários anúncios repetem a mesma coordenada); igual ao centroide do
   bairro → `nenhuma` com lat/lon vazios (como a tarefa pediu); sem coordenada → `nenhuma`.
   **Atenção para o consolidador**: o ponto "aproximado" sem número pode estar a centenas de metros do imóvel (centro da rua);
   em ruas que cruzam a borda do polígono, vale mais a regra da lista de ruas.
7. **Caixas**: Leblon ajustada para N -22.9745 S -22.9925 E -43.2125 **W -43.2390** (bbox OSM do bairro N -22.9767 S -22.9896
   E -43.2142 W -43.2380, com margem). Ipanema_Arpoador: borda leste movida de -43.19071 para **-43.18600** porque um anúncio
   da Rua Francisco Otaviano, 55 ficava 36 m fora da caixa; o Arpoador/Posto 6 inteiro agora cabe. As duas caixas se sobrepõem
   (dedup por id) e pegam Gávea/Lagoa/Copacabana — o polígono do consolidador decide.
8. `rua` recebe o nome do site com as partículas em minúsculas ("Rua Bulhões de Carvalho", como o ld+json da página mostra);
   `numero` só quando tem dígito (`--` e vazio viram vazio). `rua`/`numero` são preenchidos mesmo com `publicAddress=false`
   (o dado está na API; a precisão da coordenada cai para `aproximada`).
9. `tipo_anunciante`: PJ → Imobiliária (Construtora se o nome disser construtora/incorporadora), PF → Particular.
10. `destaques`: só pelo texto (título, descrição, itens privativos e comuns) e `petFriendly`; `acceptTrade` vem `true` em
    100 % dos anúncios (padrão do site) e **não** gera "aceita permuta".
11. `andar`: número extraído do texto ("3º andar", "andar 8"); "andar alto" vai para `destaques`. Não há campo próprio no site.
    **2ª rodada:** "prédio de 10 andares" não vira mais andar 10 (`andar\b`) e "03" sai normalizado como "3".
12. `bruto_json` recebe o caminho relativo do JSON (`json/chavesnamao/<id>.json`), não o JSON.
13. `status_site` = ATIVO para tudo que veio da busca; se o `/details/` disser `active=false`, INATIVO (contado no log).
14. Verificação pela API e não pela página: a página de anúncio inativo redireciona para a home e a de id inexistente mostra
    "Ops! Esta página não existe" com HTTP 200 — pela página não dá para separar INATIVO de NAO_ENCONTRADO.
    **Corrigido na 2ª rodada:** "Ops! Esta página não existe" está em **toda** página do site (componente not-found
    pré-renderizado no shell do Next.js), inclusive nas de anúncio válido — a 1ª rodada marcava `404=True` nas 3 páginas
    válidas. O marcador real de 404 é o digest `NEXT_HTTP_ERROR_FALLBACK;404`; anúncio inativo **não** redireciona: devolve
    a home renderizada na própria URL (título "Classificados de imóveis, carros e motos", sem `"active":true` nem o id);
    anúncio válido tem `<title>... - ID: <id> | Chaves na Mão` e `"id":<id>,`. Coletor e verificador usam esses sinais.
16. **Cobertura truncada = `exit 2`** (2ª rodada): se uma caixa do mapa entregar menos itens do que o `totalResults` declarado,
    ou se o cursor se repetir / bater no limite de 400 lotes, o log diz `INCOMPLETO: ... faltam N` e o script sai com 2,
    mesmo sem falha de rede (regra 6 do contrato: nunca fingir cobertura). Nas duas rodadas as caixas entregaram 603/603 e 132/132.
17. Loft é mapeado para `Kitnet/Studio` (não há valor "Loft" no contrato); `Apart Hotel` para `Flat`.
15. criterios.json ganhou campos técnicos no bloco `CHAVESNAMAO` (`api_mapa`, `api_detalhes`, `level1`, `iptu_limite_mensal`,
    `level3_complemento`, `_nota`) e as caixas finais. DESCOBERTAS-TECNICAS.md ganhou a seção 3.1.

## 6. Pendências
1. **`status_site = INATIVO` no bruto** (premissa 13) foge do contrato, que diz "ATIVO para tudo que veio da busca". Nesta
   rodada houve 0 casos, mas o consolidador precisa decidir: tratar INATIVO como indisponível (não levar à planilha) ou o
   coletor passar a descartar a linha. Decisão para o construtor do consolidador.
2. **Coordenada "aproximada" é o ponto da rua** (485 de 581; 44 pontos repetidos por 2+ anúncios), não o do imóvel. Em ruas que
   cruzam a borda do polígono (Barão da Torre, Visconde de Pirajá, Bartolomeu Mitre…), o consolidador deve preferir rua+número
   ou a lista de ruas, e não decidir `SIM`/`NAO` só pelo ponto. Só 75 anúncios têm número (precisão `exata`).
3. **Complemento `level3` perde os últimos ~25 de cada bairro** (trava dos "similares" do site) e trouxe só 3 anúncios a mais
   (os de lat/lon trocados). `level3=copacabana` ficou fora por custo (1 348 anúncios, ~90 páginas): anúncios de Copacabana /
   Arpoador com lat/lon trocados no site não são alcançados. Aceitável, mas vale registrar.
4. **Base do IPTU continua estimada em 501 de 517 anúncios** (limite R$ 700). A evidência sustenta (todos os "mensal" explícitos
   ≤ 330, todos os "anual" explícitos ≥ 1 053, razão anualizada 0,02–0,88 % do preço), mas é estimativa; `iptu_informado`
   guarda o cru para recálculo se o Guilherme preferir outra regra.
5. **`destaques` é só por texto**: "aceita financiamento" dispara também em "não aceita financiamento" e "pet" em "pet shop"
   (não conferido caso a caso). Usar como pista, não como fato.
6. **Tempo de 8,4 min por rodada** vem do `/details/` por anúncio. Para rodadas quinzenais o orquestrador pode pedir detalhes
   só dos ids novos (os já conhecidos vêm completos da busca, exceto `createdAt`/`updatedAt`/descrição completa) — não
   implementado; o coletor hoje é sempre completo.
7. Caixas pegam Gávea (45) e Lagoa (1): o polígono do consolidador decide; o bruto não filtra bairro.
8. `comparar-3-linhas.ps1` (1ª construção) ficou na pasta; `comparar-6-linhas.ps1` o substitui.

## 7. Verificação independente (2ª rodada, 11/10/2026, 18:20–18:50)
Feita do zero por outro construtor, com tudo executado de verdade nesta máquina (PowerShell 5.1, `curl.exe`). Scripts de
conferência em `_trabalho\testes-chavesnamao\`: `conferir-contrato.ps1` → `conferencia-contrato.txt`; `comparar-6-linhas.ps1` →
`comparacao-6-linhas.txt` (JSONs e páginas em `explor\`); `excluidos-tipo.ps1` → `excluidos-tipo.txt`.

| # | Item | Resultado | Evidência |
|---|---|---|---|
| A | Coleta completa para `_trabalho\testes-chavesnamao\` | **PASS** | 2 rodadas completas: 556 s e 501 s, `exit 0`, 0 falhas de rede, 0 cobertura truncada; `coletar-chavesnamao.log`, `exit-coleta.txt`, `saida-console-coleta-completa.txt` |
| B | BOM EF BB BF, separador `;`, 34 colunas na ordem exata, `bruto_json` só no fim | **PASS** | `conferencia-contrato.txt`: 23 itens PASS, 0 FAIL |
| B | Decimal com ponto, datas ISO, chave única `CHAVESNAMAO_<codigo>` | **PASS** | 0 vírgulas em campos numéricos; 0 datas fora de `yyyy-MM-dd`; 0 duplicatas; `capturado_em` único |
| B | Preço 500 000–1 100 000, área 35–70, tipos só residenciais | **PASS** | mín/máx 510 000 / 1 100 000 e 35 / 70; tipos Apartamento 535, Kitnet/Studio 28, Flat 18; 0 `Outro` |
| B | Coerência extra: `exata` exige número + lat/lon; `nenhuma` exige lat/lon vazios; coordenadas na Zona Sul; link no padrão `/imovel/<slug>/id-<codigo>/`; CEP com hífen; `iptu_mes` = cru ou cru/12; destaques só com rótulos do contrato; `bruto_json` aponta para arquivo existente | **PASS** | idem |
| C | 6 linhas sorteadas (semente 20261011: 41684048, 47034856, 34610478, 44243188, 47495704, 46580014) × API `/details/` | **PASS** | preço, área útil/total, rua, nº, CEP, bairro, condomínio, IPTU cru, quartos, banheiros, suítes, vagas, `createdAt`/`updatedAt`, `active`, anunciante, fotos, lat/lon: **todos iguais** nas 6; única "diferença" é o mapeamento `Kitnet / Stúdio` → `Kitnet/Studio` |
| C | Links das 6 (`curl -L -o NUL -w "%{http_code}"`) | **PASS** | 6 × HTTP 200 |
| C | 2 páginas HTML: 47495704 (Rua Marquês de São Vicente, **86**, Gávea) e 41684048 (Rua Sá Ferreira, sem nº, Copacabana) | **PASS** | ld+json `streetAddress`, `postalCode`, `price`, `floorSize`, `numberOfRooms`, `datePublished`, `dateModified`, `latitude/longitude` = CSV; tabela "Condomínio R$ 1.823/mês" e "IPTU R$ 2.700" (sem base; texto visível "Condomínio R$ 1.823/mês IPTU R$ 2.700") |
| C | Base do IPTU faz sentido? | **PASS (após correção)** | O site não rotula (página: "IPTU R$ 2.700" ao lado de "Condomínio R$ 1.823/mês"). Evidência da regra: histograma bimodal (271 anúncios ≤ 500, 231 ≥ 1 001, só 15 entre 501–1 000); 16 descrições com base explícita — 12 "anual" com cru ≥ 1 053 e 4 "mensal" com cru ≤ 330, nenhuma contra o limite 700; razão IPTU anualizado ÷ preço de 0,02 % a 0,88 % (mediana 0,23 %), compatível com IPTU residencial carioca. **Na 1ª rodada 6 anúncios estavam errados** (R$ 1.053–3.600 lidos como mensais, razão até 4,7 %) — corrigidos (item E) |
| C | 3 dos 135 excluídos por tipo | **PASS** | 46424922 "Conj. Comercial / Sala" (Sala Comercial em Ipanema, 40 m², R$ 630 000), 41196453 "Loja / Comércio" (Ponto comercial, Visconde de Pirajá), 28205213 "Conj. Comercial / Sala" (Rua Joana Angélica): `/details/` confirma `category=commercial` nos 3. Os 135 = 70 salas + 55 lojas + 5 casas + 5 casas comerciais |
| D | `verificar-chavesnamao.ps1 -Ids 45190338,14940525,40303365,99999999999` | **PASS** | 3 ATIVO (preços 940 000, 950 000, 1 100 000) + 1 NAO_ENCONTRADO; `exit 0`; CSV com BOM e as 5 colunas `chave;status_site;preco_atual;verificado_em;evidencia` (`verificacao-ids\`) |
| D | `-Ids 38000000,99999999999,45190338 -ConferirAtivos` (inativo real, inventado, ativo) | **PASS (após correção)** | INATIVO "página: sem o anúncio, site mostrou a home no lugar"; NAO_ENCONTRADO "página: 404 do site (NEXT_HTTP_ERROR_FALLBACK;404)"; ATIVO "página: anúncio presente (… - ID: 45190338)" (`verificacao-ids-2\`) |
| D | `-Chaves verificacao-chaves\amostra.csv` (3 reais + 1 inventado) | **PASS** | 3 ATIVO + 1 NAO_ENCONTRADO, `exit 0` |
| E | `Invoke-WebRequest`/`Invoke-RestMethod`/`HttpClient`/`WebClient` | **PASS** | 0 ocorrências nos 2 scripts (grep); HTTP só por `curl.exe` |
| E | Decimal com vírgula | **PASS** | `FmtNum`/`Coord`/caixas usam `InvariantCulture`; CSV sem vírgula em campo numérico; teste em cultura pt-BR |
| E | `exit` sempre 0? | **PASS (reforçado)** | `exit 2` com falha de rede (testado com endpoint inexistente: `[FALHA] … http=404 (3 tentativas)`, `RESULTADO: INCOMPLETO (exit 2)`), e agora também com cobertura truncada (premissa 16) |
| E | Variáveis com o nome de um parâmetro (PowerShell não distingue caixa) | **FAIL → corrigido** | `verificar`: `$saida = & $curl …` dentro de `Baixar` (parâmetro `-Saida`) → `$resp`. `coletar`: parâmetro de função `$capturadoEm` igual à variável de script → `$capturado`; parâmetro `$level3` de `ColetarLista` igual ao `-Level3` do script → `$bairro`. Nenhum caso estava produzindo erro (escopo de função), mas eram as armadilhas pedidas |
| E | Cobertura truncada em silêncio | **FAIL → corrigido** | `ColetarMapa` saía do laço no limite de 400 lotes ou com cursor repetido sem logar, e "recebidos < totalResults" era só AVISO com `exit 0`. Agora: log explícito e `exit 2`. `ColetarLista` loga o limite de 60 páginas |
| E | Regex de andar | **FAIL → corrigido** | "prédio de 10 andares" virava andar 10; "03" saía sem normalizar (1 linha). Teste unitário com 8 frases |
| E | Detecção de "página não existe" | **FAIL → corrigido** | ver premissa 14; o log da 1ª rodada mostrava `404=True` em 3 páginas válidas |
| E | `-Level3` após a renomeação | **PASS** | `-Level3 leblon -SemDetalhes -ConferirPaginas 0` → 57 linhas, `exit 0` |
| E | Teste unitário da nova `NormalizarIptu` (código extraído do script) | **PASS** | 18/18 casos (os 15 textos reais da rodada + 3 sintéticos) |
| F | Diferença entre as 2 rodadas (antes/depois das correções) | **PASS** | mesmas 581 chaves; colunas alteradas: `capturado_em` (581), `iptu_informado` (7), `iptu_mes` (6), `andar` (1) — nada mais mudou |

Arquivos alterados nesta rodada: `Skills\scripts\coletar-chavesnamao.ps1`, `Skills\scripts\verificar-chavesnamao.ps1` (BOM e sintaxe
conferidos), `_trabalho\DESCOBERTAS-TECNICAS.md` (seção 3.1, correções), este relatório. `criterios.json` não foi tocado.
