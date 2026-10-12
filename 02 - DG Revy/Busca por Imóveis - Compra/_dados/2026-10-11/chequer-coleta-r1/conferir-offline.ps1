# conferir-offline.ps1 - chequer de coleta, rodada 1 (itens 3, 5, 8, 9, 10 e sorteios). ASCII only.
param([string]$Dados = 'D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_dados\2026-10-11')
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$raiz = Split-Path -Parent (Split-Path -Parent $Dados)
$saida = Join-Path $Dados 'chequer-coleta-r1'
$crit = Get-Content (Join-Path $raiz 'Sites e critérios para Busca\criterios.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Sec($t) { Write-Output ''; Write-Output "===== $t =====" }

# ---------- item 10: hashes e contagens ----------
Sec 'ITEM 10 - hash e contagem de linhas'
foreach ($f in 'coleta.csv', 'bruto-vivareal.csv', 'bruto-quintoandar.csv', 'bruto-chavesnamao.csv') {
    $p = Join-Path $Dados $f
    $h = (Get-FileHash -Path $p -Algorithm SHA256).Hash
    $n = ([System.IO.File]::ReadAllLines($p)).Count - 1
    Write-Output ("{0,-24} linhas(sem cabecalho)={1,5}  SHA256={2}  curto={3}" -f $f, $n, $h, $h.Substring(0, 12))
}

# ---------- carga ----------
$col = @(Import-Csv -Path (Join-Path $Dados 'coleta.csv') -Delimiter ';' -Encoding UTF8)
Write-Output ("coleta.csv importado: {0} linhas" -f $col.Count)

# ---------- item 5: formato ----------
Sec 'ITEM 5 - formato'
$colunasContrato = 'chave;fonte;codigo;link;link_alt;tipo;titulo;rua;numero;cep;bairro_site;lat;lon;precisao_coord;preco;area_util;area_total;condominio_mes;iptu_mes;iptu_informado;quartos;banheiros;suites;vagas;andar;anunciante;tipo_anunciante;publicado_em;atualizado_em;capturado_em;fotos;destaques;descricao_resumo;status_site'
$colunasConsol = $colunasContrato + ';dentro_area;motivo_area;poligono;bairro;duplicata_grupo'
foreach ($f in 'coleta.csv', 'bruto-vivareal.csv', 'bruto-quintoandar.csv', 'bruto-chavesnamao.csv') {
    $p = Join-Path $Dados $f
    $bytes = [System.IO.File]::ReadAllBytes($p)[0..2]
    $bom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $cab = ([System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8))[0] -replace '"', ''
    $esperado = if ($f -eq 'coleta.csv') { $colunasConsol } else { $colunasContrato }
    $ok = ($cab -eq $esperado) -or ($cab -eq ($esperado + ';bruto_json'))
    $extra = if ($cab -eq ($esperado + ';bruto_json')) { ' (+bruto_json no fim, tolerado pelo contrato)' } else { '' }
    Write-Output ("{0,-24} BOM={1}  colunas_ordem_ok={2}{3}" -f $f, $bom, $ok, $extra)
    if (-not $ok) { Write-Output "   cabecalho real: $cab" }
}
# bruto_json vazio?
foreach ($f in 'bruto-vivareal.csv', 'bruto-quintoandar.csv', 'bruto-chavesnamao.csv') {
    $b = @(Import-Csv -Path (Join-Path $Dados $f) -Delimiter ';' -Encoding UTF8)
    $naoVazio = @($b | Where-Object { $_.PSObject.Properties['bruto_json'] -and $_.bruto_json -ne '' }).Count
    $st = @($b | Where-Object { $_.status_site -ne 'ATIVO' }).Count
    $chaves = @($b | Select-Object -ExpandProperty chave)
    $dup = @($chaves | Group-Object | Where-Object { $_.Count -gt 1 }).Count
    Write-Output ("{0,-24} linhas={1,5} bruto_json_nao_vazio={2} status_site<>ATIVO={3} chaves_repetidas={4}" -f $f, $b.Count, $naoVazio, $st, $dup)
}
# consolidado: chave unica, status_site, decimal, datas
$dupCol = @($col | Group-Object chave | Where-Object { $_.Count -gt 1 })
Write-Output ("coleta.csv chaves repetidas: {0}" -f $dupCol.Count)
Write-Output ("coleta.csv status_site <> ATIVO: {0}" -f @($col | Where-Object { $_.status_site -ne 'ATIVO' }).Count)
$numCols = 'lat', 'lon', 'preco', 'area_util', 'area_total', 'condominio_mes', 'iptu_mes', 'quartos', 'banheiros', 'suites', 'vagas', 'fotos'
foreach ($c in $numCols) {
    $virg = @($col | Where-Object { $_.$c -match ',' }).Count
    $naoNum = @($col | Where-Object { $_.$c -ne '' -and -not ($_.$c -match '^-?\d+(\.\d+)?$') }).Count
    if ($virg -gt 0 -or $naoNum -gt 0) { Write-Output ("  coluna {0}: com virgula={1} nao-numerico={2}" -f $c, $virg, $naoNum) }
}
Write-Output 'decimais: colunas numericas conferidas (so se lista algo quando ha desvio)'
$dIso = @($col | Where-Object { ($_.publicado_em -ne '' -and -not ($_.publicado_em -match '^\d{4}-\d{2}-\d{2}$')) -or ($_.atualizado_em -ne '' -and -not ($_.atualizado_em -match '^\d{4}-\d{2}-\d{2}$')) }).Count
$dCap = @($col | Where-Object { -not ($_.capturado_em -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$') }).Count
Write-Output ("datas: publicado_em/atualizado_em fora de yyyy-MM-dd = {0}; capturado_em fora de 'yyyy-MM-dd HH:mm' = {1}" -f $dIso, $dCap)
$ex = $col[0]
Write-Output ("exemplo linha 1: chave={0} lat={1} lon={2} preco={3} area={4} publicado_em={5} atualizado_em={6} capturado_em={7}" -f $ex.chave, $ex.lat, $ex.lon, $ex.preco, $ex.area_util, $ex.publicado_em, $ex.atualizado_em, $ex.capturado_em)
# valores de dentro_area e fonte
Write-Output 'dentro_area valores:'
$col | Group-Object dentro_area | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-12} {1}" -f $_.Name, $_.Count) }
Write-Output 'fonte valores:'
$col | Group-Object fonte | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-12} {1}" -f $_.Name, $_.Count) }
Write-Output 'tipo valores:'
$col | Group-Object tipo | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-14} {1}" -f $_.Name, $_.Count) }
Write-Output 'precisao_coord valores:'
$col | Group-Object precisao_coord | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-12} {1}" -f $_.Name, $_.Count) }

