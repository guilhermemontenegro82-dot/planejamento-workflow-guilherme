<#
.SINOPSE
  Coletor VivaReal / Zap Imóveis (glue-api do Grupo OLX) para a Busca por Imóveis - Compra.

.DESCRIÇÃO
  Lê criterios.json, consulta a glue-api para cada bairro de busca com os filtros de preço, área
  e tipo, pagina de 30 em 30 (fatiando por faixa de preço quando o totalCount passa do limite),
  deduplica por id, completa título/descrição/data de atualização/fotos em lotes de 30 ids,
  normaliza conforme Skills\CONTRATO-DADOS.md e grava:
    <Saida>\bruto-vivareal.csv          (colunas e ordem exatas do contrato)
    <Saida>\json\vivareal\*.json        (uma resposta por página / lote, para auditoria)
    <Saida>\coletar-vivareal.log        (contagens por bairro e fatia, tempos, erros)

  Códigos de saída: 0 = cobertura completa; 2 = alguma página ou lote falhou nas 3 tentativas
  (a lista do que faltou fica no log).

.PARÂMETROS
  -Saida       pasta de saída (padrão: <raiz do projeto>\_dados\<hoje>)
  -Criterios   caminho do criterios.json (padrão: <raiz>\Sites e critérios para Busca\criterios.json)
  -LimiteFatia totalCount a partir do qual a consulta é fatiada por faixa de preço (padrão 900)
  -SemFotos    não pede "medias" nos lotes de detalhe (coluna fotos fica vazia; resposta 5x menor)
  -Reprocessar não vai à internet: reaproveita os JSONs já salvos em <Saida>\json\vivareal e refaz só a normalização
  -DedupApi    volta ao modo antigo: busca com categoryPage=RESULT (a API deduplica anúncios "irmãos" do mesmo
               imóvel e devolve um representante, cujo id troca entre rodadas). PADRÃO (decisão do Guilherme em
               11/10/2026, "uma linha por anúncio, com marcação de possível duplicata"): SEM categoryPage, ids
               estáveis, todos os anúncios; o consolidador agrupa os irmãos por rua+nº (ou CEP) + área ±2 m² + preço ±2 %.

.EXEMPLO
  powershell.exe -ExecutionPolicy Bypass -File coletar-vivareal.ps1 -Saida "..\_trabalho\testes-vivareal"

.NOTAS TÉCNICAS (descobertas de 11/10/2026, ver _trabalho\DESCOBERTAS-TECNICAS.md)
  - HTTP só pelo curl.exe do Windows (o .NET é barrado pelo Cloudflare).
  - O filtro de tipo só vale com unitTypes + unitTypesV3 + unitSubTypes juntos; sem o
    unitSubTypes a API ignora o tipo e devolve salas/lojas misturadas.
  - categoryPage=RESULT é o que o site usa (filtra e deduplica), mas apaga title, description e
    updatedAt da resposta por bairro; esses campos vêm pela consulta por lote de ids (sem categoryPage).
    Sem categoryPage (modo padrão) o filtro de tipo/uso continua valendo (Leblon: 182 ids, todos
    APARTMENT/RESIDENTIAL, nenhum fora de preço/área) e o volume mais que dobra (irmãos incluídos).
  - "link" só vem quando "page" também está no includeFields - e "page" só funciona junto com
    categoryPage=RESULT (sem ele a API responde HTTP 500 "error processing page"). Por isso, no modo padrão,
    os links vêm num passo próprio: consulta por lote de ids com categoryPage=RESULT + page (devolve o link de
    TODOS os ids, irmãos inclusive), uma chamada com x-domain VivaReal e outra com x-domain Zap.
    ARMADILHA: a API guarda o "page" em cache pela URL e ignora o x-domain quando a URL se repete - as duas
    chamadas usam includeFields diferentes para não compartilhar o cache (o log avisa se algum slug sair
    no formato do outro portal; o que vale no link é o "-id-<id>/" do fim).
  - Na consulta por id com categoryPage=RESULT NÃO vem "medias": o lote de detalhe continua sem categoryPage.
  - pricingInfos.iptuPeriod pode ser MONTHLY: nesse caso yearlyIptu já é mensal. (Revisão de 11/10/2026: o
    rótulo é pouco confiável - ver comentário na normalização; a base do IPTU é decidida pelo valor, com
    iptu_limite_mensal do criterios.json, e o rótulo do site fica em iptu_informado.)
  - A API deixa passar anúncios fora da área pedida (40 de 2.901 com 29-34 m² ou 80 m²); a reconferência
    local de preço/área é obrigatória e descarta esses (listados no log).
  - Cobertura: cada faixa precisa alcançar 97 % do totalCount, senão é falha (exit 2). As bordas de preço
    são inclusivas (priceMin=priceMax=650000 devolve anúncios; 650001 devolve 0), então as faixas do
    criterios.json não se sobrepõem. Em 11/10 a soma dos totalCounts das fatias de Copacabana (2.610) passou do
    totalCount do bairro inteiro (2.506): a API deduplica diferente em faixas largas; o dedup por id resolve.
#>
[CmdletBinding()]
param(
  [string]$Saida = '',
  [string]$Criterios = '',
  [int]$LimiteFatia = 900,
  [switch]$SemFotos,
  [switch]$Reprocessar,
  [switch]$DedupApi
)
# -Reprocessar: não vai à internet; reaproveita os JSONs já salvos em <Saida>\json\vivareal (mesmos nomes de arquivo)
# e refaz só a normalização e o CSV. Se algum arquivo faltar, baixa só aquele.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

