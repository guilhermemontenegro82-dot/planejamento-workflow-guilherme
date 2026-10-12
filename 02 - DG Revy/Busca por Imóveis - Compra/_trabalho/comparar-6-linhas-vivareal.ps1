<#
.SINOPSE
  Sorteia 6 linhas do bruto-vivareal.csv (2 Ipanema, 2 Leblon, 2 Copacabana) e compara com a glue-api ao vivo
  (listings?id=<id>), campo a campo; testa o link (HTTP) e, em 2 delas, o link_alt do Zap. Teste do componente, 11/10/2026.
  Uso: powershell -NoProfile -ExecutionPolicy Bypass -File comparar-6-linhas-vivareal.ps1 -Csv "<pasta>\bruto-vivareal.csv" [-Seed 20261011]
  Saída: <pasta>\comparacao\comparacao-6-linhas.txt + JSONs das consultas.
#>
param([string]$Csv = '', [int]$Seed = 20261011)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$inv = [System.Globalization.CultureInfo]::InvariantCulture
if ($Csv -eq '') { throw 'informe -Csv' }
$pasta = Join-Path (Split-Path $Csv -Parent) 'comparacao'
New-Item -ItemType Directory -Force -Path $pasta | Out-Null
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$api = 'https://glue-api.vivareal.com/v2/listings'
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
$saida = New-Object System.Collections.Generic.List[string]
function Linha([string]$t) { $saida.Add($t); Write-Host $t }
function Baixar([string]$Url, [string]$XDom, [string]$Arq) {
  $code = & $curl -s -m 40 -A $ua -H "x-domain: $XDom" -H 'Accept: application/json' -o $Arq -w '%{http_code}' $Url
  if ($code -ne '200') { return $null }
  return $js.DeserializeObject([System.IO.File]::ReadAllText($Arq, [System.Text.Encoding]::UTF8))
}
function DataLocal([string]$iso) { if ($iso -eq '') { return '' }; return ([DateTimeOffset]::Parse($iso, $inv)).ToLocalTime().ToString('yyyy-MM-dd') }
function Cmp([string]$campo, $csv, $api) {
  $a = [string]$csv; $b = [string]$api
  $ok = ($a -eq $b)
  Linha ("    {0,-16} csv=[{1}]  api=[{2}]  {3}" -f $campo, $a, $b, $(if ($ok) { 'OK' } else { 'DIFERENTE' }))
  return $ok
}