# ---------- item 3: criterios ----------
Sec 'ITEM 3 - criterios'
$pmin = [double]$crit.preco_min; $pmax = [double]$crit.preco_max; $amin = [double]$crit.area_util_min; $amax = [double]$crit.area_util_max
$tipos = @($crit.tipos_incluidos)
$foraPreco = @($col | Where-Object { $v = [double]::Parse($_.preco, $inv); $v -lt $pmin -or $v -gt $pmax })
$foraArea = @($col | Where-Object { $v = [double]::Parse($_.area_util, $inv); $v -lt $amin -or $v -gt $amax })
$foraTipo = @($col | Where-Object { $tipos -notcontains $_.tipo })
$semPreco = @($col | Where-Object { $_.preco -eq '' }).Count
$semArea = @($col | Where-Object { $_.area_util -eq '' }).Count
Write-Output ("preco fora de [{0},{1}]: {2}  (sem preco: {3})" -f $pmin, $pmax, $foraPreco.Count, $semPreco)
Write-Output ("area_util fora de [{0},{1}]: {2}  (sem area: {3})" -f $amin, $amax, $foraArea.Count, $semArea)
Write-Output ("tipo fora de ({0}): {1}" -f ($tipos -join ', '), $foraTipo.Count)
$foraPreco | Select-Object -First 5 | ForEach-Object { Write-Output ("   preco: {0} {1}" -f $_.chave, $_.preco) }
$foraArea | Select-Object -First 5 | ForEach-Object { Write-Output ("   area: {0} {1}" -f $_.chave, $_.area_util) }
$foraTipo | Select-Object -First 5 | ForEach-Object { Write-Output ("   tipo: {0} {1}" -f $_.chave, $_.tipo) }
$precos = $col | ForEach-Object { [double]::Parse($_.preco, $inv) } | Measure-Object -Minimum -Maximum
$areas = $col | ForEach-Object { [double]::Parse($_.area_util, $inv) } | Measure-Object -Minimum -Maximum
Write-Output ("preco min={0} max={1}; area min={2} max={3}" -f $precos.Minimum, $precos.Maximum, $areas.Minimum, $areas.Maximum)

