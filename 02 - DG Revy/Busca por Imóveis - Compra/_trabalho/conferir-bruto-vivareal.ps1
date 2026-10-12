<#
.SINOPSE
  Confere um bruto-vivareal.csv contra o CONTRATO-DADOS.md (teste do componente, 11/10/2026).
  Uso: powershell -NoProfile -ExecutionPolicy Bypass -File conferir-bruto-vivareal.ps1 -Csv "<pasta>\bruto-vivareal.csv"
  Grava <pasta>\conferencia-bruto.txt e imprime o mesmo na tela. Exit 0 = tudo conforme; 3 = alguma regra violada.
#>
param([string]$Csv = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$inv = [System.Globalization.CultureInfo]::InvariantCulture
if ($Csv -eq '') { throw 'informe -Csv' }
$pasta = Split-Path $Csv -Parent
$saida = New-Object System.Collections.Generic.List[string]
$problemas = New-Object System.Collections.Generic.List[string]
function Linha([string]$t) { $saida.Add($t); Write-Host $t }
function Problema([string]$t) { $problemas.Add($t); Linha ('  PROBLEMA: ' + $t) }

Linha ("=== Conferencia de {0} ({1}) ===" -f $Csv, (Get-Date -Format 'yyyy-MM-dd HH:mm'))

# 1) BOM e cabeçalho
$bytes = [System.IO.File]::ReadAllBytes($Csv)
$bom = ('{0:X2} {1:X2} {2:X2}' -f $bytes[0], $bytes[1], $bytes[2])
Linha ("BOM: {0}" -f $bom); if ($bom -ne 'EF BB BF') { Problema 'sem BOM UTF-8' }
$primeira = (Get-Content -LiteralPath $Csv -Encoding UTF8 -TotalCount 1)
$cabecalho = $primeira -split ';'
$esperadas = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord',
  'preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar',
  'anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site')
Linha ("colunas no cabecalho: {0} (contrato: 34 + bruto_json tolerada)" -f $cabecalho.Count)
$ok = $true
for ($i = 0; $i -lt $esperadas.Count; $i++) { if ($cabecalho[$i] -ne $esperadas[$i]) { $ok = $false; Problema ("coluna {0}: esperada '{1}', veio '{2}'" -f ($i+1), $esperadas[$i], $cabecalho[$i]) } }
if ($cabecalho.Count -gt 34) { if ($cabecalho.Count -ne 35 -or $cabecalho[34] -ne 'bruto_json') { Problema ("colunas extras inesperadas: " + (($cabecalho | Select-Object -Skip 34) -join ',')) } }
if ($ok) { Linha '  as 34 colunas do contrato estao na ordem exata' }

