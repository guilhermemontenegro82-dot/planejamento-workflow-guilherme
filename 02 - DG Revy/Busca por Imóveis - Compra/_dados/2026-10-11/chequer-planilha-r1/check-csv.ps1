# check-csv.ps1 - itens 2 e 3 da rubrica + contagens para o RESUMO (item 10)
$ErrorActionPreference = 'Stop'
$raiz = 'D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra'
$dados = "$raiz\_dados\2026-10-11"
$saida = "$dados\chequer-planilha-r1"
$rodada = '2026-10-11'

$coleta = @(Import-Csv "$dados\coleta.csv" -Delimiter ';' -Encoding UTF8)
$base   = @(Import-Csv "$raiz\_dados\base.csv" -Delimiter ';' -Encoding UTF8)
"coleta.csv: $($coleta.Count) linhas | base.csv: $($base.Count) linhas"

# indice da base por chave
$idx = @{}
$dup = @()
foreach ($r in $base) { if ($idx.ContainsKey($r.chave)) { $dup += $r.chave } else { $idx[$r.chave] = $r } }
"chaves duplicadas na base: $($dup.Count)" + $(if ($dup.Count) { ' -> ' + ($dup -join ', ') } else { '' })

# ---- Item 2: coleta (dentro_area != NAO) -> base ATIVO, ultima_verificacao = rodada
$dentro = @($coleta | Where-Object { $_.dentro_area -ne 'NAO' })
$naoCol = @($coleta | Where-Object { $_.dentro_area -eq 'NAO' })
"coleta dentro_area != NAO: $($dentro.Count) | = NAO: $($naoCol.Count)"
$faltam = @(); $statusErr = @(); $verifErr = @()
foreach ($r in $dentro) {
  if (-not $idx.ContainsKey($r.chave)) { $faltam += $r.chave; continue }
  $b = $idx[$r.chave]
  if ($b.status -ne 'ATIVO') { $statusErr += "$($r.chave)=$($b.status)" }
  if ($b.ultima_verificacao -ne $rodada) { $verifErr += "$($r.chave)=$($b.ultima_verificacao)" }
}
"ITEM2 chaves da coleta faltando na base: $($faltam.Count)" + $(if ($faltam.Count) { ' -> ' + (($faltam | Select-Object -First 10) -join ', ') } else { '' })
"ITEM2 status != ATIVO: $($statusErr.Count)" + $(if ($statusErr.Count) { ' -> ' + (($statusErr | Select-Object -First 10) -join ', ') } else { '' })
"ITEM2 ultima_verificacao != ${rodada}: $($verifErr.Count)" + $(if ($verifErr.Count) { ' -> ' + (($verifErr | Select-Object -First 10) -join ', ') } else { '' })
# base nao pode ter chave que nao esteja na coleta (primeira rodada) nem chave com dentro_area = NAO
$colIdx = @{}; foreach ($r in $coleta) { $colIdx[$r.chave] = $r }
$extra = @($base | Where-Object { -not $colIdx.ContainsKey($_.chave) })
$naoNaBase = @($base | Where-Object { $_.dentro_area -eq 'NAO' })
"ITEM2 chaves da base que nao estao na coleta: $($extra.Count)"
"ITEM2 linhas da base com dentro_area = NAO: $($naoNaBase.Count)"
# campos da base iguais aos da coleta (preco, area_util, link, bairro, dentro_area) para todas as chaves
$difCampos = 0; $exDif = @()
foreach ($b in $base) {
  if (-not $colIdx.ContainsKey($b.chave)) { continue }
  $c = $colIdx[$b.chave]
  foreach ($f in @('preco','area_util','link','bairro','dentro_area','condominio_mes','iptu_mes','rua','numero','fonte')) {
    if ("$($b.$f)" -ne "$($c.$f)") { $difCampos++; if ($exDif.Count -lt 8) { $exDif += "$($b.chave).$f base='$($b.$f)' coleta='$($c.$f)'" } }
  }
}
"ITEM2 campos divergentes base x coleta (10 campos x $($base.Count) linhas): $difCampos" + $(if ($exDif.Count) { ' -> ' + ($exDif -join ' | ') } else { '' })