# ---------- item 8: proporcoes ----------
Sec 'ITEM 8 - proporcoes (sobre as linhas aceitas)'
$n = $col.Count
$nConf = @($col | Where-Object { $_.dentro_area -eq 'A CONFIRMAR' }).Count
$nLim = @($col | Where-Object { $_.dentro_area -eq 'LIMITE' }).Count
$nSim = @($col | Where-Object { $_.dentro_area -eq 'SIM' }).Count
$nNao = @($col | Where-Object { $_.dentro_area -eq 'NAO' }).Count
Write-Output ("total={0} SIM={1} LIMITE={2} ({3:P2}) A CONFIRMAR={4} ({5:P2}) NAO={6}" -f $n, $nSim, $nLim, ($nLim / $n), $nConf, ($nConf / $n), $nNao)
$naoVazio = @($col | Where-Object { $_.dentro_area -eq 'NAO' -or $_.dentro_area -eq 'SIM' -or $_.dentro_area -eq 'LIMITE' -or $_.dentro_area -eq 'A CONFIRMAR' }).Count
Write-Output ("linhas com dentro_area fora dos 4 valores: {0}" -f ($n - $naoVazio))
Write-Output 'motivo_area dos A CONFIRMAR (grupos):'
$col | Where-Object { $_.dentro_area -eq 'A CONFIRMAR' } | Group-Object { ($_.motivo_area -replace '\d+(\.\d+)? m', 'N m') } | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { Write-Output ("  {0,4}  {1}" -f $_.Count, $_.Name) }
Write-Output 'motivo_area dos LIMITE (grupos):'
$col | Where-Object { $_.dentro_area -eq 'LIMITE' } | Group-Object { ($_.motivo_area -replace '\d+(\.\d+)? m', 'N m') } | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { Write-Output ("  {0,4}  {1}" -f $_.Count, $_.Name) }
Write-Output 'motivo_area dos SIM (grupos):'
$col | Where-Object { $_.dentro_area -eq 'SIM' } | Group-Object { ($_.motivo_area -replace '\d+(\.\d+)? m', 'N m') } | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { Write-Output ("  {0,4}  {1}" -f $_.Count, $_.Name) }
Write-Output 'geocodificacao: linhas com motivo "geocodificado": '
Write-Output ("  {0}" -f @($col | Where-Object { $_.motivo_area -match 'geocodificad' }).Count)
Write-Output ("  sem coordenada (lat vazio): {0}" -f @($col | Where-Object { $_.lat -eq '' }).Count)
# SIM/LIMITE/A CONFIRMAR por bairro_site e por fonte
Write-Output 'dentro_area x fonte:'
$col | Group-Object fonte, dentro_area | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-26} {1}" -f $_.Name, $_.Count) }
Write-Output 'dentro_area x bairro (coluna bairro, so != NAO):'
$col | Where-Object { $_.dentro_area -ne 'NAO' } | Group-Object bairro, dentro_area | Sort-Object Name | ForEach-Object { Write-Output ("  {0,-34} {1}" -f $_.Name, $_.Count) }

