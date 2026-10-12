<#
  coletar-quintoandar.ps1 — Coletor do QuintoAndar (imóveis à venda) para a Busca por Imóveis (Compra).

  O que faz
    1. Lê os critérios de "Sites e critérios para Busca\criterios.json" (preço, área, tipos, viewport).
    2. Consulta a API de busca do site (a mesma que o navegador usa):
         POST https://apigw.prod.quintoandar.com.br/house-listing-search/v2/search/list
       com um viewport único que cobre Ipanema, Leblon e Arpoador. Pagina por offset até esgotar
       hits.total.value e remove duplicatas por id. Reconfere preço/área/tipo localmente.
    3. Para cada anúncio, abre a página https://www.quintoandar.com.br/imovel/<id>/comprar e lê o
       __NEXT_DATA__ (número, CEP, lat/lng, condomínio, IPTU mensal, andar, ano, status, datas,
       descrição, fotos). Salva o JSON em <Saida>\json\quintoandar\<id>.json.
    4. Grava <Saida>\bruto-quintoandar.csv nas colunas exatas do CONTRATO-DADOS.md e o log
       <Saida>\coletar-quintoandar.log.

  Uso
    powershell -ExecutionPolicy Bypass -File coletar-quintoandar.ps1 -Saida <pasta> [-Criterios <json>]
        [-PageSize 200] [-LimitePaginas N] [-SemPaginas]
    -Saida          pasta de saída (padrão: _dados\<hoje>)
    -PageSize       tamanho da página da API (testado até 500; padrão 200)
    -LimitePaginas  abre só as N primeiras páginas de anúncio (para testes rápidos); as demais
                    linhas ficam só com os campos da busca
    -SemPaginas     não abre página nenhuma (só a busca)

  Código de saída: 0 se completou; 2 se alguma chamada falhou nas 3 tentativas ou a busca não
  cobriu o total informado pela API (o log diz o que faltou).

  Regras técnicas: HTTP só pelo curl.exe do Windows (o .NET é barrado pelo Cloudflare); JSON grande
  com JavaScriptSerializer; pausa de 0,4 s entre páginas da busca e 0,5 s entre páginas de anúncio;
  timeout 40 s; 3 tentativas com 2 s de pausa.
#>
[CmdletBinding()]
param(
  [string]$Saida = '',
  [string]$Criterios = '',
  [int]$PageSize = 200,
  [int]$LimitePaginas = 0,
  [switch]$SemPaginas
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$utf8semBom = New-Object System.Text.UTF8Encoding($false)
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

# ---------------------------------------------------------------- pastas e caminhos
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Criterios) { $Criterios = Join-Path $raiz 'Sites e critérios para Busca\criterios.json' }
if (-not $Saida) { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$Saida = (Resolve-Path $Saida).Path
$pastaJson = Join-Path $Saida 'json\quintoandar'
$pastaTmp = Join-Path $Saida '_tmp-quintoandar'
New-Item -ItemType Directory -Force -Path $pastaJson | Out-Null
New-Item -ItemType Directory -Force -Path $pastaTmp | Out-Null
$logPath = Join-Path $Saida 'coletar-quintoandar.log'
$csvPath = Join-Path $Saida 'bruto-quintoandar.csv'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

function Log([string]$msg) {
  $linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg
  [System.IO.File]::AppendAllText($logPath, $linha + "`r`n", $utf8bom)
  Write-Host $linha
}

Log "== coletar-quintoandar: início =="
Log "saída: $Saida"
Log "critérios: $Criterios"

# ---------------------------------------------------------------- critérios
$crit = Get-Content -Raw -Encoding UTF8 -Path $Criterios | ConvertFrom-Json
$cfgQA = $crit.sites.QUINTOANDAR
$ua = $crit.user_agent
if (-not $ua) { $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36' }
$precoMin = [int]$crit.preco_min; $precoMax = [int]$crit.preco_max
$areaMin = [double]$crit.area_util_min; $areaMax = [double]$crit.area_util_max
$vp = $cfgQA.viewport
$tiposPermitidos = @($cfgQA.house_types)
# A API do site mudou de host em relação ao criterios.json (api/yellow-pages dá 404); o host real
# está no código do site (módulo 56296: https://apigw.prod.quintoandar.com.br/house-listing-search).
$urlBusca = 'https://apigw.prod.quintoandar.com.br/house-listing-search/v2/search/list'
$modeloPagina = 'https://www.quintoandar.com.br/imovel/{id}/comprar'
if ($cfgQA.pagina_anuncio) { $modeloPagina = [string]$cfgQA.pagina_anuncio }
Log ("critérios: preço {0}-{1}, área {2}-{3} m², tipos {4}, viewport N{5} S{6} E{7} W{8}" -f $precoMin, $precoMax, $areaMin, $areaMax, ($tiposPermitidos -join '/'), $vp.north, $vp.south, $vp.east, $vp.west)

# ---------------------------------------------------------------- utilitários
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue
$js.RecursionLimit = 1000
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path $curl)) { Log "ERRO: curl.exe não encontrado em $curl"; exit 2 }

