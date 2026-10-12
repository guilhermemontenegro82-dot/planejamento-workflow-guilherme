# Módulo de área (polígonos + ruas + geocodificação) — relatório de construção

Data: 11/10/2026. Raiz: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra`.
Tudo foi executado de verdade nesta máquina (PowerShell 5.1, curl.exe, sem Python/Node); os números abaixo saíram das execuções.

## 1. O que foi entregue

| Arquivo | O que é |
|---|---|
| `Skills\scripts\area.ps1` | Módulo (dot-source pelo `consolidar.ps1`) com `Import-Poligonos`, `Test-PontoNoPoligono`, `Get-DistanciaBordaMetros`, `Normalize-Rua`, `Test-RuaNaLista`, `Get-Geocode`, `Resolve-DentroArea`, `Get-AreaKm2`, `Get-PoligonoDoPonto`; modo CLI `-Teste` e `-Endereco/-Numero/-Bairro`. BOM UTF-8, comentários em pt-BR. |
| `Áreas de interesse\poligonos\ipanema.geojson` | Feature/Polygon, [lon, lat], anel fechado, anti-horário; properties `nome, fonte, gerado_em, descricao_bordas, area_km2, vertices`. 71 vértices, **1,747 km²**. |
| `Áreas de interesse\poligonos\leblon.geojson` | Idem. 71 vértices, **0,961 km²**. |
| `Áreas de interesse\poligonos\poligonos.html` | Leaflet 1.9.4 (unpkg) sobre OpenStreetMap, os dois polígonos (azul Ipanema, verde Leblon) e os pontos de teste (verde SIM, laranja LIMITE, vermelho NAO; anel vermelho grosso = FAIL). Abrir no navegador (precisa de internet para os tiles e o Leaflet). |
| `Áreas de interesse\poligonos\pontos-teste.csv` | 23 endereços reais geocodificados pelo próprio módulo (`rua;numero;bairro;lat;lon;esperado;observacao`). |
| `_dados\geocache.csv` | Cache da geocodificação (`rua;numero;bairro;lat;lon;precisao;consultado_em;detalhe`), já com os 23 endereços de teste. |
| `_trabalho\area\construir-poligonos.ps1` | Constrói os dois geojson a partir das geometrias reais do OSM (arquivos `_trabalho\area\overpass\vias-*.json`, baixados do Overpass) com as margens por trecho; checa auto-interseção e área; imprime 37 pontos de controle. |
| `_trabalho\area\gerar-pontos-teste.ps1` | Geocodifica a lista de teste pelo módulo e grava `pontos-teste.csv`. |
| `_trabalho\area\gerar-html.ps1` | Gera `poligonos.html` a partir dos geojson + `pontos-teste.csv` (coordenadas embutidas; `file://` não permite ler o geojson por fetch). |
| `_trabalho\teste-integracao-area\2026-10-11\` | Teste de integração: `bruto-quintoandar.csv` (101 anúncios reais) → `coleta.csv`, `consolidar.log`, `consolidar-resumo.json`. |

O que o construtor anterior deixou e foi reaproveitado: as consultas Overpass salvas (`vias-ipanema.json`, `vias-leblon.json`, `vias-extra.json`, `numeros.json`), o `analise.ps1` (distâncias entre vias) e o `desenhar.ps1` (PNGs de apoio). Não havia nenhuma entrega.

## 2. Como testar

```
cd "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra"
powershell -NoProfile -ExecutionPolicy Bypass -File "Skills\scripts\area.ps1" -Teste
powershell -NoProfile -ExecutionPolicy Bypass -File "Skills\scripts\area.ps1" -Endereco "R. Visc. de Pirajá" -Numero 540 -Bairro Ipanema
powershell -NoProfile -ExecutionPolicy Bypass -File "_trabalho\area\construir-poligonos.ps1"      # refaz os geojson e imprime os pontos de controle
powershell -NoProfile -ExecutionPolicy Bypass -File "_trabalho\area\gerar-html.ps1"               # refaz o poligonos.html
powershell -NoProfile -ExecutionPolicy Bypass -File "Skills\scripts\consolidar.ps1" -Pasta "_trabalho\teste-integracao-area\2026-10-11"
```
Abrir `Áreas de interesse\poligonos\poligonos.html` no navegador para conferir o traçado contra a marcação vermelha.

## 3. Polígonos: como foram construídos

Método: cada trecho de borda é a geometria real da via no OSM (way ids fixos no `construir-poligonos.ps1`), afinada (nós a ≥ 20–60 m) e deslocada perpendicularmente pela margem do trecho; os cantos são vértices explícitos. A orla é a linha de costa do OSM (`natural=coastline`) deslocada 80 m mar adentro. O anel é checado contra auto-interseção (nenhuma) e a área é calculada por shoelace em metros (projeção equiretangular, cos(-22,985°)).

### Ipanema + Arpoador (71 vértices, 1,747 km²) — sentido horário a partir do canto NO
| Trecho | Geometria OSM | Margem | Observação |
|---|---|---|---|
| Canto NO | Henrique Dumont × Barão da Torre (≈ -22,98259, -43,21374) | +15 m N, +35 m O | |
| Norte | Rua Barão da Torre (way 220552826), da Henrique Dumont à Praça General Osório | **+15 m** para o norte | 35 m não serve: a Rua Redentor (fora) corre a só 60–80 m da Barão da Torre; com 35 m o lado norte do Redentor ficava a < 50 m da borda (LIMITE) e o gabarito pede NAO. A Barão da Torre em si dá LIMITE de qualquer forma (faixa de 50 m do contrato). |
| Nordeste | diagonal: fim da Barão da Torre + 35 m N (≈ -22,98331, -43,19678) → junção Gomes Carneiro/Bulhões/Francisco Sá + 60 m N (≈ -22,98337, -43,19423) | | Na marcação a linha passa ~40 m ao norte do fim da Barão da Torre e ~60–75 m ao norte da junção (medido em pixels com âncoras na Barão da Torre e na Vieira Souto; ±30 m). O trecho NO da Bulhões de Carvalho (rumo à Sá Ferreira) fica fora, perto da borda. |
| Nordeste | Rua Francisco Sá (ways 29626811, 795437750, 162651831, 341671987), da junção à Av. Atlântica | +25 m para NO | Via pendente; a marcação corre em cima do eixo dela. |
| Canto NE | Francisco Sá × Atlântica levado 80 m mar adentro (≈ -22,98250, -43,18834) | | Posto 5/6 |
| Leste | linha de costa de Copacabana (way 70574890), de Francisco Sá até antes da curva do Forte | +80 m mar adentro | A curva côncava do Forte fazia o deslocamento se cruzar; a borda segue reta pelo mar. |
| Sudeste | vértices no mar: (-22,9890, -43,1865) → (-22,9915, -43,1900) → (-22,9905, -43,1922) | | Corta a península do Forte de Copacabana / Pedra do Arpoador (sem edificação residencial), como a marcação, que não contorna a pedra. |
| Sul | linha de costa de Ipanema (way 371511361), do Arpoador à Henrique Dumont | +80 m mar adentro | |
| Oeste | vertical em lon -43,21374 (Av. Henrique Dumont + 35 m O), do mar ao canto NO | +35 m O | |

Fora, como no gabarito: Nascimento Silva (104 m da borda), Redentor (lado norte 58 m; lado sul LIMITE a 30 m), Alberto de Campos, Barão de Jaguaripe, Epitácio Pessoa, Saint Roman, Sá Ferreira, resto de Copacabana. Dentro: toda a fatia Francisco Otaviano / Bulhões (trecho SE) / Rainha Elizabeth / Raul Pompéia / Francisco Bhering / Joaquim Nabuco / Gomes Carneiro.

### Leblon (71 vértices, 0,961 km²) — sentido horário a partir do canto SO
| Trecho | Geometria OSM | Margem | Observação |
|---|---|---|---|
| Canto SO | mar, ≈ (-22,9902, -43,2270) | | Praça Vinte e Quatro de Outubro |
| Oeste | Av. Visconde de Albuquerque, pista leste (ways 370164934 … 549560903), da praia até ≈ -22,983 | **65 m para DENTRO** (leste) | A marcação não corre no eixo da VA: corre 70–110 m a leste dele (entre a VA e a Rita Ludolf/Dias Ferreira). Adotei 65 m (ponta de baixo) para a Rua Dias Ferreira (incluída, "conferir limite") ficar com os dois lados a > 50 m da borda. Prédios de frente para a VA ficam 25–40 m fora → LIMITE (não NAO). |
| Noroeste | Rua Dias Ferreira (ways 180211960, 917999874) + 35 m para NO, até o fim NE dela (≈ -22,98156, -43,22398) | +35 m NO | Rua listada → fica inteira dentro. A marcação corta o fim NE dela (±30 m); prevaleceu a lista. |
| Norte | Rua Humberto de Campos (ways 119860676, 190627094), de Bartolomeu Mitre a Borges de Medeiros | +35 m N | Cruza a Bartolomeu Mitre em ≈ -22,98216 (≈ nº 530). |
| Canto NE | Humberto de Campos × Borges de Medeiros + 35 m N + 35 m L (≈ -22,98151, -43,21479) | | |
| Leste | Av. Borges de Medeiros (ways 962083688 … 957238723), de Humberto de Campos à praia | +35 m L (Jardim de Alah) | |
| Canto SE / Sul | mar ≈ (-22,9880, -43,2157); linha de costa do Leblon (way 371512811) + 80 m mar adentro | | |

Fora: Gilberto Cardoso (284 m), Timóteo da Costa, Igarapava, Codajás, Bartolomeu Mitre/Afrânio de Melo Franco ao norte da Humberto de Campos, Borges de Medeiros ao norte da Humberto de Campos (nº 701: 67 m fora). Dentro: Shopping Leblon (Afrânio de Melo Franco 290, 156 m da borda), Dias Ferreira inteira (78 → 54 m, 420 → 57 m, 679 → 14 m/LIMITE), Rita Ludolf (87 → 67 m), Cupertino Durão.

### Leitura da marcação: dois pontos em que a lista de ruas (CEP) e a linha vermelha divergem
- **Av. Bartolomeu Mitre "até 1110/1111"** e **Av. Borges de Medeiros "até 1098/1111"**: pelos números de porta do OSM a numeração é ~1,1 nº/m e o 1110 da Bartolomeu Mitre fica ≈ 500 m ao norte da Humberto de Campos (perto do Jóquei); o 1098 da Borges ≈ 330 m ao norte. Ou seja, a faixa de `ruas.csv` é a faixa postal do Leblon, não o limite da marcação. O polígono segue a linha vermelha (Humberto de Campos + 35 m). Consequência: Bartolomeu Mitre 990 (anúncio real do QuintoAndar, 336 m ao norte) = NAO; Borges 701 = NAO.
- **Rua Bulhões de Carvalho**: a lista inclui a rua inteira ("trecho do Arpoador"); a marcação deixa o trecho NO (rumo à Sá Ferreira, nºs ~450–700) de fora. O polígono segue a marcação, com a diagonal alta o bastante para esse trecho dar LIMITE (anúncios reais 530/537: 43–46 m fora) e não NAO.

## 4. Resultado do `area.ps1 -Teste` (colado)

```
Polígono Ipanema: 72 vértices, 1,747 km²
Polígono Leblon: 72 vértices, 0,961 km²
PASS  Rua Visconde de Pirajá, 540 (Ipanema): esperado SIM | obtido SIM — polígono Ipanema, 109 m da borda; rua na lista
PASS  Rua Garcia d'Ávila, 60 (Ipanema): esperado SIM | obtido SIM — polígono Ipanema, 205 m da borda; rua na lista
PASS  Rua Francisco Otaviano, 61 (Copacabana): esperado SIM | obtido SIM — polígono Ipanema, 338 m da borda; rua na lista
PASS  Avenida Rainha Elizabeth, 200 (Copacabana): esperado SIM | obtido SIM — polígono Ipanema, 220 m da borda; rua na lista
PASS  Avenida Ataulfo de Paiva, 900 (Leblon): esperado SIM | obtido SIM — polígono Leblon, 273 m da borda; rua na lista
PASS  Rua Dias Ferreira, 100 (Leblon): esperado SIM | obtido SIM — polígono Leblon, 60 m da borda; rua na lista
PASS  Rua Prudente de Morais, 450 (Ipanema): esperado SIM | obtido SIM — polígono Ipanema, 232 m da borda; rua na lista
PASS  Rua Cupertino Durão, 50 (Leblon): esperado SIM | obtido SIM — polígono Leblon, 300 m da borda; rua na lista
PASS  Rua Bulhões de Carvalho, 100 (Copacabana): esperado SIM | obtido SIM — polígono Ipanema, 244 m da borda; rua na lista
PASS  Rua Nascimento Silva, 200 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (103 m do Ipanema); rua fora da lista
PASS  Rua Alberto de Campos, 25 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (236 m do Ipanema); rua fora da lista
PASS  Rua Barão de Jaguaripe, 100 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (162 m do Ipanema); rua fora da lista
PASS  Avenida Epitácio Pessoa, 1000 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (75 m do Ipanema); rua fora da lista
PASS  Rua Redentor, 100 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (59 m do Ipanema); rua fora da lista
PASS  Avenida Visconde de Albuquerque, 300 (Leblon): esperado NAO | obtido NAO — fora dos polígonos (116 m do Leblon); rua fora da lista
PASS  Rua Gilberto Cardoso, 50 (Leblon): esperado NAO | obtido NAO — fora dos polígonos (247 m do Leblon); rua fora da lista
PASS  Rua Timóteo da Costa, 100 (Leblon): esperado NAO | obtido NAO — fora dos polígonos (348 m do Leblon); rua fora da lista
PASS  Avenida Nossa Senhora de Copacabana, 900 (Copacabana): esperado NAO | obtido NAO — fora dos polígonos (867 m do Ipanema); rua fora da lista
PASS  Rua Barata Ribeiro, 630 (Copacabana): esperado NAO | obtido NAO — fora dos polígonos (1151 m do Ipanema); rua fora da lista
PASS  Rua Almirante Saddock de Sá, 216 (Ipanema): esperado NAO | obtido NAO — fora dos polígonos (294 m do Ipanema); rua fora da lista
PASS  Rua Barão da Torre, 300 (Ipanema): esperado SIM|LIMITE | obtido LIMITE — fora do polígono Ipanema por 3 m; rua na lista
PASS  Rua Humberto de Campos, 100 (Leblon): esperado SIM|LIMITE | obtido LIMITE — polígono Leblon, 22 m da borda (dentro); rua na lista
PASS  Rua Francisco Sá, 30 (Copacabana): esperado LIMITE | obtido LIMITE — polígono Ipanema, 11 m da borda (dentro); via pendente
TOTAL: 23/23 PASS, 0 FAIL
```

Como cada ponto foi posicionado (coluna `observacao` do CSV, resumida): 17 `interpolado` pelos números de porta do OSM da própria rua (Visc. de Pirajá 540: 43 números, R² 1; Barão da Torre 300: 15 números, R² 0,83; Redentor 100: entre os nºs 95 e 188; Humberto de Campos 100: 9 números, R² 0,99; Epitácio Pessoa 1000: 65 números, R² 0,74), 5 `rua` (Bulhões de Carvalho 100, Nascimento Silva 200, Barão de Jaguaripe 100, Visconde de Albuquerque 300, Gilberto Cardoso 50: ruas sem número de porta no OSM → ponto da via do Nominatim) e 1 `rua` pelo número OSM mais próximo (Saddock de Sá 216 → nº 266). Nenhum ponto precisou de ajuste de teste; dois polígonos foram ajustados durante a construção por causa dos testes (margem da Barão da Torre e da Visconde de Albuquerque, ver seção 3).

Origem das coordenadas dos pontos (coluna `observacao` do CSV): `numero` = número existe no OSM; `interpolado` = posição interpolada entre os números de porta do OSM da própria rua (ajuste linear nº × posição no eixo, lado pela paridade); `rua` = ponto da via (Nominatim) ou número OSM mais próximo (≤ 60 de diferença). O `-Teste` avalia o ponto do CSV como coordenada **exata** (o CSV é o gabarito de posição; o que se testa é o polígono e a regra).

## 5. Teste de integração (`consolidar.ps1` sobre 101 anúncios reais do QuintoAndar)

`powershell -NoProfile -ExecutionPolicy Bypass -File Skills\scripts\consolidar.ps1 -Pasta "_trabalho\teste-integracao-area\2026-10-11"` → `exit 0`, sem nenhuma incompatibilidade de assinatura (o `consolidar.ps1` não foi tocado).

- 101 brutos → 6 fora dos critérios (Cobertura) → 95 aceitos → **SIM 11 | LIMITE 5 | A CONFIRMAR 0 | NAO 79** (16 vão para a planilha).
- Por bairro do site: Copacabana 78 (SIM 9, LIMITE 4, NAO 65), Ipanema 4 (SIM 1, NAO 3), Leblon 7 (SIM 1, NAO 6), Gávea 3, Lagoa 1, Vidigal 2 (todos NAO). A coleta é 82 % Copacabana porque o viewport do QuintoAndar cobre a metade sul de Copacabana.
- **Copacabana fora do Arpoador = NAO** (Barata Ribeiro, Bolívar, Domingos Ferreira, Pompeu Loureiro, Djalma Ulrich, Hilário de Gouveia, Sá Ferreira, Saint Roman…), todos a > 200 m, a maioria a > 700 m.
- **Rua Alberto de Campos 25 = NAO** (224 m fora; também Alberto de Campos 51, 191 m).
- **Rua Almirante Saddock de Sá 216**: não é caso de borda — a rua fica entre a Nascimento Silva e a Epitácio Pessoa; o anúncio (coordenada exata -22,98039, -43,20296) está a **306 m** da borda → NAO.
- LIMITE (5): Francisco Sá 88 (28 m fora, via pendente), Raul Pompéia 152 (23 m dentro, esquina com a Francisco Sá), Bulhões de Carvalho 530/530/537 (43–46 m fora, rua na lista, trecho NO).
- SIM com "via pendente" no motivo: N. S. de Copacabana 1292 (72 m) e 1369 (207 m) — o polígono inclui o fim da NSC (entre Francisco Sá e Francisco Otaviano), como a marcação; a regra "pendente = LIMITE" só vale quando a via decide sozinha (passo 4), conforme o contrato.
- Duplicata: 1 grupo (Raul Pompéia 131, duas chaves com o mesmo endereço/área/preço).

Conferência manual de 6 linhas (rua/nº e coordenada contra o polígono):

| chave | rua, nº | coordenada | obtido | conferência |
|---|---|---|---|---|
| QUINTOANDAR_894898234 | Rua Gomes Carneiro, 130 | -22,98536, -43,19593 | SIM (224 m) | entre Visc. de Pirajá e Vieira Souto, miolo de Ipanema ✔ |
| QUINTOANDAR_895587858 | Av. Bartolomeu Mitre, 448 | -22,98285, -43,22326 | SIM (88 m) | 42 m ao sul do eixo da Humberto de Campos, dentro do grid do Leblon ✔ |
| QUINTOANDAR_895762104 | Rua Francisco Otaviano, 78 | -22,98701, -43,19150 | SIM (320 m) | meio da Francisco Otaviano, Arpoador ✔ |
| QUINTOANDAR_894849326 | Rua Alberto de Campos, 25 | -22,98112, -43,20307 | NAO (224 m) | 236 m ao norte da Barão da Torre, além da Nascimento Silva ✔ |
| QUINTOANDAR_895607996 | Av. Bartolomeu Mitre, 990 | -22,97849, -43,22447 | NAO (336 m) | 440 m ao norte da Humberto de Campos (perto da Gilberto Cardoso/Jóquei) ✔ |
| QUINTOANDAR_895340328 | Rua Bolívar, 165 | -22,97591, -43,19321 | NAO (795 m) | Copacabana, Posto 4 ✔ |

## 6. Geocodificação (`Get-Geocode`)

1. Cache `_dados\geocache.csv` (chave = rua normalizada + número + bairro). Nunca repete consulta que está no cache, inclusive as que falharam. Única exceção: resultado degradado por indisponibilidade momentânea do Overpass (marcado `[Overpass indisponível]` no `detalhe`) pode ser refeito; a nova linha é acrescentada no fim e passa a valer. Falha de rede do Nominatim não é gravada (tenta de novo na próxima rodada).
2. Nominatim structured (`street=<nº> <rua>`, city=Rio de Janeiro, state=RJ, country=Brazil, format=json, addressdetails=1, limit=3), User-Agent `busca-imoveis-dg/1.0`, ≥ 1,1 s entre pedidos. Só aceita `house_number` igual ao pedido (precisão `numero`). O Nominatim **não interpola**: para número que não existe no OSM devolve só a via.
3. Sem número no Nominatim: Overpass (`nwr["addr:housenumber"]["addr:street"~"<nome OSM>",i]` + `way["highway"]["name"~…]`, duas saídas: `out center tags;` e `out geom;`) traz os números de porta e a geometria da rua. Número exato no OSM → `numero`; senão ajuste linear nº × posição ao longo do eixo (PCA dos nós), primeiro só com os números da mesma paridade, depois com todos (R² ≥ 0,7; extrapolação até 120 m além dos conhecidos), lado pela paridade, afastamento = média das distâncias dos números conhecidos ao eixo local (8–25 m) → `interpolado`; senão número conhecido a ≤ 60 de diferença → `rua`; senão a própria via do Nominatim (mesmo nome normalizado; outro resultado só se cair a ≤ 400 m de uma via com esse nome) → `rua`; senão `falhou`.
4. No `Resolve-DentroArea`: `numero` e `interpolado` voltam ao passo 1 como **exata**; `rua` entra no passo 2 como **aproximada** (é um ponto da via, igual ao do Chaves na Mão).
5. O overpass-api.de deu 504 ("Dispatcher_Client … timeout") em boa parte das chamadas desta noite; o módulo faz até 5 tentativas (pausas 3/6/10/15 s) e trata 200 com `remark` de erro como falha.

## 7. Premissas adotadas (corrigir se discordar)
- Margens diferentes das sugeridas, pelos motivos da seção 3: Barão da Torre +15 m (Redentor a 60–80 m); Visconde de Albuquerque com a borda 65 m a leste do eixo (traçado da marcação); diagonal do Arpoador 35–60 m ao norte; Francisco Sá +25 m; demais vias incluídas +35 m; orla +80 m; península do Forte cortada pelo mar.
- Onde a lista de ruas (faixa postal) e a marcação divergem, prevalece a marcação (Bartolomeu Mitre e Borges ao norte da Humberto de Campos = fora; trecho NO da Bulhões de Carvalho = fora/LIMITE). Exceção: Dias Ferreira inteira dentro (lista + "conferir limite").
- Coordenada com `precisao_coord` vazia é tratada como `aproximada`; `bairro`/`nenhuma` = sem coordenada; lat/lon trocados (lat < -40) são destrocados.
- Coordenada aproximada a mais de 300 m fora, mas rua na lista (incluída ou pendente) → `A CONFIRMAR` em vez de `NAO` (a rua cruza a borda; prevalece a lista, como pedido para o Chaves na Mão).
- Geocodificação `interpolado` é tratada como exata (erro típico ≤ 30 m, coberto pela faixa de 50 m).
- O `geocache.csv` tem uma 8ª coluna `detalhe` (auditoria: de onde veio a coordenada) além das 7 do contrato.
- Limites 50/150/300 m lidos de `criterios.json` (`borda_limite_m`, `borda_aproximada_dentro_m`, `borda_aproximada_fora_m`); padrão interno igual se faltarem.

## 8. Pendências
- **Guilherme decidir**: (a) fim da Av. N. S. de Copacabana (1109/1170 ao fim) e Rua Francisco Sá — hoje o polígono inclui o fim da NSC (SIM pelo polígono, "via pendente" no motivo) e a Francisco Sá fica na borda (LIMITE); (b) trecho NO da Bulhões de Carvalho (LIMITE hoje); (c) Bartolomeu Mitre e Borges de Medeiros ao norte da Humberto de Campos (NAO hoje, embora a faixa postal vá até 1110/1098); (d) prédios de frente para a Visconde de Albuquerque (LIMITE hoje).
- Rodar a integração com o `bruto-chavesnamao.csv` quando ele existir (não havia em `_trabalho\testes-chavesnamao\`); é a fonte que mais usa os passos 2–4 (coordenada aproximada e sem coordenada).
- Overpass instável à noite: se muitas geocodificações saírem `rua` com `[Overpass indisponível]`, basta rodar de novo (o cache refaz só essas).