# ---------- item 9: duplicatas ----------
Sec 'ITEM 9 - duplicatas'
$grupos = @($col | Where-Object { $_.duplicata_grupo -ne '' } | Group-Object duplicata_grupo)
$gD = @($grupos | Where-Object { $_.Name -like 'D*' }); $gP = @($grupos | Where-Object { $_.Name -like 'P*' })
Write-Output ("grupos D={0}  grupos P={1}  linhas em grupo={2}" -f $gD.Count, $gP.Count, @($col | Where-Object { $_.duplicata_grupo -ne '' }).Count)
Write-Output ("grupos com 1 linha so: {0}" -f @($grupos | Where-Object { $_.Count -eq 1 }).Count)
# conferencia automatica de todos os grupos D: mesma rua+numero (ou CEP), area +-2, preco +-2%
$ruim = New-Object System.Collections.Generic.List[string]
foreach ($g in $gD) {
    $m = @($g.Group)
    $ruas = @($m | ForEach-Object { ($_.rua.ToLowerInvariant().Trim() + '#' + $_.numero.Trim()) } | Select-Object -Unique)
    $ceps = @($m | ForEach-Object { $_.cep } | Select-Object -Unique)
    $ar = $m | ForEach-Object { [double]::Parse($_.area_util, $inv) } | Measure-Object -Minimum -Maximum
    $pr = $m | ForEach-Object { [double]::Parse($_.preco, $inv) } | Measure-Object -Minimum -Maximum
    $okEnd = ($ruas.Count -eq 1) -or ($ceps.Count -eq 1 -and $ceps[0] -ne '')
    $okArea = ($ar.Maximum - $ar.Minimum) -le 4.0001   # pares a +-2 do pivo podem distar 4 entre si
    $okPreco = ($pr.Maximum - $pr.Minimum) -le (0.0404 * $pr.Minimum)
    if (-not ($okEnd -and $okArea -and $okPreco)) { $ruim.Add(("{0}: end_ok={1} area {2}-{3} preco {4}-{5}" -f $g.Name, $okEnd, $ar.Minimum, $ar.Maximum, $pr.Minimum, $pr.Maximum)) }
}
Write-Output ("grupos D que violam a regra (largura > 2x tolerancia): {0}" -f $ruim.Count)
$ruim | Select-Object -First 10 | ForEach-Object { Write-Output "   $_" }
# sorteio de 2 grupos (1 D + 1 P) com semente fixa
$rnd = New-Object System.Random(20261011)
$sD = $gD[$rnd.Next($gD.Count)]; $sP = $gP[$rnd.Next($gP.Count)]
foreach ($g in @($sD, $sP)) {
    Write-Output ("-- grupo {0} ({1} linhas)" -f $g.Name, $g.Count)
    $g.Group | ForEach-Object { Write-Output ("   {0,-24} {1,-11} rua='{2}' n={3} cep={4} area={5} preco={6} q={7} v={8} fonte={9}" -f $_.chave, $_.dentro_area, $_.rua, $_.numero, $_.cep, $_.area_util, $_.preco, $_.quartos, $_.vagas, $_.fonte) }
}

