<#
.SINOPSE
  Verifica se anúncios do VivaReal / Zap ainda estão no ar (checagem de disponibilidade).

.DESCRIÇÃO
  Para cada id (vindo de um CSV com coluna "chave" no padrão VIVAREAL_<id>, ou de -Ids "id1,id2"),
  consulta a glue-api em lotes de até 30 ids (listings?id=a,b,c&size=N). Quem não vier no lote é
  confirmado individualmente (listings?id=<id>): totalCount 0 -> NAO_ENCONTRADO.
    status ACTIVE            -> ATIVO
    status diferente         -> INATIVO
    totalCount 0             -> NAO_ENCONTRADO
    falha de rede/API        -> ERRO (nunca marcar como removido)
  Saída: <Saida>\verificacao-vivareal.csv (chave;status_site;preco_atual;verificado_em;evidencia),
         <Saida>\json\vivareal-verificacao\*.json (respostas, para auditoria),
         <Saida>\verificar-vivareal.log.
  Códigos de saída: 0 = todos verificados; 2 = algum id ficou como ERRO.

.PARÂMETROS
  -Chaves     CSV (;) com coluna "chave"; só as chaves VIVAREAL_* são consideradas
  -Ids        alternativa: lista de ids separados por vírgula
  -Saida      pasta de saída (padrão: <raiz>\_dados\<hoje>)
  -Criterios  criterios.json (api, x_domain, user_agent)

.EXEMPLO
  powershell.exe -ExecutionPolicy Bypass -File verificar-vivareal.ps1 -Ids "2477017979,2909025223,9999999999" -Saida "..\_trabalho\testes-vivareal"
#>
[CmdletBinding()]
param(
  [string]$Chaves = '',
  [string]$Ids = '',
  [string]$Saida = '',
  [string]$Criterios = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($Criterios -eq '') { $Criterios = Join-Path $raiz 'Sites e critérios para Busca\criterios.json' }
if ($Saida -eq '')     { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
$pastaJson = Join-Path $Saida 'json\vivareal-verificacao'
New-Item -ItemType Directory -Force -Path $pastaJson | Out-Null
$script:LogPath = Join-Path $Saida 'verificar-vivareal.log'
if (Test-Path -LiteralPath $script:LogPath) { Remove-Item -LiteralPath $script:LogPath -Force }
$arquivoCsv = Join-Path $Saida 'verificacao-vivareal.csv'

function Log([string]$Msg) {
  $linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Msg
  Write-Host $linha
  [System.IO.File]::AppendAllText($script:LogPath, $linha + "`r`n", [System.Text.Encoding]::UTF8)
}
Log '=== verificar-vivareal.ps1 ==='

$crit = Get-Content -LiteralPath $Criterios -Raw -Encoding UTF8 | ConvertFrom-Json
$api = [string]$crit.sites.VIVAREAL.api
$xdom = [string]$crit.sites.VIVAREAL.x_domain
$script:UA = [string]$crit.user_agent

Add-Type -AssemblyName System.Web.Extensions
$script:Json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$script:Json.MaxJsonLength = [int]::MaxValue

function Campo($Dic, [string]$Chave) {
  if ($null -eq $Dic) { return $null }
  # "return ,$x": o PowerShell desenrola arrays devolvidos por função; a vírgula entrega o valor inteiro.
  if ($Dic -is [System.Collections.Generic.Dictionary[string,object]]) { if ($Dic.ContainsKey($Chave)) { return ,$Dic[$Chave] } }
  return $null
}
function Primeiro($Valor) {
  if ($null -eq $Valor) { return $null }
  if ($Valor -is [array]) { if ($Valor.Count -gt 0) { return ,$Valor[0] } ; return $null }
  return ,$Valor
}
function Num($Valor) {
  if ($null -eq $Valor) { return $null }
  if ($Valor -is [string]) { $s = $Valor.Trim(); if ($s -eq '') { return $null }; $r = 0.0; if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$r)) { return $r }; return $null }
  try { return [double]$Valor } catch { return $null }
}
function Str($Valor) { if ($null -eq $Valor) { return '' } ; return ([string]$Valor).Trim() }
function NumStr($Valor, [int]$Decimais) {
  if ($null -eq $Valor) { return '' }
  if ($Decimais -le 0) { return ([string][int64][math]::Round([double]$Valor)) }
  return ([double]$Valor).ToString('0.' + ('#' * $Decimais), $inv)
}