# ---- Item 3: novos
$pc = @($base | Where-Object { $_.primeira_captura -eq $rodada })
$pcOutros = @($base | Where-Object { $_.primeira_captura -ne $rodada })
"ITEM3 primeira_captura = ${rodada}: $($pc.Count) de $($base.Count) | diferentes: $($pcOutros.Count)" + $(if ($pcOutros.Count) { ' -> ' + (($pcOutros | Select-Object -First 5 | ForEach-Object { "$($_.chave)=$($_.primeira_captura)" }) -join ', ') } else { '' })
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
$j = $js.DeserializeObject([IO.File]::ReadAllText("$dados\resumo-rodada.json"))
$listaNovos = @($j['listas']['novos'])
"ITEM3 resumo.novos = $($j['novos']) | lista novos = $($listaNovos.Count) itens"
$setNovos = @{}; foreach ($k in $listaNovos) { $setNovos[$k] = 1 }
$naoNaLista = @($base | Where-Object { -not $setNovos.ContainsKey($_.chave) })
$listaSemBase = @($listaNovos | Where-Object { -not $idx.ContainsKey($_) })
"ITEM3 chaves da base fora da lista novos: $($naoNaLista.Count) | itens da lista sem base: $($listaSemBase.Count)"
# campos de rodada coerentes
$hp = @($base | Where-Object { $_.historico_precos -ne "${rodada}:$($_.preco)" })
"ITEM3/5 historico_precos != '<rodada>:<preco>': $($hp.Count)" + $(if ($hp.Count) { ' -> ' + (($hp | Select-Object -First 5 | ForEach-Object { "$($_.chave) hp='$($_.historico_precos)' preco=$($_.preco)" }) -join ' | ') } else { '' })
$rem = @($base | Where-Object { $_.removido_em -ne '' -or $_.status -eq 'REMOVIDO' })
$pa  = @($base | Where-Object { $_.preco_anterior -ne '' -or $_.preco_alterado_em -ne '' })
"ITEM4 removidos na base: $($rem.Count) (resumo.removidos = $($j['removidos']))"
"ITEM5 preco_anterior/preco_alterado_em preenchidos: $($pa.Count) (resumo.preco_alterado = $($j['preco_alterado']))"
$man = @($base | Where-Object { $_.avaliacao_socios -ne '' -or $_.observacoes -ne '' })
"ITEM9 avaliacao_socios/observacoes preenchidos na base: $($man.Count)"

# ---- Contagens para o RESUMO (item 10)
"--- CONTAGENS DA BASE ---"
"status: " + (($base | Group-Object status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"dentro_area: " + (($base | Group-Object dentro_area | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"fonte: " + (($base | Group-Object fonte | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"bairro: " + (($base | Group-Object bairro | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"bairro x status: " + (($base | Group-Object bairro, status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"bairro x dentro_area: " + (($base | Group-Object bairro, dentro_area | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"bairro x fonte: " + (($base | Group-Object bairro, fonte | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"tipo: " + (($base | Group-Object tipo | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
"quartos: " + (($base | Group-Object quartos | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | ')
$inv = [Globalization.CultureInfo]::InvariantCulture
function Mediana($arr) { $s = @($arr | Sort-Object); $n = $s.Count; if ($n -eq 0) { return $null }; if ($n % 2 -eq 1) { return $s[[int][math]::Floor($n/2)] } else { return ($s[$n/2 - 1] + $s[$n/2]) / 2 } }
foreach ($g in ($base | Group-Object bairro | Sort-Object Name)) {
  $m2 = @($g.Group | ForEach-Object { [double]::Parse($_.preco, $inv) / [double]::Parse($_.area_util, $inv) })
  $precos = @($g.Group | ForEach-Object { [double]::Parse($_.preco, $inv) })
  $areas = @($g.Group | ForEach-Object { [double]::Parse($_.area_util, $inv) })
  "mediana R$/m2 $($g.Name): " + [math]::Round((Mediana $m2), 0) + " | media R$/m2: " + [math]::Round((($m2 | Measure-Object -Average).Average), 0) + " | min: " + [math]::Round((($m2 | Measure-Object -Minimum).Minimum), 0) + " | max: " + [math]::Round((($m2 | Measure-Object -Maximum).Maximum), 0) + " | mediana preco: " + (Mediana $precos) + " | mediana area: " + (Mediana $areas) + " | n=" + $g.Count
}
$m2all = @($base | ForEach-Object { [double]::Parse($_.preco, $inv) / [double]::Parse($_.area_util, $inv) })
"mediana R$/m2 geral: " + [math]::Round((Mediana $m2all), 0) + " | media: " + [math]::Round((($m2all | Measure-Object -Average).Average), 0)
$precosAll = @($base | ForEach-Object { [double]::Parse($_.preco, $inv) })
"preco min/max geral: " + ($precosAll | Measure-Object -Minimum -Maximum | ForEach-Object { "$($_.Minimum) / $($_.Maximum)" })
$areasAll = @($base | ForEach-Object { [double]::Parse($_.area_util, $inv) })
"area min/max geral: " + ($areasAll | Measure-Object -Minimum -Maximum | ForEach-Object { "$($_.Minimum) / $($_.Maximum)" })
$foraPreco = @($base | Where-Object { $p = [double]::Parse($_.preco, $inv); $p -lt 500000 -or $p -gt 1100000 })
$foraArea = @($base | Where-Object { $a = [double]::Parse($_.area_util, $inv); $a -lt 35 -or $a -gt 70 })
"fora da faixa de preco: $($foraPreco.Count) | fora da faixa de area: $($foraArea.Count)"
"duplicata_grupo preenchido: " + @($base | Where-Object { $_.duplicata_grupo -ne '' }).Count