# Chamada HTTP via curl.exe com 3 tentativas. Devolve Codigo (HTTP), UrlFinal, Corpo, Exit, Tentativas.
function Invoke-Curl {
  param(
    [string]$Url,
    [string]$Metodo = 'GET',
    [string]$CorpoArquivo = '',
    [string[]]$Cabecalhos = @(),
    [string]$ArqSaida,
    [switch]$SeguirRedirect
  )
  $tentativa = 0; $ultimo = $null
  while ($tentativa -lt 3) {
    $tentativa++
    if (Test-Path $ArqSaida) { Remove-Item $ArqSaida -Force }
    $argumentos = @('-s', '-m', '40', '-A', $ua, '-o', $ArqSaida, '-w', '%{http_code}|%{url_effective}')
    if ($SeguirRedirect) { $argumentos += '-L' }
    foreach ($h in $Cabecalhos) { $argumentos += @('-H', $h) }
    if ($Metodo -eq 'POST') { $argumentos += @('-X', 'POST', '--data-binary', ('@' + $CorpoArquivo)) }
    $argumentos += $Url
    $saida = & $curl @argumentos
    $exit = $LASTEXITCODE
    $codigo = ''; $urlFinal = ''
    if ($saida) {
      $partes = ("$saida" -split '\|', 2)
      $codigo = $partes[0].Trim()
      if ($partes.Count -gt 1) { $urlFinal = $partes[1].Trim() }
    }
    $corpo = ''
    if (Test-Path $ArqSaida) { $corpo = [System.IO.File]::ReadAllText($ArqSaida, [System.Text.Encoding]::UTF8) }
    $ultimo = [pscustomobject]@{ Codigo = $codigo; UrlFinal = $urlFinal; Corpo = $corpo; Exit = $exit; Tentativas = $tentativa }
    # 200 e 4xx "legítimos" (400/404/410) são resposta final; o resto (000, 403, 429, 5xx, timeout) tenta de novo
    if ($exit -eq 0 -and $codigo -match '^(200|400|404|410)$') { return $ultimo }
    Start-Sleep -Seconds 2
  }
  return $ultimo
}

function N([double]$v) { return $v.ToString($inv) }
function Txt($v) {
  if ($null -eq $v) { return '' }
  return (("$v" -replace '[\r\n\t]+', ' ') -replace '\s{2,}', ' ').Trim()
}
function Num($v) {
  if ($null -eq $v -or "$v" -eq '') { return '' }
  try { return ([double]$v).ToString($inv) } catch { return '' }
}
function Inteiro($v) {
  if ($null -eq $v -or "$v" -eq '') { return '' }
  try { return ([int][math]::Round([double]$v)).ToString($inv) } catch { return '' }
}
function DataIso($s) {
  # "2026-06-13T09:03:24.000+0000" ou "...Z" -> data local yyyy-MM-dd
  if (-not $s) { return '' }
  $t = "$s" -replace '([+-]\d{2})(\d{2})$', '$1:$2'
  try { return ([datetimeoffset]::Parse($t, $inv)).ToLocalTime().ToString('yyyy-MM-dd') } catch { return '' }
}
function Pega($dic, [string]$chave) {
  # leitura segura de chave em Dictionary<string,object> (ContainsKey) / hashtable (Contains) / objeto
  if ($null -eq $dic) { return $null }
  if ($dic -is [System.Collections.Generic.Dictionary[string,object]]) { if ($dic.ContainsKey($chave)) { return $dic[$chave] } else { return $null } }
  if ($dic -is [System.Collections.IDictionary]) { if ($dic.Contains($chave)) { return $dic[$chave] } else { return $null } }
  if ($dic -is [string] -or $dic -is [System.Array] -or $dic -is [System.ValueType]) { return $null }
  try { return $dic.$chave } catch { return $null }
}
function ChavesSim($lista) {
  # amenities/installations do QuintoAndar: ou lista de strings, ou lista de {key,text,value:"SIM"/"NAO"}
  $saidaChaves = New-Object System.Collections.Generic.List[string]
  if ($null -eq $lista) { return $saidaChaves }
  foreach ($a in @($lista)) {
    if ($null -eq $a) { continue }
    if ($a -is [string]) { $saidaChaves.Add($a.ToUpperInvariant()); continue }
    $k = Pega $a 'key'; $v = Pega $a 'value'
    if ($k -and ($null -eq $v -or "$v" -eq 'SIM')) { $saidaChaves.Add("$k".ToUpperInvariant()) }
  }
  return $saidaChaves
}

