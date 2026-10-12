# compare.ps1 - itens 6, 7, 8, 10 (recalculo) e 11 (links) + passada COM curta (HasFormula literal, cores da legenda)
$ErrorActionPreference = 'Stop'
$raiz = 'D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra'
$dados = "$raiz\_dados\2026-10-11"
$saida = "$dados\chequer-planilha-r1"
$xlsx = "$raiz\Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx"
$rodada = '2026-10-11'
$inv = [Globalization.CultureInfo]::InvariantCulture

$base = @(Import-Csv "$raiz\_dados\base.csv" -Delimiter ';' -Encoding UTF8)
$pl   = @(Import-Csv "$saida\imoveis-valores.csv" -Delimiter ';' -Encoding UTF8)
$pf   = @(Import-Csv "$saida\imoveis-formulas.csv" -Delimiter ';' -Encoding UTF8)
$pc   = @(Get-Content "$saida\imoveis-cores.csv" -Encoding UTF8 | Select-Object -Skip 1)
"base: $($base.Count) | planilha valores: $($pl.Count) | formulas: $($pf.Count) | cores: $($pc.Count)"
$colsPl = @($pl[0].PSObject.Properties.Name)
function P($row, $letra) { $n = $colsPl | Where-Object { $_ -like "${letra}_*" } | Select-Object -First 1; return "$($row.$n)" }

# ---- Item 6: chaves nos dois sentidos
$bIdx = @{}; foreach ($b in $base) { $bIdx[$b.chave] = $b }
$pIdx = @{}; $dupPl = @()
for ($i = 0; $i -lt $pl.Count; $i++) { $k = P $pl[$i] 'AF'; if ($pIdx.ContainsKey($k)) { $dupPl += $k } else { $pIdx[$k] = $i } }
$semBase = @($pIdx.Keys | Where-Object { -not $bIdx.ContainsKey($_) })
$semPl = @($bIdx.Keys | Where-Object { -not $pIdx.ContainsKey($_) })
"ITEM6 linhas planilha=$($pl.Count) base=$($base.Count) | CHAVE duplicada na planilha: $($dupPl.Count) | chave da planilha sem base: $($semBase.Count) | chave da base sem planilha: $($semPl.Count)"

function MapBairro($b) { if ($b -eq 'Ipanema/Arpoador') { return 'Arpoador (Copacabana)' }; return $b }
function MapFonte($f) { switch ($f) { 'VIVAREAL' { 'VivaReal/Zap' } 'QUINTOANDAR' { 'QuintoAndar' } 'CHAVESNAMAO' { 'Chaves na Mão' } default { $f } } }
function MapEnd($b) { if ($b.rua -eq '') { return '(endereço não informado)' }; if ($b.numero -eq '') { return "$($b.rua), s/nº" }; return "$($b.rua), $($b.numero)" }
function MapStatus($b) { if ($b.status -eq 'ATIVO' -and $b.primeira_captura -eq $rodada) { return 'NOVO' }; return $b.status }
function UrlDeHyperlink($f) { if ($f -match '^=HYPERLINK\("([^"]*)"') { return $matches[1] }; return '' }
function NumEq($a, $b) { if ($a -eq '' -and $b -eq '') { return $true }; if ($a -eq '' -or $b -eq '') { return $false }; return [math]::Abs([double]::Parse($a, $inv) - [double]::Parse($b, $inv)) -lt 0.001 }
function DataEq($pl, $b) { if ($pl -eq '' -and $b -eq '') { return $true }; return $pl.StartsWith($b) }