# 2) linhas
$tab = @(Import-Csv -LiteralPath $Csv -Delimiter ';' -Encoding UTF8)
Linha ("linhas de dados: {0}" -f $tab.Count)
$chaves = @{}; $dup = 0
$numCols = @('lat','lon','preco','area_util','area_total','condominio_mes','iptu_mes','quartos','banheiros','suites','vagas','fotos')
$foraPreco = 0; $foraArea = 0; $chaveRuim = 0; $chaveCodigo = 0; $virgula = 0; $dataRuim = 0; $statusRuim = 0; $linkRuim = 0; $linkAltRuim = 0; $fonteRuim = 0; $tipoRuim = 0; $cepRuim = 0; $latRuim = 0
$tiposOk = @('Apartamento','Kitnet/Studio','Cobertura','Flat')
foreach ($l in $tab) {
  if ($l.chave -notmatch '^VIVAREAL_\d+$') { $chaveRuim++ }
  if ($l.chave -ne ('VIVAREAL_' + $l.codigo)) { $chaveCodigo++ }
  if ($chaves.ContainsKey($l.chave)) { $dup++ } else { $chaves[$l.chave] = 1 }
  if ($l.fonte -ne 'VIVAREAL') { $fonteRuim++ }
  $p = [double]::Parse($l.preco, $inv); $a = [double]::Parse($l.area_util, $inv)
  if ($p -lt 500000 -or $p -gt 1100000) { $foraPreco++ }
  if ($a -lt 35 -or $a -gt 70) { $foraArea++ }
  foreach ($c in $numCols) { if ($l.$c -match ',') { $virgula++ } }
  foreach ($c in 'publicado_em','atualizado_em') { if ($l.$c -ne '' -and $l.$c -notmatch '^\d{4}-\d{2}-\d{2}$') { $dataRuim++ } }
  if ($l.capturado_em -notmatch '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$') { $dataRuim++ }
  if ($l.status_site -ne 'ATIVO') { $statusRuim++ }
  if ($l.link -notmatch ('^https://www\.vivareal\.com\.br/imovel/.*-id-' + $l.codigo + '/$')) { $linkRuim++ }
  if ($l.link_alt -ne '' -and $l.link_alt -notmatch ('^https://www\.zapimoveis\.com\.br/imovel/.*-id-' + $l.codigo + '/$')) { $linkAltRuim++ }
  if ($tiposOk -notcontains $l.tipo) { $tipoRuim++ }
  if ($l.cep -ne '' -and $l.cep -notmatch '^\d{5}-\d{3}$') { $cepRuim++ }
  if ($l.lat -ne '' -and -not ([double]::Parse($l.lat, $inv) -lt -22.9 -and [double]::Parse($l.lat, $inv) -gt -23.1 -and [double]::Parse($l.lon, $inv) -lt -43.1 -and [double]::Parse($l.lon, $inv) -gt -43.3)) { $latRuim++ }
}
Linha ("chaves fora do padrao VIVAREAL_<id>: {0} | chave != VIVAREAL_+codigo: {1} | chaves duplicadas: {2} | fonte != VIVAREAL: {3}" -f $chaveRuim, $chaveCodigo, $dup, $fonteRuim)
Linha ("fora de preco 500000-1100000: {0} | fora de area 35-70: {1}" -f $foraPreco, $foraArea)
Linha ("campos numericos com virgula: {0} | datas fora do ISO: {1} | status_site != ATIVO: {2}" -f $virgula, $dataRuim, $statusRuim)
Linha ("link fora do padrao vivareal/-id-<codigo>/: {0} | link_alt fora do padrao zap: {1} | tipo fora de {2}: {3} | CEP fora de 99999-999: {4} | coordenada fora do Rio (Zona Sul): {5}" -f $linkRuim, $linkAltRuim, ($tiposOk -join '/'), $tipoRuim, $cepRuim, $latRuim)
foreach ($par in @(@('chaveRuim',$chaveRuim),@('chaveCodigo',$chaveCodigo),@('dup',$dup),@('fonteRuim',$fonteRuim),@('foraPreco',$foraPreco),@('foraArea',$foraArea),@('virgula',$virgula),@('dataRuim',$dataRuim),@('statusRuim',$statusRuim),@('linkRuim',$linkRuim),@('linkAltRuim',$linkAltRuim),@('tipoRuim',$tipoRuim),@('cepRuim',$cepRuim),@('latRuim',$latRuim))) {
  if ($par[1] -gt 0) { Problema ("{0} = {1}" -f $par[0], $par[1]) }
}