# ---------------------------------------------------------------- corpo da busca
$centroLat = ([double]$vp.north + [double]$vp.south) / 2
$centroLng = ([double]$vp.east + [double]$vp.west) / 2
$tiposJson = ($tiposPermitidos | ForEach-Object { '"' + $_ + '"' }) -join ','
$camposJson = '"id","area","salePrice","iptu","totalCost","address","city","regionName","neighbourhood","type","bedrooms","bathrooms","suites","parkingSpaces","isPrimaryMarket","isFurnished","location","coverImage","imageList","amenities","installations","forSale","forRent","visitStatus","listingTags"'
function Corpo-Busca([int]$offset, [int]$tamanho, [string]$ordem) {
  $direcao = 'DESC'; if ($ordem -ne 'RELEVANCE') { $direcao = 'ASC' }
  return ('{"context":{"listShowing":true,"mapShowing":true,"numPhotos":12,"isSSR":false},' +
    '"filters":{"businessContext":"SALE","enableFlexibleSearch":false,' +
    '"location":{"coordinate":{"lat":' + (N $centroLat) + ',"lng":' + (N $centroLng) + '},' +
    '"viewport":{"east":' + (N $vp.east) + ',"north":' + (N $vp.north) + ',"south":' + (N $vp.south) + ',"west":' + (N $vp.west) + '},' +
    '"neighborhoods":[],"countryCode":"BR"},' +
    '"priceRange":[{"costType":"SALE_PRICE","range":{"min":' + $precoMin + ',"max":' + $precoMax + '}}],' +
    '"availability":"ANY","occupancy":"ANY","partnerIds":[],"specialConditions":[],"excludedSpecialConditions":[],"blocklist":[],"selectedHouses":[],"categories":[],' +
    '"houseSpecs":{"area":{"range":{"min":' + (N $areaMin) + ',"max":' + (N $areaMax) + '}},"houseTypes":[' + $tiposJson + '],"amenities":[],"installations":[],' +
    '"bathrooms":{"range":{}},"bedrooms":{"range":{}},"parkingSpace":{"range":{}},"suites":{"range":{}}},' +
    '"origin":"HYBRID"},' +
    '"sorting":{"criteria":"' + $ordem + '","order":"' + $direcao + '"},' +
    '"pagination":{"pageSize":' + $tamanho + ',"offset":' + $offset + '},' +
    '"fields":[' + $camposJson + '],' +
    '"slug":"ipanema-rio-de-janeiro-rj-brasil"}')
}
$cabecalhosApi = @('Accept: application/json', 'Content-Type: application/json', 'Origin: https://www.quintoandar.com.br', 'Referer: https://www.quintoandar.com.br/comprar/imovel/ipanema-rio-de-janeiro-rj-brasil/apartamento')
[System.IO.File]::WriteAllText((Join-Path $Saida 'corpo-busca-quintoandar.json'), (Corpo-Busca 0 $PageSize 'RELEVANCE'), $utf8semBom)

# ---------------------------------------------------------------- busca (paginada, com dedup)
$hitsPorId = [ordered]@{}
$centroidesBusca = New-Object System.Collections.Generic.List[object]
$totalApi = -1
$falhasBusca = 0
$chamadasBusca = 0

function Executa-Busca([string]$ordem, [string]$rotulo) {
  $offset = 0
  do {
    $corpo = Corpo-Busca $offset $PageSize $ordem
    $arqCorpo = Join-Path $pastaTmp "busca-$rotulo-$offset.json"
    [System.IO.File]::WriteAllText($arqCorpo, $corpo, $utf8semBom)
    $arqResp = Join-Path $pastaTmp "busca-$rotulo-$offset-resp.json"
    $r = Invoke-Curl -Url $urlBusca -Metodo POST -CorpoArquivo $arqCorpo -Cabecalhos $cabecalhosApi -ArqSaida $arqResp
    $script:chamadasBusca++
    if ($r.Codigo -ne '200') {
      Log ("ERRO busca {0} offset {1}: HTTP '{2}', exit curl {3}, {4} tentativas. Resposta: {5}" -f $rotulo, $offset, $r.Codigo, $r.Exit, $r.Tentativas, (Txt $r.Corpo).Substring(0, [Math]::Min(300, (Txt $r.Corpo).Length)))
      $script:falhasBusca++
      return
    }
    $resp = $js.DeserializeObject($r.Corpo)
    $hits = Pega $resp 'hits'
    $total = [int](Pega (Pega $hits 'total') 'value')
    if ($script:totalApi -lt 0 -or $rotulo -eq 'relevance') { $script:totalApi = $total }
    $lista = @(Pega $hits 'hits')
    $novos = 0
    foreach ($h in $lista) {
      $src = Pega $h 'src'
      if ($null -eq $src) { $src = Pega $h '_source' }
      if ($null -eq $src) { continue }
      $id = "$(Pega $src 'id')"
      if (-not $id) { continue }
      if (-not $hitsPorId.Contains($id)) {
        $tags = @()
        $campos = Pega $h 'fields'
        if ($campos) { $lt = Pega $campos 'listingTags'; if ($lt) { $tags = @($lt) } }
        $hitsPorId[$id] = @{ src = $src; tags = $tags }
        $novos++
      }
    }
    $li = Pega $resp 'locationInfo'
    if ($li) { foreach ($loc in @(Pega $li 'locations')) { $c = Pega $loc 'center'; if ($c) { $centroidesBusca.Add(@([double](Pega $c 'lat'), [double](Pega $c 'lng'))) } } }
    Log ("busca {0} offset {1}: HTTP 200, total {2}, hits {3}, novos {4}, acumulado {5}" -f $rotulo, $offset, $total, $lista.Count, $novos, $hitsPorId.Count)
    $offset += $PageSize
    if ($offset -lt $total) { Start-Sleep -Milliseconds 400 }
  } while ($offset -lt $total)
}