$tab = @(Import-Csv -LiteralPath $Csv -Delimiter ';' -Encoding UTF8)
Get-Random -SetSeed $Seed | Out-Null
$amostra = @()
foreach ($b in 'Ipanema','Leblon','Copacabana') { $amostra += @($tab | Where-Object { $_.bairro_site -eq $b } | Get-Random -Count 2) }
Linha ("=== Comparacao de 6 linhas de {0} com a API ao vivo ({1}; seed {2}) ===" -f $Csv, (Get-Date -Format 'yyyy-MM-dd HH:mm'), $Seed)
# (sem 'page': na consulta por id o 'page' derruba a API com HTTP 500 - testado em 11/10/2026)
$include = 'search(result(listings(listing(id,status,pricingInfos,usableAreas,address,updatedAt,bedrooms,parkingSpaces),link)),totalCount)'
$totOk = 0; $totCampos = 0; $n = 0
foreach ($l in $amostra) {
  $n++
  $id = $l.codigo
  Linha ''
  Linha ("[{0}] {1} - {2} - {3}, {4} ({5}) - R$ {6} - {7} m2" -f $n, $l.chave, $l.bairro_site, $l.rua, $l.numero, $l.tipo, $l.preco, $l.area_util)
  $arq = Join-Path $pasta ('api_' + $id + '.json')
  $o = Baixar ('{0}?id={1}&includeFields={2}' -f $api, $id, $include) 'www.vivareal.com.br' $arq
  if ($null -eq $o) { Linha '    FALHA ao consultar a API'; continue }
  $tc = [int]$o['search']['totalCount']
  Linha ("    totalCount={0}" -f $tc)
  if ($tc -lt 1) { continue }
  $item = $o['search']['result']['listings'][0]; $lst = $item['listing']
  $pi = $null; foreach ($p in $lst['pricingInfos']) { if ($p['businessType'] -eq 'SALE') { $pi = $p; break } }; if ($null -eq $pi) { $pi = $lst['pricingInfos'][0] }
  $addr = $lst['address']
  $ok = 0; $campos = 0
  $campos++; if (Cmp 'status' 'ATIVO' $(if ($lst['status'] -eq 'ACTIVE') { 'ATIVO' } else { $lst['status'] })) { $ok++ }
  $campos++; if (Cmp 'preco' $l.preco ([string][int64][double]$pi['price'])) { $ok++ }
  $campos++; if (Cmp 'area_util' $l.area_util ([string]([double]$lst['usableAreas'][0]).ToString('0.##', $inv))) { $ok++ }
  $campos++; if (Cmp 'rua' $l.rua ([string]$addr['street'])) { $ok++ }
  $campos++; if (Cmp 'numero' $l.numero ([string]$addr['streetNumber'])) { $ok++ }
  $campos++; if (Cmp 'bairro_site' $l.bairro_site ([string]$addr['neighborhood'])) { $ok++ }
  $condo = ''; if ($pi.ContainsKey('monthlyCondoFee') -and [double]$pi['monthlyCondoFee'] -gt 0) { $condo = [string][int64][double]$pi['monthlyCondoFee'] }
  $campos++; if (Cmp 'condominio_mes' $l.condominio_mes $condo) { $ok++ }
  # IPTU: valor cru + rótulo da API; base esperada pela regra do coletor (<= 700 mensal, > 700 anual)
  $iptuCru = ''; if ($pi.ContainsKey('yearlyIptu')) { $iptuCru = [string][int64][double]$pi['yearlyIptu'] }
  $per = ''; if ($pi.ContainsKey('iptuPeriod')) { $per = [string]$pi['iptuPeriod'] }
  $esperado = ''; if ($iptuCru -ne '' -and [double]$iptuCru -gt 0) { if ([double]$iptuCru -le 700) { $esperado = $iptuCru } else { $esperado = [string][int64][math]::Round([double]$iptuCru / 12) } }
  Linha ("    {0,-16} api: yearlyIptu=[{1}] iptuPeriod=[{2}]  csv iptu_informado=[{3}]" -f 'iptu (cru)', $iptuCru, $per, $l.iptu_informado)
  $campos++; if (Cmp 'iptu_mes' $l.iptu_mes $esperado) { $ok++ }
  $q = ''; if ($lst['bedrooms'] -is [array] -and $lst['bedrooms'].Count -gt 0) { $q = [string][int]$lst['bedrooms'][0] }
  $campos++; if (Cmp 'quartos' $l.quartos $q) { $ok++ }
  $vg = ''; if ($lst['parkingSpaces'] -is [array] -and $lst['parkingSpaces'].Count -gt 0) { $vg = [string][int]$lst['parkingSpaces'][0] }
  $campos++; if (Cmp 'vagas' $l.vagas $vg) { $ok++ }
  $campos++; if (Cmp 'atualizado_em' $l.atualizado_em (DataLocal ([string]$lst['updatedAt']))) { $ok++ }
  $href = ''; if ($item.ContainsKey('link')) { $href = [string]$item['link']['href'] }
  if ($href -ne '') { $campos++; if (Cmp 'link' $l.link ('https://www.vivareal.com.br' + $href)) { $ok++ } }
  else { $campos++; $padrao = ($l.link -match ('^https://www\.vivareal\.com\.br/imovel/.*-id-' + $id + '/$')); Linha ('    {0,-16} csv=[{1}]  api: a consulta por id nao devolve link; padrao /imovel/...-id-<id>/ {2}' -f 'link', $l.link, $(if ($padrao) { 'OK' } else { 'DIFERENTE' })); if ($padrao) { $ok++ } }
  $code = & $curl -s -L -m 40 -A $ua -o NUL -w '%{http_code}' $l.link
  Linha ("    link HTTP {0} (403 = Cloudflare barra robô na página HTML; aceitável)" -f $code)
  # link_alt (Zap) nas 2 primeiras (1 Ipanema, 1 Leblon) e em qualquer linha sem link_alt
  if ($n -in 1,3 -or $l.link_alt -eq '') {
    $arqZ = Join-Path $pasta ('zap_' + $id + '.json')
    $oz = Baixar ('{0}?id={1}&includeFields=search(result(listings(listing(id,portal,portals),link)),totalCount)' -f $api, $id) 'www.zapimoveis.com.br' $arqZ
    if ($null -eq $oz) { Linha '    zap: FALHA ao consultar' }
    else {
      $tcz = [int]$oz['search']['totalCount']; $hz = ''; $portais = ''
      if ($tcz -gt 0) { $iz = $oz['search']['result']['listings'][0]; if ($iz.ContainsKey('link')) { $hz = [string]$iz['link']['href'] }; $portais = ([string]$iz['listing']['portal']) + ' / ' + (@($iz['listing']['portals']) -join ',') }
      Linha ("    zap: totalCount={0} portal/portais=[{1}]" -f $tcz, $portais)
      if ($hz -ne '' -or $l.link_alt -eq '') { $campos++; if (Cmp 'link_alt' $l.link_alt $(if ($hz -ne '') { 'https://www.zapimoveis.com.br' + $hz } else { '' })) { $ok++ } }
      else { $campos++; $padrao = ($l.link_alt -match ('^https://www\.zapimoveis\.com\.br/imovel/.*-id-' + $id + '/$')); Linha ('    {0,-16} csv=[{1}]  api: a consulta por id nao devolve link; padrao zap/imovel/...-id-<id>/ {2}' -f 'link_alt', $l.link_alt, $(if ($padrao) { 'OK' } else { 'DIFERENTE' })); if ($padrao) { $ok++ } }
      if ($l.link_alt -ne '') { $codeZ = & $curl -s -L -m 40 -A $ua -o NUL -w '%{http_code}' $l.link_alt; Linha ("    link_alt HTTP {0}" -f $codeZ) }
    }
  }
  Linha ("    => {0}/{1} campos iguais" -f $ok, $campos)
  $totOk += $ok; $totCampos += $campos
  Start-Sleep -Milliseconds 400
}
Linha ''
Linha ("TOTAL: {0}/{1} campos iguais" -f $totOk, $totCampos)
[System.IO.File]::WriteAllLines((Join-Path $pasta 'comparacao-6-linhas.txt'), $saida, (New-Object System.Text.UTF8Encoding($true)))
