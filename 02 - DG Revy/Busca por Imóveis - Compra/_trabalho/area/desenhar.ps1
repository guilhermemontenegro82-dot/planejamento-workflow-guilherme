# Desenha as vias do Overpass, os números de porta do OSM, o polígono (se existir) e os pontos de teste
# num PNG, para conferência visual sem navegador.
# Uso: desenhar.ps1 -Area ipanema|leblon [-Nome zoom1 -LonMin .. -LonMax .. -LatMin .. -LatMax .. -PxPorMetro 1.2]
param([string]$Area = 'ipanema', [string]$Nome = '', [double]$PxPorMetro = 0.55,
      [double]$LonMin = 0, [double]$LonMax = 0, [double]$LatMin = 0, [double]$LatMax = 0, [switch]$SemNumeros)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions
$raiz = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra"
$wt = "$raiz\_trabalho\area"
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = [int]::MaxValue

# Janela de desenho (lon min/max, lat min/max)
if ($LonMin -eq 0) {
    if ($Area -eq 'ipanema') { $LonMin = -43.2175; $LonMax = -43.1860; $LatMin = -22.9915; $LatMax = -22.9775 }
    else { $LonMin = -43.2375; $LonMax = -43.2110; $LatMin = -22.9910; $LatMax = -22.9765 }
}
if (-not $Nome) { $Nome = $Area }
$latMed = ($LatMin + $LatMax) / 2
$mPorGrauLat = 111320.0
$mPorGrauLon = 111320.0 * [Math]::Cos($latMed * [Math]::PI / 180)
$larg = [int](($LonMax - $LonMin) * $mPorGrauLon * $PxPorMetro)
$alt = [int](($LatMax - $LatMin) * $mPorGrauLat * $PxPorMetro)
function PX($lon) { return [float](($lon - $LonMin) * $mPorGrauLon * $PxPorMetro) }
function PY($lat) { return [float](($LatMax - $lat) * $mPorGrauLat * $PxPorMetro) }

$bmp = New-Object System.Drawing.Bitmap($larg, $alt)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)
$fonte = New-Object System.Drawing.Font('Arial', 7)
$fonteP = New-Object System.Drawing.Font('Arial', 8, [System.Drawing.FontStyle]::Bold)
$fonteN = New-Object System.Drawing.Font('Arial', 6)
$penVia = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 150, 150), 1.5)
$penViaInc = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 140, 0), 2.5)
$penViaFora = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 120, 0), 2.5)
$penViaPend = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 160, 160), 2.5)
$penPol = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2.5)
$brText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 60, 160))
$brNum = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 60, 120))

# Vias incluídas (ruas.csv) e vias de borda excluídas, para colorir
$ruas = Import-Csv "$raiz\Listagem das ruas\ruas.csv" -Delimiter ';' -Encoding UTF8
$incl = @($ruas | Where-Object { $_.situacao -eq 'incluída' } | ForEach-Object { $_.rua } | Select-Object -Unique)
$pend = @($ruas | Where-Object { $_.situacao -eq 'pendente' } | ForEach-Object { $_.rua } | Select-Object -Unique)
$fora = @('Rua Nascimento Silva', 'Rua Alberto de Campos', 'Rua Barão de Jaguaripe', 'Avenida Epitácio Pessoa', 'Rua Redentor', 'Avenida Visconde de Albuquerque', 'Rua Gilberto Cardoso', 'Rua Timóteo da Costa', 'Rua Igarapava')

# Grade de 100 m
$penGrade = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 235, 235), 1)
for ($x = 0; $x -lt $larg; $x += [int](100 * $PxPorMetro)) { $g.DrawLine($penGrade, $x, 0, $x, $alt) }
for ($y = 0; $y -lt $alt; $y += [int](100 * $PxPorMetro)) { $g.DrawLine($penGrade, 0, $y, $larg, $y) }