Executa-Busca 'RELEVANCE' 'relevance'
if ($falhasBusca -eq 0 -and $totalApi -gt 0 -and $hitsPorId.Count -lt $totalApi) {
  Log ("busca por relevância devolveu {0} ids distintos de {1}: segunda passada ordenada por TOTAL_COST para completar" -f $hitsPorId.Count, $totalApi)
  Start-Sleep -Milliseconds 400
  Executa-Busca 'TOTAL_COST' 'totalcost'
}
Log ("busca concluída: total API {0}, ids distintos {1}, chamadas {2}, falhas {3}" -f $totalApi, $hitsPorId.Count, $chamadasBusca, $falhasBusca)

# ---------------------------------------------------------------- reconferência local dos critérios
$idsValidos = New-Object System.Collections.Generic.List[string]
$foraCriterios = New-Object System.Collections.Generic.List[string]
foreach ($id in @($hitsPorId.Keys)) {
  $src = $hitsPorId[$id].src
  $preco = [double](Pega $src 'salePrice'); $area = [double](Pega $src 'area'); $tipo = "$(Pega $src 'type')"
  $ok = ($preco -ge $precoMin -and $preco -le $precoMax -and $area -ge $areaMin -and $area -le $areaMax -and ($tiposPermitidos -contains $tipo))
  if ($ok) { $idsValidos.Add($id) } else { $foraCriterios.Add("$id (preço $preco, área $area, tipo $tipo)") }
}
if ($foraCriterios.Count -gt 0) { Log ("{0} anúncio(s) da API fora dos critérios na reconferência local (excluídos): {1}" -f $foraCriterios.Count, ($foraCriterios -join '; ')) }
Log ("anúncios a processar: {0}" -f $idsValidos.Count)

# ---------------------------------------------------------------- páginas de anúncio + normalização
$colunas = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord','preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar','anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site','bruto_json')
$linhas = New-Object System.Collections.Generic.List[object]
$paginasOk = 0
$paginasSemDados = New-Object System.Collections.Generic.List[string]
$paginasFalha = New-Object System.Collections.Generic.List[string]
$paginasPuladas = 0
$comNumero = 0; $comCep = 0; $comCoordExata = 0
$capturadoEm = Get-Date -Format 'yyyy-MM-dd HH:mm'
$centroidesFixos = New-Object System.Collections.Generic.List[object]
$centroidesFixos.Add(@($centroLat, $centroLng))
foreach ($c in $centroidesBusca) { $centroidesFixos.Add($c) }

function EhCentroide([double]$lat, [double]$lng, $extras) {
  # centroide é usado tal e qual pelo site, então a comparação é quase exata (0,00002° ≈ 2 m);
  # tolerância maior marcava como "bairro" imóvel real que por acaso fica perto do centro do bairro
  foreach ($c in $centroidesFixos) { if ([math]::Abs($lat - $c[0]) -lt 0.00002 -and [math]::Abs($lng - $c[1]) -lt 0.00002) { return $true } }
  foreach ($c in @($extras)) { if ($c -and [math]::Abs($lat - $c[0]) -lt 0.00002 -and [math]::Abs($lng - $c[1]) -lt 0.00002) { return $true } }
  return $false
}