$script:Curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$script:Chamadas = 0
function Baixar-Json {
  param([string]$Url, [string]$Arquivo)
  $motivo = ''
  for ($tent = 1; $tent -le 3; $tent++) {
    $script:Chamadas++
    $codigo = ''
    try {
      $saidaCurl = & $script:Curl -s -m 40 -A $script:UA -H "x-domain: $xdom" -H 'Accept: application/json' -o $Arquivo -w '%{http_code}' $Url
      $codigo = ([string]$saidaCurl).Trim()
    } catch { $codigo = 'EXC'; $motivo = 'excecao: ' + $_.Exception.Message }
    if ($codigo -eq '200' -and (Test-Path -LiteralPath $Arquivo)) {
      $txt = [System.IO.File]::ReadAllText($Arquivo, [System.Text.Encoding]::UTF8)
      $obj = $null
      try { $obj = $script:Json.DeserializeObject($txt) } catch { $obj = $null }
      if ($null -ne $obj -and ($obj -is [System.Collections.Generic.Dictionary[string,object]]) -and $obj.ContainsKey('search')) { return @{ ok = $true; obj = $obj } }
      if ($null -ne $obj -and ($obj -is [System.Collections.Generic.Dictionary[string,object]]) -and $obj.ContainsKey('err')) {
        $e = ([string]$obj['err']) -replace '\s+', ' '; if ($e.Length -gt 160) { $e = $e.Substring(0, 160) }
        $motivo = 'erro da API: ' + $e
      } else { $motivo = 'resposta 200 sem JSON valido' }
    } elseif ($codigo -ne 'EXC') { $motivo = 'HTTP ' + $codigo + ' (curl exit ' + $LASTEXITCODE + ')' }
    Log ("      tentativa {0}/3 falhou: {1}" -f $tent, $motivo)
    if ($tent -lt 3) { Start-Sleep -Seconds 2 }
  }
  return @{ ok = $false; motivo = $motivo }
}
function Extrair-Listings($Obj) {
  # Emite os anúncios no pipeline (sem vírgula): o chamador SEMPRE fecha com @(...), que recolhe N, 1 ou 0 como array.
  $lista = Campo (Campo (Campo $Obj 'search') 'result') 'listings'
  if ($lista -is [array]) { return @($lista) }
  return @()
}
$include = 'search(result(listings(listing(id,status,updatedAt,pricingInfos,usableAreas))),totalCount)'

# ----------------------------------------------------------------------------------------------
# Ids a verificar
# ----------------------------------------------------------------------------------------------
$idsLista = New-Object System.Collections.Generic.List[string]
$ignoradas = 0
if ($Chaves -ne '') {
  if (-not (Test-Path -LiteralPath $Chaves)) { Log ("arquivo de chaves nao encontrado: {0}" -f $Chaves); exit 2 }
  $tab = Import-Csv -LiteralPath $Chaves -Delimiter ';' -Encoding UTF8
  foreach ($linha in $tab) {
    $ch = Str $linha.chave
    if ($ch -match '^VIVAREAL_(\d+)$') { if (-not $idsLista.Contains($Matches[1])) { $idsLista.Add($Matches[1]) } }
    elseif ($ch -ne '') { $ignoradas++ }
  }
  Log ("chaves lidas de {0}: {1} ids VivaReal, {2} chaves de outras fontes ignoradas" -f $Chaves, $idsLista.Count, $ignoradas)
}
if ($Ids -ne '') {
  foreach ($x in ($Ids -split '[,; ]+')) { $v = (Str $x) -replace '^VIVAREAL_', ''; if ($v -match '^\d+$' -and -not $idsLista.Contains($v)) { $idsLista.Add($v) } }
  Log ("ids informados por parametro: {0}" -f $idsLista.Count)
}
if ($idsLista.Count -eq 0) { Log 'nenhum id para verificar (use -Chaves <csv> ou -Ids "a,b,c")'; exit 2 }

# ----------------------------------------------------------------------------------------------
# Lotes de 30 + confirmação individual de quem não veio
# ----------------------------------------------------------------------------------------------
$agora = Get-Date -Format 'yyyy-MM-dd HH:mm'
$resultado = @{}     # id -> ordered (status_site, preco_atual, evidencia)
function Interpretar($Listing, [string]$Origem) {
  $status = Str (Campo $Listing 'status')
  $pi = $null
  $pr = Campo $Listing 'pricingInfos'
  if ($pr -is [array]) { foreach ($p in $pr) { if ((Str (Campo $p 'businessType')) -eq 'SALE') { $pi = $p; break } }; if ($null -eq $pi -and $pr.Count -gt 0) { $pi = $pr[0] } }
  $preco = Num (Campo $pi 'price')
  $area = Num (Primeiro (Campo $Listing 'usableAreas'))
  $sit = 'INATIVO'; if ($status -eq 'ACTIVE') { $sit = 'ATIVO' }
  $ev = ('{0}; status={1}; updatedAt={2}; preco={3}; area={4}' -f $Origem, $status, (Str (Campo $Listing 'updatedAt')), (NumStr $preco 0), (NumStr $area 2))
  return [ordered]@{ status_site = $sit; preco_atual = (NumStr $preco 0); evidencia = $ev }
}