# Vias (todos os arquivos vias-*.json da pasta overpass, para a janela pegar o que precisar)
$rotulados = @{}
foreach ($arq in (Get-ChildItem "$wt\overpass\vias-*.json")) {
    $txt = [System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8)
    $obj = $ser.DeserializeObject($txt)
    foreach ($w in $obj['elements']) {
        if ($w['type'] -ne 'way' -or -not $w.ContainsKey('geometry')) { continue }
        $nomeVia = $w['tags']['name']
        $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
        $dentro = $false
        foreach ($p in $w['geometry']) { $xx = PX ([double]$p['lon']); $yy = PY ([double]$p['lat']); if ($xx -ge -50 -and $xx -le $larg + 50 -and $yy -ge -50 -and $yy -le $alt + 50) { $dentro = $true }; $pts.Add((New-Object System.Drawing.PointF($xx, $yy))) }
        if ($pts.Count -lt 2 -or -not $dentro) { continue }
        $pen = $penVia
        $nomeCmp = $nomeVia -replace 'Elisabeth', 'Elizabeth da Bélgica' -replace 'Gois', 'Góis' -replace 'Líra', 'Lira' -replace '^Avenida Rainha Elizabeth$', 'Avenida Rainha Elizabeth da Bélgica'
        if ($incl -contains $nomeCmp) { $pen = $penViaInc } elseif ($fora -contains $nomeVia) { $pen = $penViaFora } elseif ($pend -contains $nomeVia) { $pen = $penViaPend }
        $g.DrawLines($pen, $pts.ToArray())
        $chave = "$nomeVia|$([int]($pts[0].X / 150))|$([int]($pts[0].Y / 150))"
        if (-not $rotulados.ContainsKey($chave) -and $pts.Count -ge 2) {
            $m = $pts[[int]($pts.Count / 2)]
            if ($m.X -ge 0 -and $m.Y -ge 0 -and $m.X -le $larg -and $m.Y -le $alt) { $g.DrawString(($nomeVia -replace '^(Rua|Avenida) ', ''), $fonte, $brText, $m.X + 2, $m.Y - 10); $rotulados[$chave] = $true }
        }
    }
}

# Números de porta do OSM (numeros.json), se existir e a escala permitir
if (-not $SemNumeros -and (Test-Path "$wt\overpass\numeros.json") -and $PxPorMetro -ge 0.9) {
    $obj = $ser.DeserializeObject([System.IO.File]::ReadAllText("$wt\overpass\numeros.json", [System.Text.Encoding]::UTF8))
    foreach ($e in $obj['elements']) {
        $la = $e['lat']; $lo = $e['lon']; if ($e.ContainsKey('center')) { $la = $e['center']['lat']; $lo = $e['center']['lon'] }
        if ($null -eq $la) { continue }
        $x = PX ([double]$lo); $y = PY ([double]$la)
        if ($x -lt 0 -or $y -lt 0 -or $x -gt $larg -or $y -gt $alt) { continue }
        $g.FillEllipse($brNum, $x - 2, $y - 2, 4, 4)
        $g.DrawString($e['tags']['addr:housenumber'], $fonteN, $brNum, $x + 2, $y - 3)
    }
}

# Polígono, se existir
$geo = "$raiz\Áreas de interesse\poligonos\$Area.geojson"
if (Test-Path $geo) {
    $pj = $ser.DeserializeObject([System.IO.File]::ReadAllText($geo, [System.Text.Encoding]::UTF8))
    $anel = $pj['geometry']['coordinates'][0]
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($c in $anel) { $pts.Add((New-Object System.Drawing.PointF((PX ([double]$c[0])), (PY ([double]$c[1]))))) }
    $g.DrawPolygon($penPol, $pts.ToArray())
    $brV = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red)
    for ($i = 0; $i -lt $pts.Count - 1; $i++) { $g.FillEllipse($brV, $pts[$i].X - 2, $pts[$i].Y - 2, 4, 4); $g.DrawString("$i", $fonteP, $brV, $pts[$i].X + 3, $pts[$i].Y + 1) }
}

# Pontos de teste, se existirem
$pt = "$raiz\Áreas de interesse\poligonos\pontos-teste.csv"
if (Test-Path $pt) {
    $linhas = Import-Csv $pt -Delimiter ';' -Encoding UTF8
    foreach ($l in $linhas) {
        if (-not $l.lat -or -not $l.lon) { continue }
        $x = PX ([double]$l.lon); $y = PY ([double]$l.lat)
        if ($x -lt 0 -or $y -lt 0 -or $x -gt $larg -or $y -gt $alt) { continue }
        $cor = switch -Regex ($l.esperado) { '^SIM$' { [System.Drawing.Color]::Green } '^NAO$' { [System.Drawing.Color]::Red } default { [System.Drawing.Color]::Blue } }
        $br = New-Object System.Drawing.SolidBrush($cor)
        $g.FillEllipse($br, $x - 5, $y - 5, 10, 10)
        $g.DrawString("$($l.rua -replace '^(Rua|Avenida) ','') $($l.numero)", $fonteP, $br, $x + 6, $y - 6)
    }
}

# Escala
$g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 3)), 20, $alt - 20, 20 + [int](200 * $PxPorMetro), $alt - 20)
$g.DrawString('200 m', $fonteP, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)), 20, $alt - 36)
$saida = "$wt\mapa-$Nome.png"
$bmp.Save($saida, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"PNG gravado: $saida ($larg x $alt px)"