$indice = 0
foreach ($id in $idsValidos) {
  $indice++
  $src = $hitsPorId[$id].src
  $tagsBusca = @($hitsPorId[$id].tags)
  $hi = $null; $tituloHtml = ''
  $urlPagina = $modeloPagina -replace '\{id\}', $id
  $linkFinal = $urlPagina
  $abrir = (-not $SemPaginas) -and ($LimitePaginas -le 0 -or $indice -le $LimitePaginas)
  if ($abrir) {
    $arqHtml = Join-Path $pastaTmp "pagina-$id.html"
    # O site às vezes responde HTTP 200 com a página "Esse imóvel está indisponível" (houseInfo vazio) por
    # instabilidade do servidor, mesmo para anúncio no ar (visto em 11/10/2026). Por isso a leitura da página
    # é repetida até 3 vezes quando vier vazia ou sem __NEXT_DATA__; falha de rede já é tratada no Invoke-Curl.
    $rodada = 0; $semDados = $false; $semNext = $false; $r = $null
    do {
      $rodada++
      if ($rodada -gt 1) { Start-Sleep -Seconds 2 }
      $semDados = $false; $semNext = $false; $hi = $null
      $r = Invoke-Curl -Url $urlPagina -ArqSaida $arqHtml -SeguirRedirect
      if ($r.Codigo -eq '200' -and $r.Corpo) {
        $m = [regex]::Match($r.Corpo, '<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', 'Singleline')
        if ($m.Success) {
          $nd = $m.Groups[1].Value
          try {
            $o = $js.DeserializeObject($nd)
            $hi = Pega (Pega (Pega (Pega (Pega $o 'props') 'pageProps') 'initialState') 'house') 'houseInfo'
          } catch { $hi = $null; Log "aviso: JSON da página $id não decodificou: $($_.Exception.Message)" }
          if ($hi -and "$(Pega $hi 'id')" -ne '') {
            [System.IO.File]::WriteAllText((Join-Path $pastaJson "$id.json"), $nd, $utf8semBom)
            if ($r.UrlFinal) { $linkFinal = $r.UrlFinal }
            $mt = [regex]::Match($r.Corpo, '<title[^>]*>(.*?)</title>', 'Singleline')
            if ($mt.Success) { $tituloHtml = [System.Net.WebUtility]::HtmlDecode((Txt $mt.Groups[1].Value)) -replace '\s*[-|]\s*QuintoAndar\s*$', '' }
          } else { $hi = $null; $semDados = $true }
        } else { $semNext = $true }
      }
    } while (($semDados -or $semNext) -and $rodada -lt 3)
    if ($hi) {
      $paginasOk++
      if ($rodada -gt 1) { Log "página ${id}: ok na rodada $rodada (o site tinha respondido 'indisponível')" }
    } elseif ($semDados) {
      $paginasSemDados.Add($id)
      Log "página ${id}: HTTP 200 mas sem houseInfo em $rodada rodadas (site diz indisponível); linha mantida só com os dados da busca"
    } elseif ($semNext) {
      $paginasFalha.Add($id)
      Log "página ${id}: HTTP 200 sem __NEXT_DATA__ em $rodada rodadas (tamanho $($r.Corpo.Length)); linha mantida só com os dados da busca"
    } else {
      $paginasFalha.Add($id)
      Log ("página {0}: falhou (HTTP '{1}', exit curl {2}, {3} tentativas); linha mantida só com os dados da busca" -f $id, $r.Codigo, $r.Exit, $r.Tentativas)
    }
    if (Test-Path $arqHtml) { Remove-Item $arqHtml -Force }
    Start-Sleep -Milliseconds 500
  } else { $paginasPuladas++ }

  # ---- campos: página tem prioridade, busca é o fallback
  $endereco = $null; $condominio = $null; $listingSale = $null
  if ($hi) {
    $endereco = Pega $hi 'address'
    $condominio = Pega $hi 'condominium'
    foreach ($l in @(Pega $hi 'listings')) { if ("$(Pega $l 'businessContext')" -eq 'SALE') { $listingSale = $l } }
  }
  $rua = ''; if ($endereco) { $rua = Txt (Pega $endereco 'street') }; if (-not $rua) { $rua = Txt (Pega $src 'address') }
  $numero = ''; if ($condominio) { $numero = Txt (Pega $condominio 'number') }
  $cep = ''; if ($endereco) { $cep = Txt (Pega $endereco 'zipCode') }
  if ($cep -match '^\d{8}$') { $cep = $cep.Substring(0,5) + '-' + $cep.Substring(5) }
  $bairro = ''; if ($endereco) { $bairro = Txt (Pega $endereco 'neighborhood') }; if (-not $bairro) { $bairro = Txt (Pega $src 'neighbourhood') }; if (-not $bairro) { $bairro = Txt (Pega $src 'regionName') }

  $lat = $null; $lng = $null; $origemCoord = ''
  if ($endereco -and (Pega $endereco 'lat') -ne $null -and (Pega $endereco 'lng') -ne $null) { $lat = [double](Pega $endereco 'lat'); $lng = [double](Pega $endereco 'lng'); $origemCoord = 'pagina' }
  elseif ((Pega $src 'location') -ne $null) { $loc = Pega $src 'location'; if ((Pega $loc 'lat') -ne $null) { $lat = [double](Pega $loc 'lat'); $lng = [double](Pega $loc 'lon'); $origemCoord = 'busca' } }
  $centroidesExtras = @()
  if ($condominio) {
    foreach ($nomeBloco in @('region','city')) { $bloco = Pega $condominio $nomeBloco; $c = Pega $bloco 'center'; if ($c -and (Pega $c 'lat') -ne $null) { $centroidesExtras += ,@([double](Pega $c 'lat'), [double](Pega $c 'lng')) } }
  }
  $precisao = 'nenhuma'
  if ($lat -ne $null) { if (EhCentroide $lat $lng $centroidesExtras) { $precisao = 'bairro' } else { $precisao = 'exata' } }

  $preco = Inteiro (Pega $hi 'salePrice'); if (-not $preco) { $preco = Inteiro (Pega $src 'salePrice') }
  $areaUtil = Num (Pega $hi 'area'); if (-not $areaUtil) { $areaUtil = Num (Pega $src 'area') }
  $condo = ''; if ($hi) { $condo = Inteiro (Pega $hi 'condoPrice') }
  if ($condo -eq '0') { $condo = '' }   # no QuintoAndar, 0 = não informado
  $iptu = ''; if ($hi) { $iptu = Inteiro (Pega $hi 'iptu') }; if ($iptu -eq '') { $iptu = Inteiro (Pega $src 'iptu') }
  $iptuInformado = ''; if ($iptu -ne '') { $iptuInformado = "$iptu/mês" }   # o site informa IPTU mensal
  if ($iptu -eq '0') { $iptu = '' }   # 0 = não informado; fica em iptu_informado ("0/mês") para auditoria
  $quartos = Inteiro (Pega $hi 'bedrooms'); if ($quartos -eq '') { $quartos = Inteiro (Pega $src 'bedrooms') }
  $banheiros = Inteiro (Pega $hi 'bathrooms'); if ($banheiros -eq '') { $banheiros = Inteiro (Pega $src 'bathrooms') }
  $suites = Inteiro (Pega $hi 'suites'); if ($suites -eq '') { $suites = Inteiro (Pega $src 'suites') }
  $vagas = Inteiro (Pega $hi 'parkingSpaces'); if ($vagas -eq '') { $vagas = Inteiro (Pega $src 'parkingSpaces') }
  $andar = ''
  if ($hi) {
    $andarExato = Pega $hi 'floor'
    if ($andarExato -ne $null -and "$andarExato" -ne '') { $andar = "$andarExato" }
    else {
      $rf = Pega $hi 'rangeFloor'
      if ($rf -and (Pega $rf 'min') -ne $null -and (Pega $rf 'max') -ne $null) {
        $fmin = [int](Pega $rf 'min'); $fmax = [int](Pega $rf 'max')
        if ($fmin -eq $fmax) { $andar = "$fmin" } elseif ($fmax -gt 0) { $andar = "$fmin-$fmax" }   # o site só informa a faixa de andares
      }
    }
  }
  $tipoSite = "$(Pega $src 'type')"; if ($hi -and (Pega $hi 'type')) { $tipoSite = "$(Pega $hi 'type')" }
  $tipo = switch ($tipoSite) { 'Apartamento' { 'Apartamento' } 'StudioOuKitchenette' { 'Kitnet/Studio' } 'Casa' { 'Outro' } 'CasaCondominio' { 'Outro' } default { 'Outro' } }

  # destaques: chaves "SIM" da página (amenities, comodidades, instalações do prédio) + listas da busca + descrição
  $flags = New-Object System.Collections.Generic.HashSet[string]
  foreach ($k in (ChavesSim (Pega $src 'amenities'))) { [void]$flags.Add($k) }
  foreach ($k in (ChavesSim (Pega $src 'installations'))) { [void]$flags.Add($k) }
  foreach ($t in $tagsBusca) { [void]$flags.Add("TAG_$t".ToUpperInvariant()) }
  if ($hi) {
    foreach ($nomeLista in @('amenities','comfortCommodities','practicalityCommodities','installations')) { foreach ($k in (ChavesSim (Pega $hi $nomeLista))) { [void]$flags.Add($k) } }
    if ($condominio) { $feat = Pega $condominio 'features'; if ($feat) { foreach ($k in (ChavesSim (Pega $feat 'installations'))) { [void]$flags.Add($k) }; if ("$(Pega $feat 'doorman')" -eq 'NightAndDayShift') { [void]$flags.Add('PORTARIA_24H') } } }
    if ((Pega $hi 'isNewOrRenovated') -eq $true) { [void]$flags.Add('NOVOS_OU_REFORMADOS') }
    if ((Pega $hi 'acceptsPets') -eq $true) { [void]$flags.Add('PODE_TER_ANIMAIS_DE_ESTIMACAO') }
    if ((Pega $hi 'hasFurniture') -eq $true) { [void]$flags.Add('MOBILIADO') }
    if ((Pega $hi 'isNearSubway') -eq $true) { [void]$flags.Add('PERTO_DE_METRO_OU_TREM') }
  }
  if ((Pega $src 'isFurnished') -eq $true) { [void]$flags.Add('MOBILIADO') }
  if ($flags.Contains('APARTAMENTO_COBERTURA') -and $tipo -eq 'Apartamento') { $tipo = 'Cobertura' }
  $descricao = ''; if ($hi) { $descricao = Txt ([System.Net.WebUtility]::HtmlDecode("$(Pega $hi 'remarks')")) }   # o site guarda &#13; e afins na descrição
  $descMin = $descricao.ToLowerInvariant()
  $dest = New-Object System.Collections.Generic.List[string]
  if ($flags.Contains('VARANDA') -or $flags.Contains('VARANDA_GOURMET') -or $descMin -match '(?<!sem )varanda') { $dest.Add('varanda') }
  if ($flags.Contains('VISTA_MAR') -or $flags.Contains('VISTA_PARA_O_MAR') -or $descMin -match 'vista (para o |pro |do |de )?mar|vista-mar|vista mar') { $dest.Add('vista mar') }
  if ($flags.Contains('VISTA_LIVRE') -or $descMin -match 'vista livre') { $dest.Add('vista livre') }
  if ($flags.Contains('NOVOS_OU_REFORMADOS') -or $descMin -match 'reformad|reforma recente|reforma completa') { $dest.Add('reformado') }
  if ($flags.Contains('GARDEN') -or $descMin -match '\bgarden\b') { $dest.Add('garden') }
  if ($flags.Contains('ELEVADOR') -or $descMin -match 'elevador') { $dest.Add('elevador') }
  if ($flags.Contains('PORTARIA_24H') -or $descMin -match 'portaria 24|portaria vinte e quatro') { $dest.Add('portaria 24h') }
  if ($flags.Contains('PISCINA') -or $flags.Contains('PISCINA_PRIVATIVA') -or $descMin -match 'piscina') { $dest.Add('piscina') }
  if ($flags.Contains('ACADEMIA') -or $descMin -match 'academia') { $dest.Add('academia') }
  if ($flags.Contains('MOBILIADO') -or $descMin -match 'mobiliad') { $dest.Add('mobiliado') }
  if ($descMin -match 'andar alto' -or ($andar -match '^(\d+)' -and [int]$Matches[1] -ge 10)) { $dest.Add('andar alto') }   # faixa de andares começando no 10º ou acima
  if ($descMin -match 'quadra da praia|1ª quadra|primeira quadra|1a quadra') { $dest.Add('quadra da praia') }
  if ($descMin -match 'financiamento|financi[aá]vel|aceita financ') { $dest.Add('aceita financiamento') }
  if ($descMin -match 'permuta') { $dest.Add('aceita permuta') }
  if ($flags.Contains('SOL_DA_MANHA') -or $descMin -match 'sol da manh') { $dest.Add('sol da manhã') }
  if ($flags.Contains('RUA_SILENCIOSA') -or $descMin -match 'silencios') { $dest.Add('silencioso') }
  if ($descMin -match 'vaga (na |em )?escritura|vaga escriturada|escriturada') { $dest.Add('vaga na escritura') }
  if ($flags.Contains('QUARTO_DE_SERVICO') -or $descMin -match 'depend[eê]ncia') { $dest.Add('dependência') }
  if ($flags.Contains('CHURRASQUEIRA') -or $descMin -match 'churrasqueira') { $dest.Add('churrasqueira') }
  if ($flags.Contains('PODE_TER_ANIMAIS_DE_ESTIMACAO') -or $descMin -match 'aceita (pet|animais)|pet friendly') { $dest.Add('pet') }
  if ($flags.Contains('LAVABO') -or $descMin -match 'lavabo') { $dest.Add('lavabo') }

  $fotos = ''
  if ($hi -and (Pega $hi 'photos') -ne $null) { $fotos = "$(@(Pega $hi 'photos').Count)" }
  elseif ((Pega $src 'imageList') -ne $null) { $fotos = "$(@(Pega $src 'imageList').Count)" }

  $publicadoEm = ''; $atualizadoEm = ''
  if ($listingSale) { $publicadoEm = DataIso (Pega $listingSale 'firstPublicationDate'); $atualizadoEm = DataIso (Pega $listingSale 'lastPublicationDate') }
  if (-not $atualizadoEm -and $hi) { $atualizadoEm = DataIso (Pega $hi 'lastPublishedDate') }

  $titulo = $tituloHtml
  if (-not $titulo) {
    $qTxt = ''; if ($quartos -ne '') { $qTxt = ", $quartos quarto(s)" }
    $titulo = "$tipoSite${qTxt}, $areaUtil m², $rua - $bairro"
  }
  if ($titulo.Length -gt 200) { $titulo = $titulo.Substring(0, 200) }
  $resumo = $descricao; if ($resumo.Length -gt 300) { $resumo = $resumo.Substring(0, 300) }

  if ($numero) { $comNumero++ }
  if ($cep) { $comCep++ }
  if ($precisao -eq 'exata') { $comCoordExata++ }

  $linha = [ordered]@{
    chave = "QUINTOANDAR_$id"; fonte = 'QUINTOANDAR'; codigo = $id; link = $linkFinal; link_alt = ''
    tipo = $tipo; titulo = $titulo; rua = $rua; numero = $numero; cep = $cep; bairro_site = $bairro
    lat = $(if ($lat -ne $null) { N $lat } else { '' }); lon = $(if ($lng -ne $null) { N $lng } else { '' }); precisao_coord = $precisao
    preco = $preco; area_util = $areaUtil; area_total = ''; condominio_mes = $condo; iptu_mes = $iptu; iptu_informado = $iptuInformado
    quartos = $quartos; banheiros = $banheiros; suites = $suites; vagas = $vagas; andar = $andar
    anunciante = 'QuintoAndar'; tipo_anunciante = 'Plataforma'
    publicado_em = $publicadoEm; atualizado_em = $atualizadoEm; capturado_em = $capturadoEm
    fotos = $fotos; destaques = (($dest | Select-Object -Unique) -join ' | '); descricao_resumo = $resumo
    status_site = 'ATIVO'; bruto_json = ''
  }
  $linhas.Add([pscustomobject]$linha)
  if ($indice % 10 -eq 0) { Log ("progresso: {0}/{1} anúncios ({2} páginas ok, {3} falhas, {4} sem dados)" -f $indice, $idsValidos.Count, $paginasOk, $paginasFalha.Count, $paginasSemDados.Count) }
}