# ---------- sorteios para itens 4, 6, 7 ----------
Sec 'SORTEIOS (semente 20261011)'
$rnd = New-Object System.Random(20261011)
function Sortear($lista, $k) { $l = @($lista); $idx = @(); while ($idx.Count -lt $k -and $idx.Count -lt $l.Count) { $i = $rnd.Next($l.Count); if ($idx -notcontains $i) { $idx += $i } }; return @($idx | ForEach-Object { $l[$_] }) }
$am = @{}
foreach ($f in 'VIVAREAL', 'QUINTOANDAR', 'CHAVESNAMAO') { $am[$f] = Sortear ($col | Where-Object { $_.fonte -eq $f }) 2 }
$sim5 = Sortear ($col | Where-Object { $_.dentro_area -eq 'SIM' }) 5
$nao4 = Sortear ($col | Where-Object { $_.dentro_area -eq 'NAO' }) 4
$campos = 'chave', 'fonte', 'codigo', 'link', 'tipo', 'rua', 'numero', 'cep', 'bairro_site', 'lat', 'lon', 'precisao_coord', 'preco', 'area_util', 'area_total', 'condominio_mes', 'iptu_mes', 'iptu_informado', 'quartos', 'banheiros', 'suites', 'vagas', 'andar', 'anunciante', 'publicado_em', 'atualizado_em', 'dentro_area', 'motivo_area', 'poligono', 'bairro', 'duplicata_grupo'
Write-Output '## item 4 (fidelidade): 2 por fonte'
foreach ($f in 'VIVAREAL', 'QUINTOANDAR', 'CHAVESNAMAO') { foreach ($r in $am[$f]) { Write-Output ('  ' + (($campos | ForEach-Object { "$_=" + $r.$_ }) -join ' | ')) } }
Write-Output '## item 6 (SIM): 5 linhas'
foreach ($r in $sim5) { Write-Output ('  ' + (($campos | ForEach-Object { "$_=" + $r.$_ }) -join ' | ')) }
Write-Output '## item 7 (NAO): 4 linhas'
foreach ($r in $nao4) { Write-Output ('  ' + (($campos | ForEach-Object { "$_=" + $r.$_ }) -join ' | ')) }
# grava as amostras em CSV para os passos seguintes
$todas = @()
foreach ($f in 'VIVAREAL', 'QUINTOANDAR', 'CHAVESNAMAO') { foreach ($r in $am[$f]) { $todas += [pscustomobject]@{ item = 4; chave = $r.chave } } }
foreach ($r in $sim5) { $todas += [pscustomobject]@{ item = 6; chave = $r.chave } }
foreach ($r in $nao4) { $todas += [pscustomobject]@{ item = 7; chave = $r.chave } }
$todas | Export-Csv -Path (Join-Path $saida 'amostras.csv') -Delimiter ';' -NoTypeInformation -Encoding UTF8
Write-Output ("amostras gravadas em {0}" -f (Join-Path $saida 'amostras.csv'))

# ---------- item 7 extra: ruas claramente incluidas marcadas NAO ----------
Sec 'ITEM 7 extra - ruas incluidas marcadas NAO (varredura)'
$ruasInc = @(Import-Csv -Path (Join-Path $raiz 'Listagem das ruas\ruas.csv') -Delimiter ';' -Encoding UTF8)
Write-Output ("ruas.csv: {0} linhas; situacoes: {1}" -f $ruasInc.Count, (($ruasInc | Group-Object situacao | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '))
$naoPorRua = $col | Where-Object { $_.dentro_area -eq 'NAO' } | Group-Object rua | Sort-Object Count -Descending
Write-Output 'top 25 ruas com NAO:'
$naoPorRua | Select-Object -First 25 | ForEach-Object { Write-Output ("  {0,4}  {1}" -f $_.Count, $_.Name) }
Write-Output 'NAO em Visconde de Piraja / Ataulfo de Paiva / Vieira Souto / Delfim Moreira / Prudente de Morais (motivos):'
$col | Where-Object { $_.dentro_area -eq 'NAO' -and ($_.rua -match 'Visconde de Piraj|Ataulfo de Paiva|Vieira Souto|Delfim Moreira|Prudente de Mora') } | Group-Object rua, motivo_area | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { Write-Output ("  {0,4}  {1}" -f $_.Count, $_.Name) }