# 3) contagens
function Grupo([string]$titulo, $script) {
  $g = @($tab | Group-Object $script | Sort-Object Count -Descending)
  Linha ("{0}: {1}" -f $titulo, (($g | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }) -join ', '))
}
Grupo 'bairro_site' { $_.bairro_site }
Grupo 'tipo' { $_.tipo }
Grupo 'precisao_coord' { $_.precisao_coord }
Grupo 'numero' { if ($_.numero -eq '') { 'sem numero' } else { 'com numero' } }
Grupo 'rua' { if ($_.rua -eq '') { 'sem rua' } else { 'com rua' } }
Grupo 'cep' { if ($_.cep -eq '') { 'sem cep' } else { 'com cep' } }
Grupo 'atualizado_em' { if ($_.atualizado_em -eq '') { 'sem' } else { 'com' } }
Grupo 'publicado_em' { if ($_.publicado_em -eq '') { 'sem' } else { 'com' } }
Grupo 'link_alt (Zap)' { if ($_.link_alt -eq '') { 'sem' } else { 'com' } }
Grupo 'iptu base' { if ($_.iptu_mes -eq '') { 'vazio' } elseif ($_.iptu_informado -match '/m[eê]s') { 'mensal' } elseif ($_.iptu_informado -match '/ano') { 'anual' } else { 'outro' } }
Grupo 'iptu_informado (forma)' { $_.iptu_informado -replace '^\d+', 'N' }
Grupo 'condominio_mes' { if ($_.condominio_mes -eq '') { 'vazio' } else { 'informado' } }
Grupo 'tipo_anunciante' { if ($_.tipo_anunciante -eq '') { '(vazio)' } else { $_.tipo_anunciante } }
Grupo 'titulo' { if ($_.titulo -eq '') { 'vazio' } else { 'com' } }
Grupo 'descricao_resumo' { if ($_.descricao_resumo -eq '') { 'vazio' } else { 'com' } }
Grupo 'fotos' { if ($_.fotos -eq '') { 'vazio' } elseif ([int]$_.fotos -eq 0) { '0' } else { '>0' } }
Grupo 'andar' { if ($_.andar -eq '') { 'vazio' } else { 'informado' } }
Grupo 'quartos' { if ($_.quartos -eq '') { 'vazio' } else { $_.quartos } }
Grupo 'vagas' { if ($_.vagas -eq '') { 'vazio' } else { $_.vagas } }
$precos = @($tab | ForEach-Object { [double]::Parse($_.preco, $inv) } | Sort-Object); $areas = @($tab | ForEach-Object { [double]::Parse($_.area_util, $inv) } | Sort-Object)
Linha ("preco min {0} max {1} | area min {2} max {3}" -f $precos[0], $precos[-1], $areas[0], $areas[-1])
$datas = @($tab | Where-Object { $_.publicado_em -ne '' } | ForEach-Object { $_.publicado_em } | Sort-Object); Linha ("publicado_em de {0} a {1}" -f $datas[0], $datas[-1])
$datas = @($tab | Where-Object { $_.atualizado_em -ne '' } | ForEach-Object { $_.atualizado_em } | Sort-Object); Linha ("atualizado_em de {0} a {1}" -f $datas[0], $datas[-1])
$dest = @{}; foreach ($l in $tab) { foreach ($d in ($l.destaques -split ' \| ')) { if ($d -ne '') { if (-not $dest.ContainsKey($d)) { $dest[$d] = 0 }; $dest[$d]++ } } }
Linha ("destaques: " + (($dest.Keys | Sort-Object { -$dest[$_] } | ForEach-Object { '{0}={1}' -f $_, $dest[$_] }) -join ', '))

# 4) fatia de Copacabana que interessa (ruas do Arpoador)
function SemAcento([string]$s) { $n = $s.Normalize([Text.NormalizationForm]::FormD); (($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }) -join '').ToLowerInvariant() }
$ruasArpoador = @('Francisco Otaviano','Bulhões de Carvalho','Rainha Elizabeth','Raul Pompéia','Francisco Bhering','Joaquim Nabuco','Gomes Carneiro')
Linha 'ruas do Arpoador (fatia de Copacabana que interessa):'
$totalArp = 0
foreach ($r in $ruasArpoador) {
  $chave = SemAcento $r
  $hits = @($tab | Where-Object { (SemAcento $_.rua) -match [regex]::Escape($chave) })
  $porBairro = (($hits | Group-Object bairro_site | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }) -join ', ')
  Linha ("  {0,-22} {1,4} anuncio(s)  [{2}]" -f $r, $hits.Count, $porBairro)
  $totalArp += $hits.Count
}
Linha ("  total nessas ruas: {0}" -f $totalArp)

Linha ''
if ($problemas.Count -eq 0) { Linha 'RESULTADO: CONFORME o contrato' } else { Linha ("RESULTADO: {0} problema(s)" -f $problemas.Count) }
[System.IO.File]::WriteAllLines((Join-Path $pasta 'conferencia-bruto.txt'), $saida, (New-Object System.Text.UTF8Encoding($true)))
if ($problemas.Count -eq 0) { exit 0 } else { exit 3 }