# ---------------------------------------------------------------- CSV (UTF-8 com BOM, ';', ponto decimal)
if ($linhas.Count -gt 0) {
  $linhas | Select-Object $colunas | Export-Csv -Path $csvPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
} else {
  [System.IO.File]::WriteAllText($csvPath, (($colunas | ForEach-Object { '"' + $_ + '"' }) -join ';') + "`r`n", $utf8bom)
}
$bytes = [System.IO.File]::ReadAllBytes($csvPath)
if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
  $conteudo = [System.IO.File]::ReadAllText($csvPath, [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllText($csvPath, $conteudo, $utf8bom)
}
# limpa temporários da busca (as respostas da API ficam para auditoria em _tmp apenas se houve falha)
if ($falhasBusca -eq 0 -and $paginasFalha.Count -eq 0) { Remove-Item $pastaTmp -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- resumo e código de saída
$relogio.Stop()
Log "== resumo =="
Log ("total informado pela API (hits.total.value): {0}" -f $totalApi)
Log ("ids distintos obtidos na busca: {0}; fora dos critérios localmente: {1}" -f $hitsPorId.Count, $foraCriterios.Count)
Log ("linhas gravadas em bruto-quintoandar.csv: {0}" -f $linhas.Count)
Log ("páginas de anúncio: ok {0}, falha {1}, sem dados {2}, puladas {3}" -f $paginasOk, $paginasFalha.Count, $paginasSemDados.Count, $paginasPuladas)
if ($paginasFalha.Count -gt 0) { Log ("ids com página falha: {0}" -f ($paginasFalha -join ', ')) }
if ($paginasSemDados.Count -gt 0) { Log ("ids com página sem dados: {0}" -f ($paginasSemDados -join ', ')) }
Log ("com número: {0}; com CEP: {1}; com coordenada exata: {2}" -f $comNumero, $comCep, $comCoordExata)
Log ("tempo total: {0:n1} s" -f $relogio.Elapsed.TotalSeconds)
Log ("CSV: {0}" -f $csvPath)

$incompleto = ($falhasBusca -gt 0) -or ($paginasFalha.Count -gt 0) -or ($totalApi -lt 0) -or ($hitsPorId.Count -lt $totalApi)
if ($incompleto) {
  Log "RESULTADO: INCOMPLETO (exit 2) — ver linhas de ERRO/falha acima"
  exit 2
}
Log "RESULTADO: COMPLETO (exit 0)"
exit 0