# ATENÇÃO: não chamar este array de "$ids": o PowerShell não distingue maiúsculas e ele cairia no parâmetro
# [string]$Ids, que converte o array num texto só ("id1 id2 id3") sem dar erro (defeito corrigido em 11/10/2026).
$listaIds = $idsLista.ToArray()     # (@($lista) NAO enumera uma List[string] no PS 5.1: viraria 1 elemento)
$nLote = 0
$pendentes = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $listaIds.Count; $i += 30) {
  $fim = [math]::Min($i + 29, $listaIds.Count - 1)
  $lote = @($listaIds[$i..$fim])
  $nLote++
  $arq = Join-Path $pastaJson ('lote_{0:000}.json' -f $nLote)
  $url = '{0}?id={1}&size={2}&includeFields={3}' -f $api, ($lote -join ','), $lote.Count, $include
  $r = Baixar-Json -Url $url -Arquivo $arq
  if ($r.ok) {
    $vieram = @{}
    foreach ($item in @(Extrair-Listings $r.obj)) {
      $l = Campo $item 'listing'; $id = Str (Campo $l 'id')
      if ($id -ne '' -and ($lote -contains $id)) { $resultado[$id] = Interpretar $l ('lote de ' + $lote.Count + ' ids'); $vieram[$id] = $true }
    }
    foreach ($id in $lote) { if (-not $vieram.ContainsKey($id)) { $pendentes.Add($id) } }
    Log ("  lote {0}: {1} ids pedidos, {2} encontrados, {3} para confirmar individualmente" -f $nLote, $lote.Count, $vieram.Count, ($lote.Count - $vieram.Count))
  } else {
    Log ("  lote {0} FALHOU ({1}); os {2} ids serao tentados um a um" -f $nLote, $r.motivo, $lote.Count)
    foreach ($id in $lote) { $pendentes.Add($id) }
  }
  Start-Sleep -Milliseconds 400
}

foreach ($id in $pendentes) {
  $arq = Join-Path $pastaJson ('id_{0}.json' -f $id)
  $url = '{0}?id={1}&includeFields={2}' -f $api, $id, $include
  $r = Baixar-Json -Url $url -Arquivo $arq
  if (-not $r.ok) {
    $resultado[$id] = [ordered]@{ status_site = 'ERRO'; preco_atual = ''; evidencia = ('falha de rede/API: ' + $r.motivo) }
  } else {
    $tc = Num (Campo (Campo $r.obj 'search') 'totalCount'); if ($null -eq $tc) { $tc = 0 }
    $achado = $null
    foreach ($item in @(Extrair-Listings $r.obj)) { $l = Campo $item 'listing'; if ((Str (Campo $l 'id')) -eq $id) { $achado = $l; break } }
    if ($null -ne $achado) { $resultado[$id] = Interpretar $achado 'consulta individual' }
    else { $resultado[$id] = [ordered]@{ status_site = 'NAO_ENCONTRADO'; preco_atual = ''; evidencia = ('consulta individual: totalCount=' + [int]$tc) } }
  }
  Log ("  id {0}: {1} ({2})" -f $id, $resultado[$id].status_site, $resultado[$id].evidencia)
  Start-Sleep -Milliseconds 400
}

# ----------------------------------------------------------------------------------------------
# CSV + resumo
# ----------------------------------------------------------------------------------------------
function Csv-Campo($Valor) {
  $s = ''; if ($null -ne $Valor) { $s = [string]$Valor }
  if ($s.IndexOfAny([char[]]@(';', '"', "`r", "`n")) -ge 0) { return '"' + $s.Replace('"', '""') + '"' }
  return $s
}
$saidaCsv = New-Object System.Collections.Generic.List[string]
$saidaCsv.Add('chave;status_site;preco_atual;verificado_em;evidencia')
$cont = @{ ATIVO = 0; INATIVO = 0; NAO_ENCONTRADO = 0; ERRO = 0 }
foreach ($id in $listaIds) {
  $r = $resultado[$id]
  if ($null -eq $r) { $r = [ordered]@{ status_site = 'ERRO'; preco_atual = ''; evidencia = 'sem resultado (nao deveria acontecer)' } }
  $cont[$r.status_site]++
  $saidaCsv.Add((@((Csv-Campo ('VIVAREAL_' + $id)), (Csv-Campo $r.status_site), (Csv-Campo $r.preco_atual), (Csv-Campo $agora), (Csv-Campo $r.evidencia)) -join ';'))
}
[System.IO.File]::WriteAllLines($arquivoCsv, $saidaCsv, $utf8Bom)
Log ("Resumo: {0} ids | ATIVO {1} | INATIVO {2} | NAO_ENCONTRADO {3} | ERRO {4} | chamadas {5} | {6:N1} s" -f $listaIds.Count, $cont['ATIVO'], $cont['INATIVO'], $cont['NAO_ENCONTRADO'], $cont['ERRO'], $script:Chamadas, $relogio.Elapsed.TotalSeconds)
Log ("CSV: {0}" -f $arquivoCsv)
if ($cont['ERRO'] -gt 0) { Log 'exit 2 (houve ERRO)'; exit 2 }
exit 0