# ----------------------------------------------------------------------------------------------
# Caminhos
# ----------------------------------------------------------------------------------------------
$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent        # Skills\scripts -> Skills -> raiz
if ($Criterios -eq '') { $Criterios = Join-Path $raiz 'Sites e critérios para Busca\criterios.json' }
if ($Saida -eq '')     { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
$pastaJson = Join-Path $Saida 'json\vivareal'
New-Item -ItemType Directory -Force -Path $pastaJson | Out-Null
$script:LogPath = Join-Path $Saida 'coletar-vivareal.log'
if (Test-Path -LiteralPath $script:LogPath) { Remove-Item -LiteralPath $script:LogPath -Force }
$arquivoCsv = Join-Path $Saida 'bruto-vivareal.csv'

function Log([string]$Msg) {
  $linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Msg
  Write-Host $linha
  [System.IO.File]::AppendAllText($script:LogPath, $linha + "`r`n", [System.Text.Encoding]::UTF8)
}

Log '=== coletar-vivareal.ps1 ==='
Log ("Saida: {0}" -f $Saida)
Log ("Criterios: {0}" -f $Criterios)

# ----------------------------------------------------------------------------------------------
# Critérios
# ----------------------------------------------------------------------------------------------
$crit = Get-Content -LiteralPath $Criterios -Raw -Encoding UTF8 | ConvertFrom-Json
$cfg = $crit.sites.VIVAREAL
$api       = [string]$cfg.api
$xdomVR    = [string]$cfg.x_domain
$xdomZap   = 'www.zapimoveis.com.br'
$tamPag    = [int]$cfg.page_size
$offsetMax = [int]$cfg.offset_max
$faixas    = @($cfg.faixas_preco_fatiamento)
$precoMin  = [int]$crit.preco_min
$precoMax  = [int]$crit.preco_max
$areaMin   = [double]$crit.area_util_min
$areaMax   = [double]$crit.area_util_max
$cidade    = [string]$crit.cidade
$bairros   = @($crit.bairros_busca)
$script:UA = [string]$crit.user_agent
if ($tamPag -le 0 -or $tamPag -gt 30) { $tamPag = 30 }   # a API recusa size > 30

Log ("Criterios: preco R$ {0:N0}-{1:N0}, area {2}-{3} m2, bairros: {4}" -f $precoMin, $precoMax, $areaMin, $areaMax, ($bairros -join ', '))

# ----------------------------------------------------------------------------------------------
# JSON grande: JavaScriptSerializer (ConvertFrom-Json do PS 5.1 trava em ~2 MB)
# ----------------------------------------------------------------------------------------------
Add-Type -AssemblyName System.Web.Extensions
$script:Json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$script:Json.MaxJsonLength = [int]::MaxValue
$script:Json.RecursionLimit = 512

function Campo($Dic, [string]$Chave) {
  # Lê uma chave de um dicionário vindo do JavaScriptSerializer; $null se não existir.
  if ($null -eq $Dic) { return $null }
  if ($Dic -is [System.Collections.Generic.Dictionary[string,object]]) {
    # "return ,$x": o PowerShell desenrola arrays devolvidos por função (um array de 1 item viraria o item solto,
    # e um array vazio viraria $null); a vírgula embrulha o valor para ele chegar inteiro ao chamador.
    if ($Dic.ContainsKey($Chave)) { return ,$Dic[$Chave] }
  }
  return $null
}
function Primeiro($Valor) {
  # Primeiro elemento de um array (a API devolve bedrooms:[1], usableAreas:[38] etc.); $null se vazio.
  if ($null -eq $Valor) { return $null }
  if ($Valor -is [array]) { if ($Valor.Count -gt 0) { return ,$Valor[0] } ; return $null }
  return ,$Valor
}
function Num($Valor) {
  # Converte número ou string numérica (a consulta por id devolve "730000" como texto) em [double]; $null se não der.
  if ($null -eq $Valor) { return $null }
  if ($Valor -is [string]) {
    $s = $Valor.Trim(); if ($s -eq '') { return $null }
    $r = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$r)) { return $r }
    return $null
  }
  try { return [double]$Valor } catch { return $null }
}
function Str($Valor) { if ($null -eq $Valor) { return '' } ; return ([string]$Valor).Trim() }
function Converter-Data($Valor) {
  # ("Data" sozinho é palavra reservada do PowerShell.) ISO da API ("2026-10-02T17:34:27.306+00:00" ou "...Z") -> data local yyyy-MM-dd.
  $s = Str $Valor; if ($s -eq '') { return '' }
  $dto = [DateTimeOffset]::MinValue
  if ([DateTimeOffset]::TryParse($s, $inv, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) {
    return $dto.ToLocalTime().ToString('yyyy-MM-dd')
  }
  return ''
}
function NumStr($Valor, [int]$Decimais) {
  if ($null -eq $Valor) { return '' }
  if ($Decimais -le 0) { return ([string][int64][math]::Round([double]$Valor)) }
  return ([double]$Valor).ToString('0.' + ('#' * $Decimais), $inv)
}
function IntOuVazio($Valor) {
  # Inteiro explícito (0 = 0); vazio quando a API não informa (array vazio / null).
  $n = Num $Valor; if ($null -eq $n) { return '' } ; return ([string][int][math]::Round($n))
}
function Limpar-Texto([string]$Texto, [int]$Max) {
  # Tira HTML, decodifica entidades, remove quebras de linha e corta em $Max caracteres.
  if ([string]::IsNullOrEmpty($Texto)) { return '' }
  $t = $Texto -replace '<br\s*/?>', ' ' -replace '<[^>]+>', ' '
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  $t = $t -replace '[\r\n\t ]+', ' ' -replace '\s{2,}', ' '
  $t = $t.Trim()
  if ($Max -gt 0 -and $t.Length -gt $Max) { $t = $t.Substring(0, $Max).TrimEnd() }
  return $t
}
function Slug([string]$Texto) { return ($Texto -replace '[^A-Za-z0-9_-]', '_') }

# ----------------------------------------------------------------------------------------------
# HTTP: curl.exe do Windows, 3 tentativas, timeout 40 s, pausa de 2 s entre tentativas
# ----------------------------------------------------------------------------------------------
$script:Curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$script:Chamadas = 0
$script:Reaproveitados = 0
$script:BytesBaixados = [int64]0
function Pausa([int]$Ms) { if (-not $Reprocessar) { Start-Sleep -Milliseconds $Ms } }   # 0,4 s entre páginas; nada no modo offline
if ($Reprocessar) { Log ("MODO REPROCESSAMENTO: reaproveitando os JSONs de {0}; so baixa o que faltar" -f $pastaJson) }

function Baixar-Json {
  param([string]$Url, [string]$XDomain, [string]$Arquivo)
  $motivo = ''
  if ($Reprocessar -and (Test-Path -LiteralPath $Arquivo)) {
    # modo offline: reaproveita a resposta já gravada
    $txtCache = [System.IO.File]::ReadAllText($Arquivo, [System.Text.Encoding]::UTF8)
    $objCache = $null
    try { $objCache = $script:Json.DeserializeObject($txtCache) } catch { $objCache = $null }
    if ($null -ne $objCache -and ($objCache -is [System.Collections.Generic.Dictionary[string,object]]) -and $objCache.ContainsKey('search')) {
      $script:Reaproveitados++
      return @{ ok = $true; obj = $objCache; tentativas = 0 }
    }
    Log ("      arquivo em cache invalido, baixando de novo: {0}" -f (Split-Path $Arquivo -Leaf))
  }
  for ($tent = 1; $tent -le 3; $tent++) {
    $script:Chamadas++
    $codigo = ''
    try {
      $saidaCurl = & $script:Curl -s -m 40 -A $script:UA -H "x-domain: $XDomain" -H 'Accept: application/json' -o $Arquivo -w '%{http_code}' $Url
      $codigo = ([string]$saidaCurl).Trim()
    } catch { $codigo = 'EXC'; $motivo = 'excecao: ' + $_.Exception.Message }
    if ($codigo -eq '200' -and (Test-Path -LiteralPath $Arquivo)) {
      $txt = [System.IO.File]::ReadAllText($Arquivo, [System.Text.Encoding]::UTF8)
      $script:BytesBaixados += $txt.Length
      $obj = $null
      try { $obj = $script:Json.DeserializeObject($txt) } catch { $obj = $null }
      if ($null -ne $obj -and ($obj -is [System.Collections.Generic.Dictionary[string,object]]) -and $obj.ContainsKey('search')) {
        return @{ ok = $true; obj = $obj; tentativas = $tent }
      }
      if ($null -ne $obj -and ($obj -is [System.Collections.Generic.Dictionary[string,object]]) -and $obj.ContainsKey('err')) {
        $e = ([string]$obj['err']) -replace '\s+', ' '
        if ($e.Length -gt 160) { $e = $e.Substring(0, 160) }
        $motivo = 'erro da API: ' + $e
      } else { $motivo = 'resposta 200 sem JSON valido' }
    } elseif ($codigo -ne 'EXC') {
      $motivo = 'HTTP ' + $codigo + ' (curl exit ' + $LASTEXITCODE + ')'
    }
    Log ("      tentativa {0}/3 falhou: {1}" -f $tent, $motivo)
    if ($tent -lt 3) { Start-Sleep -Seconds 2 }
  }
  return @{ ok = $false; motivo = $motivo }
}

function Extrair-Listings($Obj) {
  # Emite os anúncios no pipeline (sem vírgula aqui!): o chamador SEMPRE fecha com @(...), que recolhe 30, 1 ou 0
  # anúncios como array. Com ",@(...)" o array sairia como um único objeto e o @() do chamador o embrulharia de novo.
  $lista = Campo (Campo (Campo $Obj 'search') 'result') 'listings'
  if ($lista -is [array]) { return @($lista) }
  return @()
}

# ----------------------------------------------------------------------------------------------
# Consulta
# ----------------------------------------------------------------------------------------------
# unitTypes/unitTypesV3/unitSubTypes precisam vir juntos para o filtro de tipo valer (testado 11/10/2026).
# KITNET é aceito na lista, mas devolve 0 nos três bairros: kitnets/studios aparecem como APARTMENT.
$tiposApi = 'APARTMENT,KITNET'
# categoryPage=RESULT só no modo -DedupApi (ver cabeçalho). No padrão a busca vem sem ele: todos os anúncios, ids estáveis.
$catPage = ''; if ($DedupApi) { $catPage = 'categoryPage=RESULT&' }
$script:QueryBase = ('addressState={0}&addressCity={1}&addressZone={2}&addressType=neighborhood&business=SALE&{6}listingType=USED&usableAreasMin={3}&usableAreasMax={4}&unitTypes={5}&unitTypesV3={5}&unitSubTypes=UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX&usageTypes=RESIDENTIAL&sort=createdAt%20ASC' -f `
  [Uri]::EscapeDataString('Rio de Janeiro'), [Uri]::EscapeDataString($cidade), [Uri]::EscapeDataString('Zona Sul'), `
  $areaMin.ToString($inv), $areaMax.ToString($inv), $tiposApi, $catPage)
Log ("Modo: {0}" -f $(if ($DedupApi) { '-DedupApi (categoryPage=RESULT: a API deduplica os irmaos; link vem da pagina)' } else { 'padrao sem categoryPage (uma linha por anuncio, ids estaveis; links por lote de ids)' }))

# Campos da busca (title/description/updatedAt não vêm com categoryPage=RESULT: ficam para o lote de detalhe).
$camposA = 'id,address,pricingInfos,usableAreas,totalAreas,bedrooms,bathrooms,suites,parkingSpaces,unitFloor,createdAt,status,publicationType,amenities,unitTypes,displayAddressType'
if ($DedupApi) { $script:IncludeA = 'search(result(listings(listing(' + $camposA + '),account(name,licenseNumber),link)),totalCount),page' }
else { $script:IncludeA = 'search(result(listings(listing(' + $camposA + '),account(name,licenseNumber))),totalCount)' }   # sem categoryPage, "page" dá 500 e "link" não vem
$script:IncludeB = 'search(result(listings(listing(id),link)),totalCount),page'
# Links por lote de ids (modo padrão): includeFields DIFERENTES entre VivaReal e Zap (cache do "page" por URL, ver cabeçalho).
$script:IncludeL1 = 'search(result(listings(listing(id,status),link)),totalCount),page'
$script:IncludeL2 = 'search(result(listings(listing(id),link)),totalCount),page'
$script:IncludeC = 'search(result(listings(listing(id,title,description,updatedAt,createdAt,status,pricingInfos,unitSubTypes,acceptExchange,contractType)' + $(if ($SemFotos) { '' } else { ',medias' }) + ')),totalCount)'

function Montar-Url([string]$Bairro, [int]$PMin, [int]$PMax, [int]$From, [int]$Size, [string]$Include) {
  return ('{0}?{1}&addressNeighborhood={2}&priceMin={3}&priceMax={4}&from={5}&size={6}&includeFields={7}' -f `
    $api, $script:QueryBase, [Uri]::EscapeDataString($Bairro), $PMin, $PMax, $From, $Size, $Include)
}

$script:Anuncios = @{}        # id -> @{ item; arquivo; bairroBusca }
$script:LinksVR  = @{}        # id -> href relativo no VivaReal (da página no modo -DedupApi; do lote de links no padrão)
$script:LinksZap = @{}        # id -> href relativo no Zap
$script:Detalhes = @{}        # id -> item do lote de detalhe (listing + medias)
$script:Falhas   = New-Object System.Collections.Generic.List[string]
$script:Resumo   = New-Object System.Collections.Generic.List[object]

function Obter-Total([string]$Bairro, [int]$PMin, [int]$PMax) {
  $url = Montar-Url $Bairro $PMin $PMax 0 1 'search(result(listings(listing(id))),totalCount)'
  $arq = Join-Path $pastaJson ('total_{0}_{1}-{2}.json' -f (Slug $Bairro), $PMin, $PMax)
  $r = Baixar-Json -Url $url -XDomain $xdomVR -Arquivo $arq
  if (-not $r.ok) { return -1 }
  $tc = Num (Campo (Campo $r.obj 'search') 'totalCount')
  if ($null -eq $tc) { return -1 }
  return [int]$tc
}

function Coletar-Fatia([string]$Bairro, [int]$PMin, [int]$PMax, [int]$Nivel) {
  $tc = Obter-Total $Bairro $PMin $PMax
  Pausa 400
  if ($tc -lt 0) {
    Log ("  [{0}] faixa R$ {1:N0}-{2:N0}: nao foi possivel obter o totalCount" -f $Bairro, $PMin, $PMax)
    $script:Falhas.Add(('totalCount {0} {1}-{2}' -f $Bairro, $PMin, $PMax))
    return
  }
  Log ("  [{0}] faixa R$ {1:N0}-{2:N0}: totalCount {3}" -f $Bairro, $PMin, $PMax, $tc)
  if ($tc -eq 0) {
    $script:Resumo.Add([pscustomobject]@{ bairro = $Bairro; pmin = $PMin; pmax = $PMax; totalCount = 0; obtidos = 0; novos = 0; paginas = 0 })
    return
  }
  if ($tc -gt $LimiteFatia) {
    if ($Nivel -eq 0 -and $faixas.Count -gt 1) {
      Log ("    acima de {0}: fatiando pelas {1} faixas de preco do criterios.json" -f $LimiteFatia, $faixas.Count)
      foreach ($fx in $faixas) { Coletar-Fatia $Bairro ([int]$fx[0]) ([int]$fx[1]) ($Nivel + 1) }
      return
    }
    if (($PMax - $PMin) -ge 2) {
      $meio = [int][math]::Floor(($PMin + $PMax) / 2)
      Log ("    acima de {0}: dividindo ao meio em {1}-{2} e {3}-{4}" -f $LimiteFatia, $PMin, $meio, ($meio + 1), $PMax)
      Coletar-Fatia $Bairro $PMin $meio ($Nivel + 1)
      Coletar-Fatia $Bairro ($meio + 1) $PMax ($Nivel + 1)
      return
    }
    Log ("    AVISO: faixa indivisivel com {0} anuncios; so da para paginar ate o offset {1}" -f $tc, $offsetMax)
    $script:Falhas.Add(('fatia indivisivel {0} {1}-{2} ({3} anuncios, offset max {4})' -f $Bairro, $PMin, $PMax, $tc, $offsetMax))
  }

  $obtidos = 0; $novos = 0; $from = 0; $pag = 0
  while ($from -lt $tc -and $from -lt $offsetMax) {
    $pag++
    $nome = '{0}_{1}-{2}_p{3:00}' -f (Slug $Bairro), $PMin, $PMax, $pag
    # --- chamada A: dados do anúncio + link VivaReal ---
    $arqA = Join-Path $pastaJson ($nome + '.json')
    $rA = Baixar-Json -Url (Montar-Url $Bairro $PMin $PMax $from $tamPag $script:IncludeA) -XDomain $xdomVR -Arquivo $arqA
    if (-not $rA.ok) {
      Log ("    pagina {0} (from={1}) FALHOU: {2}" -f $pag, $from, $rA.motivo)
      $script:Falhas.Add(('pagina {0} ({1})' -f $nome, $rA.motivo))
      $from += $tamPag; Pausa 400; continue
    }
    $lista = @(Extrair-Listings $rA.obj)
    if ($lista.Count -eq 0) {
      # A API devolveu página vazia antes de alcançar o totalCount: encerra a faixa; a checagem de cobertura
      # logo abaixo decide se isso vira falha (exit 2) ou só drift pequeno do site.
      Log ("    AVISO: pagina {0} (from={1}) veio vazia antes do totalCount {2}; encerrando a faixa" -f $pag, $from, $tc)
      break
    }
    foreach ($item in $lista) {
      $id = Str (Campo (Campo $item 'listing') 'id')
      if ($id -eq '') { continue }
      $obtidos++
      if (-not $script:Anuncios.ContainsKey($id)) {
        $script:Anuncios[$id] = @{ item = $item; arquivo = ($nome + '.json'); bairroBusca = $Bairro }
        $novos++
      }
      if ($DedupApi) { $hrefA = Str (Campo (Campo $item 'link') 'href'); if ($hrefA -ne '') { $script:LinksVR[$id] = $hrefA } }
    }
    Pausa 400
    if ($DedupApi) {
      # --- chamada B (só no modo -DedupApi): mesma página com x-domain do Zap, só para o href ---
      $arqB = Join-Path $pastaJson ($nome + '_zap.json')
      $rB = Baixar-Json -Url (Montar-Url $Bairro $PMin $PMax $from $tamPag $script:IncludeB) -XDomain $xdomZap -Arquivo $arqB
      if ($rB.ok) {
        foreach ($item in @(Extrair-Listings $rB.obj)) {
          $id = Str (Campo (Campo $item 'listing') 'id')
          $href = Str (Campo (Campo $item 'link') 'href')
          if ($id -ne '' -and $href -ne '') { $script:LinksZap[$id] = $href }
        }
      } else {
        Log ("    pagina {0} (zap, from={1}) FALHOU: {2}" -f $pag, $from, $rB.motivo)
        $script:Falhas.Add(('pagina {0} zap ({1})' -f $nome, $rB.motivo))
      }
      Pausa 400
    }
    $from += $tamPag
  }
  Log ("    obtidos {0} ({1} novos) de totalCount {2} em {3} pagina(s)" -f $obtidos, $novos, $tc, $pag)
  # Cobertura nunca fica truncada em silêncio: abaixo de 97 % do totalCount da faixa é falha (exit 2).
  # (O totalCount pode oscilar um pouco durante a coleta - anúncio novo ou retirado - por isso a folga de 3 %.)
  $minimoAceitavel = [int][math]::Ceiling($tc * 0.97)
  if ($obtidos -lt $minimoAceitavel) {
    Log ("    AVISO: cobertura parcial nesta faixa: obtidos {0} de {1} (minimo aceitavel {2} = 97%)" -f $obtidos, $tc, $minimoAceitavel)
    $script:Falhas.Add(('cobertura parcial {0} {1}-{2}: obtidos {3} de totalCount {4}' -f $Bairro, $PMin, $PMax, $obtidos, $tc))
  }
  $script:Resumo.Add([pscustomobject]@{ bairro = $Bairro; pmin = $PMin; pmax = $PMax; totalCount = $tc; obtidos = $obtidos; novos = $novos; paginas = $pag })
}

# ----------------------------------------------------------------------------------------------
# 1) Busca por bairro
# ----------------------------------------------------------------------------------------------
Log '--- 1) Busca por bairro ---'
$totalPorBairro = @{}
foreach ($bairro in $bairros) {
  $antes = $script:Anuncios.Count
  Coletar-Fatia $bairro $precoMin $precoMax 0
  $totalPorBairro[$bairro] = $script:Anuncios.Count - $antes
  Log ("  [{0}] anuncios unicos acumulados nesta busca: {1}" -f $bairro, $totalPorBairro[$bairro])
}
Log ("Busca concluida: {0} anuncios unicos, {1} links Zap, {2:N1} s" -f $script:Anuncios.Count, $script:LinksZap.Count, $relogio.Elapsed.TotalSeconds)

# ----------------------------------------------------------------------------------------------
# 2) Detalhe em lotes de 30 ids (title, description, updatedAt, iptuPeriod, contractType, medias)
# ----------------------------------------------------------------------------------------------
Log '--- 2) Detalhe por lote de ids ---'
$ids = @($script:Anuncios.Keys | Sort-Object)
$nLote = 0
for ($i = 0; $i -lt $ids.Count; $i += 30) {
  $fim = [math]::Min($i + 29, $ids.Count - 1)
  $lote = @($ids[$i..$fim])
  $nLote++
  $arqC = Join-Path $pastaJson ('detalhe_{0:000}.json' -f $nLote)
  $urlC = '{0}?id={1}&size={2}&includeFields={3}' -f $api, ($lote -join ','), $lote.Count, $script:IncludeC
  $rC = Baixar-Json -Url $urlC -XDomain $xdomVR -Arquivo $arqC
  if ($rC.ok) {
    $recebidos = 0
    foreach ($item in @(Extrair-Listings $rC.obj)) {
      $id = Str (Campo (Campo $item 'listing') 'id')
      if ($id -ne '') { $script:Detalhes[$id] = $item; $recebidos++ }
    }
    if ($recebidos -lt $lote.Count) { Log ("    lote {0}: pediu {1} ids, recebeu {2}" -f $nLote, $lote.Count, $recebidos) }
  } else {
    Log ("    lote {0} FALHOU: {1}" -f $nLote, $rC.motivo)
    $script:Falhas.Add(('detalhe lote {0} ({1} ids: {2})' -f $nLote, $lote.Count, $rC.motivo))
  }
  Pausa 400
}
Log ("Detalhe concluido: {0} lotes, {1} anuncios com detalhe, {2:N1} s" -f $nLote, $script:Detalhes.Count, $relogio.Elapsed.TotalSeconds)

# ----------------------------------------------------------------------------------------------
# 2b) Links por lote de ids (modo padrão): categoryPage=RESULT + page devolvem o link de todos os ids,
#     irmãos inclusive; uma chamada com x-domain VivaReal (link) e outra com x-domain Zap (link_alt).
# ----------------------------------------------------------------------------------------------
function Baixar-LinksLote([string[]]$Lote, [int]$Numero, [string]$XDomain, [string]$Include, [string]$Sufixo, [string]$Rotulo, $Tabela) {
  $arq = Join-Path $pastaJson ('link_{0:000}{1}.json' -f $Numero, $Sufixo)
  $url = '{0}?id={1}&size={2}&categoryPage=RESULT&includeFields={3}' -f $api, ($Lote -join ','), $Lote.Count, $Include
  $r = Baixar-Json -Url $url -XDomain $XDomain -Arquivo $arq
  if (-not $r.ok) {
    Log ("    lote de links {0} ({1}) FALHOU: {2}" -f $Numero, $Rotulo, $r.motivo)
    $script:Falhas.Add(('links lote {0} {1} ({2} ids: {3})' -f $Numero, $Rotulo, $Lote.Count, $r.motivo))
    return
  }
  $recebidos = 0
  foreach ($item in @(Extrair-Listings $r.obj)) {
    $id = Str (Campo (Campo $item 'listing') 'id'); $href = Str (Campo (Campo $item 'link') 'href')
    if ($id -ne '' -and $href -ne '') { $Tabela[$id] = $href; $recebidos++ }   # $Tabela é a hashtable do script (passada por referência)
  }
  if ($recebidos -lt $Lote.Count) { Log ("    lote de links {0} ({1}): pediu {2} ids, recebeu {3} links" -f $Numero, $Rotulo, $Lote.Count, $recebidos) }
}
if (-not $DedupApi) {
  Log '--- 2b) Links por lote de ids (VivaReal e Zap) ---'
  $nLoteL = 0
  for ($i = 0; $i -lt $ids.Count; $i += 30) {
    $fim = [math]::Min($i + 29, $ids.Count - 1)
    $lote = @($ids[$i..$fim])
    $nLoteL++
    Baixar-LinksLote $lote $nLoteL $xdomVR  $script:IncludeL1 ''     'vivareal' $script:LinksVR
    Pausa 400
    Baixar-LinksLote $lote $nLoteL $xdomZap $script:IncludeL2 '_zap' 'zap'      $script:LinksZap
    Pausa 400
  }
  # Sanidade do slug: VivaReal usa ".../<tipo>-...-venda-RS<preco>-id-<id>/", Zap usa "/imovel/venda-...-id-<id>/".
  $vrComoZap = @($script:LinksVR.Values  | Where-Object { $_ -match '^/imovel/venda-' }).Count
  $zapComoVr = @($script:LinksZap.Values | Where-Object { $_ -match '-venda-RS\d+-id-' }).Count
  Log ("Links concluidos: {0} lotes, {1} links VivaReal, {2} links Zap, {3:N1} s" -f $nLoteL, $script:LinksVR.Count, $script:LinksZap.Count, $relogio.Elapsed.TotalSeconds)
  if ($vrComoZap -gt 0 -or $zapComoVr -gt 0) { Log ("  AVISO: {0} hrefs VivaReal com slug no formato do Zap e {1} hrefs Zap com slug no formato do VivaReal (cache do 'page' na API; o '-id-<id>/' do fim e o que vale)" -f $vrComoZap, $zapComoVr) }
}

# ----------------------------------------------------------------------------------------------
# 3) Normalização (CONTRATO-DADOS.md)
# ----------------------------------------------------------------------------------------------
Log '--- 3) Normalizacao ---'
$colunas = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord',
  'preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar',
  'anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site','bruto_json')

# amenities da API -> destaque do contrato
$mapaAmenities = @{
  'BALCONY' = 'varanda'; 'TERRACE' = 'varanda';
  'SEA_VIEW' = 'vista mar'; 'OCEAN_VIEW' = 'vista mar'; 'BEACH_VIEW' = 'vista mar';
  'PANORAMIC_VIEW' = 'vista livre';
  'GARDEN' = 'garden'; 'PRIVATE_GARDEN' = 'garden';
  'ELEVATOR' = 'elevador';
  'CONCIERGE_24H' = 'portaria 24h';
  'POOL' = 'piscina'; 'HEATED_POOL' = 'piscina'; 'ADULT_POOL' = 'piscina'; 'INDOOR_POOL' = 'piscina';
  'GYM' = 'academia'; 'FITNESS' = 'academia';
  'FURNISHED' = 'mobiliado'; 'SEMI_FURNISHED' = 'mobiliado';
  'BARBECUE_GRILL' = 'churrasqueira'; 'BARBECUE' = 'churrasqueira';
  'PETS_ALLOWED' = 'pet';
  'MAIDS_QUARTERS' = 'dependência'; 'MAID_ROOM' = 'dependência'; 'SERVICE_ROOM' = 'dependência'; 'EMPLOYEE_DEPENDENCY' = 'dependência';
  'HALF_BATH' = 'lavabo'; 'LAVATORY' = 'lavabo'; 'LAVABO' = 'lavabo'
}
# regex (sem distinguir maiúsculas; acentos opcionais) no título + descrição -> destaque; na ordem do contrato
$regexDestaques = [ordered]@{
  'varanda'              = 'varanda|sacada|terra[çc]o'
  'vista mar'            = 'vista (para o |pro |pra o |do |de |ao )?mar\b|vista[- ]mar|frente (para o |pro |ao )?mar\b|mar [àa] vista|vis[ãa]o (do |de |para o )?mar\b'
  'vista livre'          = 'vista livre|vista desimpedida|vista panor[âa]mica|vista aberta|vista ampla'
  'reformado'            = 'reformad|renovad|moderniz|retrofit'
  'garden'               = '\bgarden\b'
  'elevador'             = 'elevador'
  'portaria 24h'         = 'portaria 24|porteiro 24|portaria vinte e quatro|seguran[çc]a 24|\b24 ?h(oras|rs)?\b'
  'piscina'              = 'piscina'
  'academia'             = 'academia|fitness'
  'mobiliado'            = 'mobiliad'
  'andar alto'           = 'andar alto|alto andar|andares altos|[úu]ltimo andar'
  'quadra da praia'      = 'quadra da praia|primeira quadra|1[ªa°º] quadra|(uma|1) quadra (da|para a|pra) praia'
  'aceita financiamento' = '(aceita|aceitamos|aceita-se|possibilidade de|pode ser|estuda|sujeito a) financi|financi[áa]vel|financiamento banc[áa]rio|\bfgts\b'
  'aceita permuta'       = 'permuta'
  'sol da manhã'         = 'sol da manh[ãa]|\bnascente\b'
  'silencioso'           = 'silencios|sil[êe]ncio|rua (calma|tranquila)'
  'vaga na escritura'    = 'vaga (na |em )?escritura|vaga escriturada|escriturada'
  'dependência'          = 'depend[êe]ncia|quarto de empregada|quarto de servi[çc]o|dep\.? ?(completa|de empregada|revers[íi]vel)'
  'churrasqueira'        = 'churrasqueira'
  'pet'                  = 'aceita pet|pet ?friendly|aceita animais|animais de estima[çc][ãa]o'
  'lavabo'               = 'lavabo'
}
$ordemDestaques = @($regexDestaques.Keys)

function Pricing-Sale($Pricings) {
  # pricingInfos é array; pega o item de venda (businessType SALE), senão o primeiro.
  if ($Pricings -is [array]) {
    foreach ($p in $Pricings) { if ((Str (Campo $p 'businessType')) -eq 'SALE') { return $p } }
    if ($Pricings.Count -gt 0) { return $Pricings[0] }
  }
  return $null
}
function Formatar-Cep([string]$Cep) {
  $d = $Cep -replace '\D', ''
  if ($d.Length -eq 8) { return $d.Substring(0, 5) + '-' + $d.Substring(5) }
  return ''
}
function Classificar-Tipo([string]$UnitType, $SubTipos, [string]$Titulo) {
  $tipo = switch ($UnitType) {
    'APARTMENT' { 'Apartamento' }
    'KITNET'    { 'Kitnet/Studio' }
    'PENTHOUSE' { 'Cobertura' }
    'FLAT'      { 'Flat' }
    default     { if ($UnitType -eq '') { 'Apartamento' } else { 'Outro' } }
  }
  if ($tipo -eq 'Apartamento') {
    $subs = @(); if ($SubTipos -is [array]) { $subs = @($SubTipos | ForEach-Object { Str $_ }) }
    if (($subs -contains 'STUDIO') -or ($subs -contains 'KITNET') -or ($Titulo -match '(?i)\b(kitnet|kitinete|quitinete|conjugad[oa]|st[uú]dio)\b')) { $tipo = 'Kitnet/Studio' }
    elseif ($Titulo -match '(?i)\bcobertura\b') { $tipo = 'Cobertura' }
  }
  return $tipo
}
function Classificar-Anunciante([string]$ContractType, [string]$Creci, [string]$Nome) {
  # contractType do anúncio (OWNER / REAL_ESTATE) é o sinal mais direto; CRECI e nome são apoio.
  if ($ContractType -eq 'OWNER') { return 'Particular' }
  if ($ContractType -match 'DEVELOPER|CONSTRUCTION|BUILDER|INCORPORA') { return 'Construtora' }
  if ($Creci -ne '') { return 'Imobiliária' }
  if ($ContractType -eq 'REAL_ESTATE') { return 'Imobiliária' }
  if ($Nome -match '(?i)im[óo]ve|imobili|consultoria|ltda|neg[óo]cio|corretor|realty|broker|propert|invest|empreend|incorp|administra|\bs\.?a\.?\b|\bme\b|eireli') { return 'Imobiliária' }
  if ($Nome -match '^(?i)[a-záéíóúâêôãõç\.]+( [a-záéíóúâêôãõç\.]+){1,5}$' -and $Nome -notmatch '\d') { return 'Particular' }
  return ''
}

$agora = Get-Date -Format 'yyyy-MM-dd HH:mm'
$linhas = New-Object System.Collections.Generic.List[object]
$descartes = New-Object System.Collections.Generic.List[string]
$contPrec = @{ exata = 0; aproximada = 0; nenhuma = 0 }
$semNumero = 0; $semRua = 0; $semLink = 0; $semLinkAlt = 0; $semDetalhe = 0; $semAtualizado = 0
$contTipo = @{}; $contAnunciante = @{}; $contIptu = @{ vazio = 0 }
$iptuLimiteMensal = 700.0
if ($null -ne $cfg.iptu_limite_mensal) { $iptuLimiteMensal = [double]$cfg.iptu_limite_mensal }

foreach ($id in $ids) {
  $reg = $script:Anuncios[$id]
  $item = $reg.item
  $listing = Campo $item 'listing'
  $account = Campo $item 'account'
  $det = $null; if ($script:Detalhes.ContainsKey($id)) { $det = $script:Detalhes[$id] } else { $semDetalhe++ }
  $detL = Campo $det 'listing'

  # endereço
  $addr = Campo $listing 'address'
  $rua = Str (Campo $addr 'street'); $numero = Str (Campo $addr 'streetNumber')
  $cep = Formatar-Cep (Str (Campo $addr 'zipCode')); $bairroSite = Str (Campo $addr 'neighborhood')
  $lat = ''; $lon = ''; $prec = 'nenhuma'
  $point = Campo $addr 'point'
  if ($null -ne $point) {
    $la = Num (Campo $point 'lat'); $lo = Num (Campo $point 'lon')
    if ($null -ne $la -and $null -ne $lo) { $prec = 'exata' }
    else {
      $la = Num (Campo $point 'approximateLat'); $lo = Num (Campo $point 'approximateLon')
      if ($null -ne $la -and $null -ne $lo) { $prec = 'aproximada' }
    }
    if ($prec -ne 'nenhuma') { $lat = NumStr $la 6; $lon = NumStr $lo 6 }
  }

  # preço, condomínio, IPTU
  $pi = Pricing-Sale (Campo $listing 'pricingInfos')
  $preco = Num (Campo $pi 'price')
  $condo = Num (Campo $pi 'monthlyCondoFee'); if ($null -ne $condo -and $condo -le 0) { $condo = $null }
  $piDet = Pricing-Sale (Campo $detL 'pricingInfos'); if ($null -eq $piDet) { $piDet = $pi }
  $periodo = (Str (Campo $piDet 'iptuPeriod')).ToUpperInvariant()
  # yearlyIptu e iptu trazem o MESMO valor cru digitado pelo anunciante (conferido em 2.901 anúncios em 11/10/2026);
  # a base vem só do rótulo iptuPeriod (MONTHLY / YEARLY / Period_NONE), e o rótulo é pouco confiável: 394 de 1.189
  # "YEARLY" tinham valor <= 300 (cota mensal típica) e 33 de 1.558 "MONTHLY" tinham valor > 700 (típico de anual).
  # Regra adotada (igual à do Chaves na Mão): valor <= iptu_limite_mensal (criterios.json, 700) = cota mensal,
  # acima = anual (÷12). O rótulo do site fica registrado em iptu_informado. Com iptu_limite_mensal = 0 volta a
  # valer só o rótulo (MONTHLY = mensal; YEARLY e sem período = anual).
  $iptuAnual = Num (Campo $piDet 'yearlyIptu'); $iptuCampo = Num (Campo $piDet 'iptu')
  $iptuMes = ''; $iptuInf = ''
  $v = $iptuCampo; if ($null -eq $v) { $v = $iptuAnual }
  if ($null -ne $v -and $v -gt 0) {
    $vStr = NumStr $v 0
    $rotulo = switch ($periodo) { 'MONTHLY' { 'mensal' } 'YEARLY' { 'anual' } default { 'sem' } }
    if ($iptuLimiteMensal -gt 0) { $baseFinal = $(if ($v -le $iptuLimiteMensal) { 'mensal' } else { 'anual' }) }
    else { $baseFinal = $(if ($rotulo -eq 'mensal') { 'mensal' } else { 'anual' }) }
    if ($baseFinal -eq 'mensal') { $iptuMes = $vStr } else { $iptuMes = NumStr ($v / 12) 0 }
    if ($rotulo -eq $baseFinal) { $iptuInf = $vStr + $(if ($baseFinal -eq 'mensal') { '/mês' } else { '/ano' }); $contIptu[$baseFinal + ' (rótulo do site)']++ }
    elseif ($rotulo -eq 'sem') { $iptuInf = $vStr + ' (sem período no site; lido como ' + $baseFinal + ' pelo valor)'; $contIptu['sem período -> ' + $baseFinal]++ }
    else { $iptuInf = $vStr + '/' + $(if ($rotulo -eq 'mensal') { 'mês' } else { 'ano' }) + ' no site; lido como ' + $baseFinal + ' pelo valor'; $contIptu['rótulo ' + $rotulo + ' -> ' + $baseFinal + ' pelo valor']++ }
  } else { $contIptu['vazio']++ }

  # áreas e cômodos
  $areaUtil = Num (Primeiro (Campo $listing 'usableAreas'))
  $areaTotal = Num (Primeiro (Campo $listing 'totalAreas')); if ($null -ne $areaTotal -and $areaTotal -le 0) { $areaTotal = $null }
  $andarNum = Num (Campo $listing 'unitFloor'); $andar = ''; if ($null -ne $andarNum -and $andarNum -gt 0) { $andar = [string][int]$andarNum }

  # reconferência local dos critérios (o site às vezes devolve fora)
  if ($null -eq $preco -or $preco -lt $precoMin -or $preco -gt $precoMax -or $null -eq $areaUtil -or $areaUtil -lt $areaMin -or $areaUtil -gt $areaMax) {
    $descartes.Add(('{0}: preco={1} area={2} (fora dos criterios)' -f $id, (NumStr $preco 0), (NumStr $areaUtil 2)))
    continue
  }
  # contagens (só do que vai para o CSV)
  $contPrec[$prec]++
  if ($numero -eq '') { $semNumero++ }
  if ($rua -eq '') { $semRua++ }

  # textos
  $titulo = Limpar-Texto (Str (Campo $detL 'title')) 200
  $descricaoCompleta = Limpar-Texto (Str (Campo $detL 'description')) 0
  $descricao = $descricaoCompleta; if ($descricao.Length -gt 300) { $descricao = $descricao.Substring(0, 300).TrimEnd() }

  # tipo e anunciante
  $unitType = Str (Primeiro (Campo $listing 'unitTypes'))
  $tipo = Classificar-Tipo $unitType (Campo $detL 'unitSubTypes') $titulo
  $anunciante = Str (Campo $account 'name'); $creci = Str (Campo $account 'licenseNumber')
  $contractType = Str (Campo $detL 'contractType'); if ($contractType -eq '') { $contractType = Str (Campo $listing 'contractType') }
  $tipoAnunciante = Classificar-Anunciante $contractType $creci $anunciante
  if (-not $contTipo.ContainsKey($tipo)) { $contTipo[$tipo] = 0 }; $contTipo[$tipo]++
  $chaveAn = $tipoAnunciante; if ($chaveAn -eq '') { $chaveAn = '(vazio)' }
  if (-not $contAnunciante.ContainsKey($chaveAn)) { $contAnunciante[$chaveAn] = 0 }; $contAnunciante[$chaveAn]++

  # links (href do VivaReal: da página no modo -DedupApi, do lote de links no padrão; sem href, monta o link
  # no padrão do site - o que vale para o site é o "-id-<id>/" do fim)
  $href = ''; if ($script:LinksVR.ContainsKey($id)) { $href = $script:LinksVR[$id] }
  $link = ''
  if ($href -ne '') { if ($href -match '^https?://') { $link = $href } else { $link = 'https://www.vivareal.com.br' + $href } }
  else {
    $semLink++
    $link = 'https://www.vivareal.com.br/imovel/{0}-{1}-quartos-{2}-zona-sul-rio-de-janeiro-{3}m2-venda-RS{4}-id-{5}/' -f `
      $(if ($unitType -eq 'KITNET') { 'kitnet' } else { 'apartamento' }), (IntOuVazio (Primeiro (Campo $listing 'bedrooms'))), `
      (Slug ($bairroSite.ToLowerInvariant() -replace '[áàâã]', 'a' -replace '[éê]', 'e' -replace '[í]', 'i' -replace '[óôõ]', 'o' -replace '[ú]', 'u' -replace '[ç]', 'c' -replace ' ', '-')), `
      (NumStr $areaUtil 0), (NumStr $preco 0), $id
    $link = $link -replace '--+', '-'
  }
  $linkAlt = ''
  if ($script:LinksZap.ContainsKey($id)) { $h2 = $script:LinksZap[$id]; if ($h2 -match '^https?://') { $linkAlt = $h2 } else { $linkAlt = 'https://www.zapimoveis.com.br' + $h2 } } else { $semLinkAlt++ }

  # datas
  $publicado = Converter-Data (Campo $listing 'createdAt'); if ($publicado -eq '') { $publicado = Converter-Data (Campo $detL 'createdAt') }
  $atualizado = Converter-Data (Campo $detL 'updatedAt'); if ($atualizado -eq '') { $semAtualizado++ }

  # fotos
  $fotos = ''
  $medias = Campo $det 'medias'
  if ($medias -is [array]) { $fotos = [string](@($medias | Where-Object { (Str (Campo $_ 'type')) -eq 'IMAGE' }).Count) }

  # destaques: amenities + acceptExchange + regex no título/descrição
  $achados = @{}
  $amen = Campo $listing 'amenities'
  if ($amen -is [array]) { foreach ($a in $amen) { $k = Str $a; if ($mapaAmenities.ContainsKey($k)) { $achados[$mapaAmenities[$k]] = $true } } }
  $permuta = Campo $detL 'acceptExchange'; if ($permuta -is [bool] -and $permuta) { $achados['aceita permuta'] = $true }
  $textoBusca = ($titulo + ' ' + $descricaoCompleta)
  foreach ($nomeDest in $ordemDestaques) { if ([regex]::IsMatch($textoBusca, '(?i)' + $regexDestaques[$nomeDest])) { $achados[$nomeDest] = $true } }
  $destaques = (@($ordemDestaques | Where-Object { $achados.ContainsKey($_) })) -join ' | '

  $linha = [ordered]@{
    chave = 'VIVAREAL_' + $id; fonte = 'VIVAREAL'; codigo = $id; link = $link; link_alt = $linkAlt; tipo = $tipo; titulo = $titulo
    rua = $rua; numero = $numero; cep = $cep; bairro_site = $bairroSite; lat = $lat; lon = $lon; precisao_coord = $prec
    preco = (NumStr $preco 0); area_util = (NumStr $areaUtil 2); area_total = (NumStr $areaTotal 2); condominio_mes = (NumStr $condo 0)
    iptu_mes = $iptuMes; iptu_informado = $iptuInf
    quartos = (IntOuVazio (Primeiro (Campo $listing 'bedrooms'))); banheiros = (IntOuVazio (Primeiro (Campo $listing 'bathrooms')))
    suites = (IntOuVazio (Primeiro (Campo $listing 'suites'))); vagas = (IntOuVazio (Primeiro (Campo $listing 'parkingSpaces'))); andar = $andar
    anunciante = $anunciante; tipo_anunciante = $tipoAnunciante; publicado_em = $publicado; atualizado_em = $atualizado; capturado_em = $agora
    fotos = $fotos; destaques = $destaques; descricao_resumo = $descricao; status_site = 'ATIVO'; bruto_json = $reg.arquivo
  }
  $linhas.Add([pscustomobject]$linha)
}

# ----------------------------------------------------------------------------------------------
# 4) CSV (UTF-8 com BOM, ';', decimal com ponto, aspas só quando preciso)
# ----------------------------------------------------------------------------------------------
function Csv-Campo($Valor) {
  $s = ''; if ($null -ne $Valor) { $s = [string]$Valor }
  if ($s.IndexOfAny([char[]]@(';', '"', "`r", "`n")) -ge 0) { return '"' + $s.Replace('"', '""') + '"' }
  return $s
}
$ordenadas = @($linhas | Sort-Object -Property @{ Expression = 'bairro_site' }, @{ Expression = { [double]$_.preco } }, @{ Expression = 'codigo' })
$saidaCsv = New-Object System.Collections.Generic.List[string]
$saidaCsv.Add(($colunas -join ';'))
foreach ($l in $ordenadas) {
  $campos = foreach ($c in $colunas) { Csv-Campo $l.$c }
  $saidaCsv.Add(($campos -join ';'))
}
[System.IO.File]::WriteAllLines($arquivoCsv, $saidaCsv, $utf8Bom)

# ----------------------------------------------------------------------------------------------
# 5) Resumo no log
# ----------------------------------------------------------------------------------------------
Log '--- Resumo ---'
foreach ($r in $script:Resumo) { Log ("  {0,-11} R$ {1,9}-{2,9}: totalCount {3,5} | obtidos {4,5} | novos {5,5} | paginas {6,3}" -f $r.bairro, $r.pmin, $r.pmax, $r.totalCount, $r.obtidos, $r.novos, $r.paginas) }
$porBairro = @($ordenadas | Group-Object bairro_site | Sort-Object Name)
foreach ($g in $porBairro) { Log ("  linhas no CSV com bairro_site = {0}: {1}" -f $g.Name, $g.Count) }
foreach ($b in $bairros) { Log ("  anuncios unicos obtidos na busca de {0}: {1}" -f $b, $totalPorBairro[$b]) }
Log ("  anuncios unicos: {0} | descartados fora dos criterios: {1} | linhas gravadas: {2}" -f $script:Anuncios.Count, $descartes.Count, $ordenadas.Count)
foreach ($d in $descartes) { Log ("    descartado {0}" -f $d) }
Log ("  coordenada exata {0} | aproximada {1} | nenhuma {2}" -f $contPrec['exata'], $contPrec['aproximada'], $contPrec['nenhuma'])
Log ("  sem numero {0} | sem rua {1} | sem link {2} | sem link Zap {3} | sem detalhe {4} | sem atualizado_em {5}" -f $semNumero, $semRua, $semLink, $semLinkAlt, $semDetalhe, $semAtualizado)
Log ("  IPTU (limite mensal {0}): {1}" -f $iptuLimiteMensal, (($contIptu.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $contIptu[$_] }) -join ' | '))
Log ("  tipo: {0}" -f (($contTipo.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $contTipo[$_] }) -join ', '))
Log ("  tipo_anunciante: {0}" -f (($contAnunciante.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $contAnunciante[$_] }) -join ', '))
Log ("  chamadas HTTP: {0} | respostas reaproveitadas do disco: {1} | baixado: {2:N1} MB | tempo total: {3:N1} s" -f $script:Chamadas, $script:Reaproveitados, ($script:BytesBaixados / 1MB), $relogio.Elapsed.TotalSeconds)
Log ("  CSV: {0}" -f $arquivoCsv)
if ($script:Falhas.Count -gt 0) {
  Log ("  FALHAS ({0}) - cobertura INCOMPLETA:" -f $script:Falhas.Count)
  foreach ($f in $script:Falhas) { Log ("    - {0}" -f $f) }
  Log 'exit 2'
  exit 2
}
Log 'Cobertura completa. exit 0'
exit 0