# comparacao de TODAS as linhas nos campos da rubrica (+ CHAVE, CEP, TIPO, fonte, ult. verificacao, link zap)
$dif = @{}; $exemplos = @()
$campos = @('PRECO','AREA','CONDOMINIO','IPTU','BAIRRO','ENDERECO','LINK','STATUS','1A_CAPTURA','ULT_VERIF','FONTE','CEP','TIPO','LINK_ZAP','QUARTOS','VAGAS','DESCRICAO')
foreach ($c in $campos) { $dif[$c] = 0 }
for ($i = 0; $i -lt $pl.Count; $i++) {
  $r = $pl[$i]; $f = $pf[$i]; $k = P $r 'AF'; if (-not $bIdx.ContainsKey($k)) { continue }; $b = $bIdx[$k]
  $t = @{}
  $t['PRECO'] = NumEq (P $r 'I') $b.preco
  $t['AREA'] = NumEq (P $r 'J') $b.area_util
  $t['CONDOMINIO'] = NumEq (P $r 'L') $b.condominio_mes
  $t['IPTU'] = NumEq (P $r 'M') $b.iptu_mes
  $t['BAIRRO'] = ((P $r 'E') -eq (MapBairro $b.bairro))
  $t['ENDERECO'] = ((P $r 'F') -eq (MapEnd $b))
  $t['LINK'] = ((UrlDeHyperlink (P $f 'AD')) -eq $b.link)
  $t['STATUS'] = ((P $r 'B') -eq (MapStatus $b))
  $t['1A_CAPTURA'] = (DataEq (P $r 'V') $b.primeira_captura)
  $t['ULT_VERIF'] = (DataEq (P $r 'W') $b.ultima_verificacao)
  $t['FONTE'] = ((P $r 'D') -eq (MapFonte $b.fonte))
  $t['CEP'] = ((P $r 'G') -eq $b.cep)
  $t['TIPO'] = ((P $r 'H') -eq $b.tipo)
  $t['LINK_ZAP'] = ((UrlDeHyperlink (P $f 'AE')) -eq $b.link_alt)
  $t['QUARTOS'] = NumEq (P $r 'O') $b.quartos
  $t['VAGAS'] = NumEq (P $r 'Q') $b.vagas
  $t['DESCRICAO'] = ((P $r 'AG') -eq $b.descricao_resumo)
  foreach ($c in $campos) { if (-not $t[$c]) { $dif[$c]++; if ($exemplos.Count -lt 12) { $exemplos += "linha $($i+5) $k ${c}: planilha='" + $(switch ($c) { 'LINK' { UrlDeHyperlink (P $f 'AD') } 'LINK_ZAP' { UrlDeHyperlink (P $f 'AE') } 'ENDERECO' { P $r 'F' } 'BAIRRO' { P $r 'E' } 'STATUS' { P $r 'B' } 'DESCRICAO' { (P $r 'AG').Substring(0, [math]::Min(40, (P $r 'AG').Length)) } 'CEP' { P $r 'G' } 'TIPO' { P $r 'H' } 'FONTE' { P $r 'D' } 'QUARTOS' { P $r 'O' } 'VAGAS' { P $r 'Q' } default { 'n/d' } }) + "' base='" + $(switch ($c) { 'LINK' { $b.link } 'LINK_ZAP' { $b.link_alt } 'ENDERECO' { "$($b.rua)|$($b.numero)" } 'BAIRRO' { $b.bairro } 'STATUS' { "$($b.status)/$($b.primeira_captura)" } 'DESCRICAO' { $b.descricao_resumo.Substring(0, [math]::Min(40, $b.descricao_resumo.Length)) } 'CEP' { $b.cep } 'TIPO' { $b.tipo } 'FONTE' { $b.fonte } 'QUARTOS' { $b.quartos } 'VAGAS' { $b.vagas } default { 'n/d' } }) + "'" } } }
}
"ITEM6 divergencias em todas as $($pl.Count) linhas: " + (($campos | ForEach-Object { "$_=$($dif[$_])" }) -join ' | ')
if ($exemplos.Count) { "ITEM6 exemplos: " + ($exemplos -join ' || ') }

# ---- sorteio das 8 linhas (semente fixa para reproducao)
$sorteio = @(Get-Random -SetSeed 20261011 -InputObject (5..1025) -Count 8 | Sort-Object)
"SORTEIO (semente 20261011): linhas " + ($sorteio -join ', ')
foreach ($lin in $sorteio) {
  $i = $lin - 5; $r = $pl[$i]; $f = $pf[$i]; $k = P $r 'AF'; $b = $bIdx[$k]
  $kval = P $r 'K'; $nval = P $r 'N'
  $kEsp = [double]::Parse($b.preco, $inv) / [double]::Parse($b.area_util, $inv)
  $nEsp = ''; if ($b.condominio_mes -ne '' -or $b.iptu_mes -ne '') { $s = 0.0; if ($b.condominio_mes -ne '') { $s += [double]::Parse($b.condominio_mes, $inv) }; if ($b.iptu_mes -ne '') { $s += [double]::Parse($b.iptu_mes, $inv) }; $nEsp = $s.ToString($inv) }
  $kOk = [math]::Abs([double]::Parse($kval, $inv) - $kEsp) -lt 0.001
  $nOk = NumEq $nval $nEsp
  "L$lin CHAVE=$k | PRECO pl=" + (P $r 'I') + " base=$($b.preco) | AREA pl=" + (P $r 'J') + " base=$($b.area_util) | COND pl='" + (P $r 'L') + "' base='$($b.condominio_mes)' | IPTU pl='" + (P $r 'M') + "' base='$($b.iptu_mes)' | BAIRRO pl='" + (P $r 'E') + "' base='$($b.bairro)' | END pl='" + (P $r 'F') + "' base='$($b.rua)|$($b.numero)' | STATUS pl=" + (P $r 'B') + " base=$($b.status)/$($b.primeira_captura) | 1aCAPT pl=" + (P $r 'V') + " base=$($b.primeira_captura) | LINK igual=" + ((UrlDeHyperlink (P $f 'AD')) -eq $b.link) + " (" + (UrlDeHyperlink (P $f 'AD')) + ")"
  "   ITEM7 K$lin formula='" + (P $f 'K') + "' valor=$kval esperado=" + $kEsp.ToString($inv) + " ok=$kOk | N$lin formula='" + (P $f 'N') + "' valor='$nval' esperado='$nEsp' ok=$nOk"
}

