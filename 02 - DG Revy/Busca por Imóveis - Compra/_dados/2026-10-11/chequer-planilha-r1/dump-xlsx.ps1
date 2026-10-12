# dump-xlsx.ps1 - abre a planilha SO PARA LEITURA via Excel COM e despeja abas, formulas, cores e larguras
$ErrorActionPreference = 'Stop'
$raiz = 'D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra'
$dados = "$raiz\_dados\2026-10-11"
$saida = "$dados\chequer-planilha-r1"
$xlsx = "$raiz\Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx"
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$inv = [Globalization.CultureInfo]::InvariantCulture

$pidsAntes = @(Get-Process excel -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
"EXCEL.EXE antes: " + $(if ($pidsAntes.Count) { $pidsAntes -join ',' } else { 'nenhum' })

function ColLetter([int]$c) { $s = ''; while ($c -gt 0) { $m = ($c - 1) % 26; $s = [char](65 + $m) + $s; $c = [int][math]::Floor(($c - 1) / 26) }; return $s }
function Cel($v, $fmt) {
  if ($null -eq $v) { return '' }
  if ($v -is [double] -and $fmt -and ($fmt -match 'yy|dd|mm' ) -and ($fmt -notmatch '#|0\.0|R\$')) { return ([DateTime]::FromOADate($v)).ToString('yyyy-MM-dd HH:mm') }
  if ($v -is [double]) { return $v.ToString($inv) }
  return "$v"
}
function Dump2D($arr, $rows, $cols, $fmts, $hdr) {
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add(($hdr | ForEach-Object { '"' + "$_".Replace('"','""') + '"' }) -join ';')
  for ($r = 1; $r -le $rows; $r++) {
    $linha = New-Object System.Collections.Generic.List[string]
    for ($c = 1; $c -le $cols; $c++) { $linha.Add('"' + (Cel $arr[$r, $c] $fmts[$c - 1]).Replace('"','""') + '"') }
    $out.Add(($linha -join ';'))
  }
  return $out
}

$excel = $null; $wb = $null
try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false; $excel.DisplayAlerts = $false
  $wb = $excel.Workbooks.Open($xlsx, 0, $true)
  "ReadOnly: " + $wb.ReadOnly
  $nomes = @(); foreach ($ws in $wb.Worksheets) { $nomes += $ws.Name }
  "Abas: " + ($nomes -join ' | ')

  # ---------- IMOVEIS ----------
  $ws = $wb.Worksheets.Item(1)
  "Aba 1: " + $ws.Name
  $ur = $ws.UsedRange
  "UsedRange: " + $ur.Address($false, $false) + " | linhas=" + $ur.Rows.Count + " colunas=" + $ur.Columns.Count
  $nCols = $ur.Columns.Count
  # cabecalho (linhas 1-4)
  $topo = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(4, $nCols)).Value2
  for ($r = 1; $r -le 4; $r++) { $vals = @(); for ($c = 1; $c -le $nCols; $c++) { $v = $topo[$r, $c]; if ($null -ne $v -and "$v" -ne '') { $vals += (ColLetter $c) + "$r=" + (Cel $v $null) } }; "Linha ${r}: " + ($vals -join ' || ') }
  # celula ao lado de 'Data atualizacao:'
  for ($r = 1; $r -le 3; $r++) { for ($c = 1; $c -le $nCols; $c++) { $v = $topo[$r, $c]; if ("$v" -match 'Data atualiza') { $viz = $ws.Cells.Item($r, $c + 1); "DATA ATUALIZACAO: rotulo em " + (ColLetter $c) + "$r='" + $v + "' | vizinho " + (ColLetter ($c+1)) + "$r Value2=" + $viz.Value2 + " Text='" + $viz.Text + "' NumberFormat='" + $viz.NumberFormat + "' HasFormula=" + $viz.HasFormula + " Formula=" + $viz.Formula } } }
  $hdr = @(); for ($c = 1; $c -le $nCols; $c++) { $hdr += "$($topo[4, $c])" }
  "CABECALHO L4: " + (($hdr | ForEach-Object -Begin { $i = 0 } -Process { $i++; (ColLetter $i) + '=' + $_ }) -join ' | ')
  # ultima linha com dado na coluna da CHAVE (ou coluna A)
  $colChave = 1; for ($c = 1; $c -le $nCols; $c++) { if ($hdr[$c-1] -eq 'CHAVE') { $colChave = $c } }
  $xlUp = -4162
  $lastRow = $ws.Cells.Item($ws.Rows.Count, $colChave).End($xlUp).Row
  $lastRowA = $ws.Cells.Item($ws.Rows.Count, 1).End($xlUp).Row
  "Ultima linha com CHAVE (col " + (ColLetter $colChave) + "): $lastRow | ultima linha col A: $lastRowA | linhas de dados (5..$lastRow): " + ($lastRow - 4)
  $rng = $ws.Range($ws.Cells.Item(5,1), $ws.Cells.Item($lastRow, $nCols))
  $vals = $rng.Value2
  $forms = $rng.Formula
  $fmts = @(); for ($c = 1; $c -le $nCols; $c++) { $fmts += "$($ws.Cells.Item(5, $c).NumberFormat)" }
  "NUMBERFORMAT L5: " + (($fmts | ForEach-Object -Begin { $i = 0 } -Process { $i++; (ColLetter $i) + "='" + $_ + "'" }) -join ' | ')
  $larg = @(); for ($c = 1; $c -le $nCols; $c++) { $col = $ws.Columns.Item($c); $larg += (ColLetter $c) + '=' + [math]::Round($col.ColumnWidth, 1) + $(if ($col.Hidden) { '(OCULTA)' } else { '' }) }
  "LARGURAS: " + ($larg -join ' | ')
  $nRows = $lastRow - 4
  $hdrCsv = @(); for ($c = 1; $c -le $nCols; $c++) { $hdrCsv += (ColLetter $c) + '_' + $hdr[$c-1] }
  $linhasVal = Dump2D $vals $nRows $nCols $fmts $hdrCsv
  [IO.File]::WriteAllLines("$saida\imoveis-valores.csv", $linhasVal, $utf8bom)
  $linhasForm = Dump2D $forms $nRows $nCols @() $hdrCsv
  [IO.File]::WriteAllLines("$saida\imoveis-formulas.csv", $linhasForm, $utf8bom)
  "Gravados imoveis-valores.csv e imoveis-formulas.csv ($nRows linhas)"
  # tipos dos valores por coluna (numero x texto)
  $tipos = @(); for ($c = 1; $c -le $nCols; $c++) { $nd = 0; $ns = 0; $nv = 0; for ($r = 1; $r -le $nRows; $r++) { $v = $vals[$r, $c]; if ($null -eq $v) { $nv++ } elseif ($v -is [double]) { $nd++ } else { $ns++ } }; $tipos += (ColLetter $c) + ":num=$nd/txt=$ns/vazio=$nv" }
  "TIPOS: " + ($tipos -join ' | ')
  # formulas: contagem por coluna
  $fcount = @(); for ($c = 1; $c -le $nCols; $c++) { $nf = 0; for ($r = 1; $r -le $nRows; $r++) { if ("$($forms[$r, $c])".StartsWith('=')) { $nf++ } }; if ($nf -gt 0) { $fcount += (ColLetter $c) + "=$nf" } }
  "FORMULAS por coluna: " + ($fcount -join ' | ')
  "Hyperlinks (objetos) na aba: " + $ws.Hyperlinks.Count
  # cores de preenchimento: por linha, todas as colunas (Interior.Color)
  $cores = New-Object System.Collections.Generic.List[string]
  $cores.Add((($hdrCsv | ForEach-Object { '"' + $_ + '"' }) -join ';'))
  $sw = [Diagnostics.Stopwatch]::StartNew()
  for ($r = 5; $r -le $lastRow; $r++) {
    $linha = New-Object System.Collections.Generic.List[string]
    for ($c = 1; $c -le $nCols; $c++) { $cell = $ws.Cells.Item($r, $c); $ci = $cell.Interior; $col = $ci.Color; $pat = $ci.Pattern; $fc = $cell.Font.Color; $fb = $cell.Font.Bold; $linha.Add("$col/$pat/$fc/$fb") }
    $cores.Add(($linha -join ';'))
  }
  [IO.File]::WriteAllLines("$saida\imoveis-cores.csv", $cores, $utf8bom)
  "Gravado imoveis-cores.csv (Interior.Color/Pattern/Font.Color/Bold) em " + [math]::Round($sw.Elapsed.TotalSeconds,1) + " s"
  # cores do cabecalho
  $hc = @(); for ($c = 1; $c -le $nCols; $c++) { $hc += (ColLetter $c) + '=' + $ws.Cells.Item(4,$c).Interior.Color }
  "CORES CABECALHO L4: " + ($hc -join ' | ')
  "Congelamento/AutoFiltro: FreezePanes=" + $excel.ActiveWindow.FreezePanes + " SplitRow=" + $excel.ActiveWindow.SplitRow + " AutoFilterMode=" + $ws.AutoFilterMode

  # ---------- outras abas ----------
  for ($i = 2; $i -le $wb.Worksheets.Count; $i++) {
    $w = $wb.Worksheets.Item($i)
    $u = $w.UsedRange
    $rows = $u.Rows.Count; $cols = $u.Columns.Count
    "Aba ${i}: " + $w.Name + " | UsedRange " + $u.Address($false,$false) + " ($rows x $cols)"
    $v2 = $u.Value2; $f2 = $u.Formula
    $fm = @(); for ($c = 1; $c -le $cols; $c++) { $fm += "$($u.Cells.Item(2, $c).NumberFormat)" }
    $h2 = @(); for ($c = 1; $c -le $cols; $c++) { $h2 += (ColLetter ($u.Column + $c - 1)) }
    $nome = $w.Name -replace '[^A-Za-z0-9]', '_'
    if ($rows -eq 1 -and $cols -eq 1) { $arr = New-Object 'object[,]' 2,2; $arr[1,1] = $v2; $v2 = $arr; $arrf = New-Object 'object[,]' 2,2; $arrf[1,1] = $f2; $f2 = $arrf }
    [IO.File]::WriteAllLines("$saida\aba$i-$nome-valores.csv", (Dump2D $v2 $rows $cols $fm $h2), $utf8bom)
    [IO.File]::WriteAllLines("$saida\aba$i-$nome-formulas.csv", (Dump2D $f2 $rows $cols @() $h2), $utf8bom)
    $nf = 0; for ($r = 1; $r -le $rows; $r++) { for ($c = 1; $c -le $cols; $c++) { if ("$($f2[$r, $c])".StartsWith('=')) { $nf++ } } }
    "  formulas: $nf | primeira linha col: " + $u.Column + " | primeira linha: " + $u.Row
    $lg = @(); for ($c = 1; $c -le $cols; $c++) { $cc = $u.Column + $c - 1; $lg += (ColLetter $cc) + '=' + [math]::Round($w.Columns.Item($cc).ColumnWidth, 1) }
    "  larguras: " + ($lg -join ' | ')
  }
}
finally {
  if ($wb) { $wb.Close($false); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
  if ($excel) { $excel.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
  [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  Start-Sleep -Milliseconds 1500
  $pidsDepois = @(Get-Process excel -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
  $orfaos = @($pidsDepois | Where-Object { $_ -notin $pidsAntes })
  "EXCEL.EXE depois: " + $(if ($pidsDepois.Count) { $pidsDepois -join ',' } else { 'nenhum' }) + " | orfaos criados por mim: " + $(if ($orfaos.Count) { ($orfaos -join ',') } else { 'nenhum' })
  foreach ($p in $orfaos) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue; "  matei EXCEL.EXE $p" }
}
"xlsx apos leitura: " + (Get-Item $xlsx).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + " | " + (Get-Item $xlsx).Length + " bytes | SHA256 " + (Get-FileHash $xlsx -Algorithm SHA256).Hash.Substring(0,12)