# ---- Item 7: formulas em todas as linhas (valor correto)
$kErr = 0; $nErr = 0; $kSemF = 0; $nSemF = 0
for ($i = 0; $i -lt $pl.Count; $i++) {
  $r = $pl[$i]; $f = $pf[$i]; $k = P $r 'AF'; $b = $bIdx[$k]
  if (-not (P $f 'K').StartsWith('=')) { $kSemF++ }
  if (-not (P $f 'N').StartsWith('=')) { $nSemF++ }
  $kEsp = [double]::Parse($b.preco, $inv) / [double]::Parse($b.area_util, $inv)
  if ([math]::Abs([double]::Parse((P $r 'K'), $inv) - $kEsp) -ge 0.001) { $kErr++ }
  $nEsp = ''; if ($b.condominio_mes -ne '' -or $b.iptu_mes -ne '') { $s = 0.0; if ($b.condominio_mes -ne '') { $s += [double]::Parse($b.condominio_mes, $inv) }; if ($b.iptu_mes -ne '') { $s += [double]::Parse($b.iptu_mes, $inv) }; $nEsp = $s.ToString($inv) }
  if (-not (NumEq (P $r 'N') $nEsp)) { $nErr++ }
}
"ITEM7 todas as linhas: K sem formula=$kSemF | K valor errado=$kErr | N sem formula=$nSemF | N valor errado=$nErr"

# ---- Item 8: ordem e cores
$rank = @{ 'NOVO' = 0; 'ATIVO' = 0; 'FORA DOS CRITÉRIOS' = 1; 'REMOVIDO' = 2 }
$ordemErr = 0; $prev = -1
for ($i = 0; $i -lt $pl.Count; $i++) { $s = P $pl[$i] 'B'; $rk = $rank[$s]; if ($null -eq $rk) { $rk = 9 }; if ($rk -lt $prev) { $ordemErr++ }; $prev = $rk }
"ITEM8 ordem: quebras de ordem (ATIVO -> FORA -> REMOVIDO) = $ordemErr | sequencia de STATUS: " + (($pl | ForEach-Object { P $_ 'B' } | Group-Object | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join ', ')
# cores: coluna B (indice 1) para NOVO; coluna C (indice 2) para LIMITE/A CONFIRMAR; restante sem preenchimento
$corB = @{}; $corC_lim = @{}; $corC_sim = @{}; $outrasCols = @{}
for ($i = 0; $i -lt $pl.Count; $i++) {
  $cels = $pc[$i] -split ';'
  $s = P $pl[$i] 'B'; $a = P $pl[$i] 'C'
  $cb = ($cels[1] -split '/')[0]; $key = "$s=$cb"; if ($corB.ContainsKey($key)) { $corB[$key]++ } else { $corB[$key] = 1 }
  $cc = ($cels[2] -split '/')[0] + '/' + ($cels[2] -split '/')[1]
  if ($a -eq 'SIM') { if ($corC_sim.ContainsKey($cc)) { $corC_sim[$cc]++ } else { $corC_sim[$cc] = 1 } } else { $key2 = "$a=$cc"; if ($corC_lim.ContainsKey($key2)) { $corC_lim[$key2]++ } else { $corC_lim[$key2] = 1 } }
  for ($c = 0; $c -lt $cels.Count; $c++) { if ($c -in @(1,2)) { continue }; $p = ($cels[$c] -split '/'); $cc2 = $p[0] + '/' + $p[1]; if ($outrasCols.ContainsKey($cc2)) { $outrasCols[$cc2]++ } else { $outrasCols[$cc2] = 1 } }
}
"ITEM8 preenchimento col B (STATUS) por valor=cor: " + (($corB.Keys | Sort-Object | ForEach-Object { "$_ -> $($corB[$_])" }) -join ' | ')
"ITEM8 preenchimento col C (AREA) LIMITE/A CONFIRMAR por valor=cor/padrao: " + (($corC_lim.Keys | Sort-Object | ForEach-Object { "$_ -> $($corC_lim[$_])" }) -join ' | ')
"ITEM8 preenchimento col C (AREA) SIM por cor/padrao: " + (($corC_sim.Keys | Sort-Object | ForEach-Object { "$_ -> $($corC_sim[$_])" }) -join ' | ')
"ITEM8 preenchimento das demais colunas (cor/padrao -> celulas): " + (($outrasCols.Keys | Sort-Object | ForEach-Object { "$_ -> $($outrasCols[$_])" }) -join ' | ')

# ---- Item 10: RESUMO recalculado (so ATIVO em area SIM)
function Mediana($arr) { $s = @($arr | Sort-Object); $n = $s.Count; if ($n -eq 0) { return $null }; if ($n % 2 -eq 1) { return $s[[int][math]::Floor($n/2)] } else { return ($s[$n/2 - 1] + $s[$n/2]) / 2 } }
$sim = @($base | Where-Object { $_.status -eq 'ATIVO' -and $_.dentro_area -eq 'SIM' })
"ITEM10 ATIVO em SIM: $($sim.Count)"
foreach ($g in (($sim | Group-Object bairro | Sort-Object Name) + @([pscustomobject]@{ Name = 'TODOS'; Group = $sim; Count = $sim.Count }))) {
  $m2 = @($g.Group | ForEach-Object { [double]::Parse($_.preco, $inv) / [double]::Parse($_.area_util, $inv) })
  $precos = @($g.Group | ForEach-Object { [double]::Parse($_.preco, $inv) })
  $areas = @($g.Group | ForEach-Object { [double]::Parse($_.area_util, $inv) })
  "ITEM10 R$/m2 SIM " + (MapBairro $g.Name) + ": qtd=$($g.Count) min=" + [math]::Round((($m2 | Measure-Object -Minimum).Minimum), 2) + " mediana=" + [math]::Round((Mediana $m2), 2) + " max=" + [math]::Round((($m2 | Measure-Object -Maximum).Maximum), 2) + " preco_mediano=" + (Mediana $precos) + " area_mediana=" + (Mediana $areas)
}
# 10 menores R$/m2 (ATIVO) recalculados
$top = @($base | Where-Object { $_.status -eq 'ATIVO' } | ForEach-Object { [pscustomobject]@{ chave = $_.chave; m2 = [double]::Parse($_.preco, $inv) / [double]::Parse($_.area_util, $inv); preco = $_.preco; area = $_.area_util; bairro = (MapBairro $_.bairro); end = (MapEnd $_); fonte = (MapFonte $_.fonte); n = ($pIdx[$_.chave] + 1) } } | Sort-Object m2, chave | Select-Object -First 10)
"ITEM10 10 menores R$/m2 recalculados: " + (($top | ForEach-Object { "$($_.n):$($_.end)/$($_.bairro)/$($_.preco)/$($_.area)/" + [math]::Round($_.m2, 0) }) -join ' | ')
# novos: contagem com marca NOVO x resumo
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
$j = $js.DeserializeObject([IO.File]::ReadAllText("$dados\resumo-rodada.json"))
"ITEM10 resumo-rodada.json: coletados_na_area VIVAREAL=$($j['coletados_na_area']['VIVAREAL']) QUINTOANDAR=$($j['coletados_na_area']['QUINTOANDAR']) CHAVESNAMAO=$($j['coletados_na_area']['CHAVESNAMAO']) | novos=$($j['novos']) removidos=$($j['removidos']) preco_alterado=$($j['preco_alterado']) total_ativo=$($j['total_ativo']) | observacao='$($j['observacao'])'"
$hist = @(Get-Content "$saida\aba3-HIST_RICO_RODADAS-valores.csv" -Encoding UTF8)
"ITEM10 HISTORICO linha 5 (bruta): " + $hist[5] + " | A5 serial " + (($hist[5] -split ';')[0] -replace '"','') + " = " + ([DateTime]::FromOADate([double](($hist[5] -split ';')[0] -replace '"',''))).ToString('yyyy-MM-dd')

# ---- Item 11: links (sorteio estratificado: 3 VivaReal, 1 QuintoAndar, 1 Chaves na Mao)
$curl = "$env:SystemRoot\System32\curl.exe"
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$porFonte = @{}
for ($i = 0; $i -lt $pl.Count; $i++) { $fnt = P $pl[$i] 'D'; if (-not $porFonte.ContainsKey($fnt)) { $porFonte[$fnt] = @() }; $porFonte[$fnt] += $i }
$amostraLinks = @()
$amostraLinks += @(Get-Random -SetSeed 1011 -InputObject $porFonte['VivaReal/Zap'] -Count 3)
$amostraLinks += @(Get-Random -SetSeed 1012 -InputObject $porFonte['QuintoAndar'] -Count 1)
$amostraLinks += @(Get-Random -SetSeed 1013 -InputObject $porFonte['Chaves na Mão'] -Count 1)
foreach ($i in $amostraLinks) {
  $r = $pl[$i]; $f = $pf[$i]; $url = UrlDeHyperlink (P $f 'AD')
  if ($url -eq '') { "ITEM11 L$($i+5) " + (P $r 'AF') + " LINK VAZIO"; continue }
  $res = & $curl -s -o NUL -w "%{http_code} %{url_effective}" -L --max-time 40 -A $ua $url 2>&1
  "ITEM11 L$($i+5) " + (P $r 'AF') + " STATUS=" + (P $r 'B') + " -> HTTP " + $res + " | url=" + $url
  Start-Sleep -Milliseconds 400
}

# ---- passada COM curta: HasFormula literal nas 8 linhas sorteadas, legenda, D2
$pidsAntes = @(Get-Process excel -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$excel = $null; $wb = $null
try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false; $excel.DisplayAlerts = $false
  $wb = $excel.Workbooks.Open($xlsx, 0, $true)
  $ws = $wb.Worksheets.Item(1)
  "COM ReadOnly=" + $wb.ReadOnly
  "COM D2: Value2=" + $ws.Range('D2').Value2 + " Text='" + $ws.Range('D2').Text + "' NumberFormat='" + $ws.Range('D2').NumberFormat + "' | A2='" + $ws.Range('A2').Text + "' | A2:D2 mesclado=" + $ws.Range('A2').MergeCells + " | B2 mesclado=" + $ws.Range('B2').MergeCells + " MergeArea=" + $ws.Range('B2').MergeArea.Address($false,$false)
  foreach ($cel in @('G3','H3','J3','L3','M3','O3')) { $c = $ws.Range($cel); "COM legenda ${cel}='" + $c.Text + "' Interior.Color=" + $c.Interior.Color + " Pattern=" + $c.Interior.Pattern + " Font.Color=" + $c.Font.Color }
  foreach ($lin in $sorteio) { "COM L${lin}: K.HasFormula=" + $ws.Range("K$lin").HasFormula + " K.Text='" + $ws.Range("K$lin").Text + "' | N.HasFormula=" + $ws.Range("N$lin").HasFormula + " N.Text='" + $ws.Range("N$lin").Text + "' | I.Text='" + $ws.Range("I$lin").Text + "' | V.Text='" + $ws.Range("V$lin").Text + "' | AD.HasFormula=" + $ws.Range("AD$lin").HasFormula + " AD.Text='" + $ws.Range("AD$lin").Text + "' | B.Interior.Color=" + $ws.Range("B$lin").Interior.Color + " C.Text='" + $ws.Range("C$lin").Text + "' C.Interior.Color=" + $ws.Range("C$lin").Interior.Color }
  $wr = $wb.Worksheets.Item(2); "COM RESUMO B2 Text='" + $wr.Range('B2').Text + "' B8 Text='" + $wr.Range('B8').Text + "' B9='" + $wr.Range('B9').Text + "' B10='" + $wr.Range('B10').Text + "' B11='" + $wr.Range('B11').Text + "' B34='" + $wr.Range('B34').Text + "' D34='" + $wr.Range('D34').Text + "'"
  $wh = $wb.Worksheets.Item(3); "COM HISTORICO A5 Text='" + $wh.Range('A5').Text + "' NumberFormat='" + $wh.Range('A5').NumberFormat + "'"
}
finally {
  if ($wb) { $wb.Close($false); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
  if ($excel) { $excel.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
  [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  Start-Sleep -Milliseconds 2000
  $pidsDepois = @(Get-Process excel -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
  $orfaos = @($pidsDepois | Where-Object { $_ -notin $pidsAntes })
  "COM EXCEL.EXE depois: " + $(if ($pidsDepois.Count) { $pidsDepois -join ',' } else { 'nenhum' }) + " | orfaos: " + $(if ($orfaos.Count) { ($orfaos -join ',') } else { 'nenhum' })
  foreach ($p in $orfaos) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue; "  matei EXCEL.EXE $p" }
}
"xlsx apos: " + (Get-Item $xlsx).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + " | SHA256 " + (Get-FileHash $xlsx -Algorithm SHA256).Hash.Substring(0,12)
