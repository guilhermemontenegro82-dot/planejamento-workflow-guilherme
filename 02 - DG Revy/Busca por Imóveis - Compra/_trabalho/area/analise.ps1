# Análise de apoio: distâncias entre vias de borda e listagem de nós das vias curvas.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$wt = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_trabalho\area"
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = [int]::MaxValue
$ways = @()
foreach ($arq in (Get-ChildItem "$wt\overpass\vias-*.json")) { $o = $ser.DeserializeObject([System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8)); foreach ($w in $o['elements']) { if ($w['type'] -eq 'way' -and $w.ContainsKey('tags') -and $w['tags'].ContainsKey('name')) { $ways += $w } } }
$cosLat = [Math]::Cos(-22.985 * [Math]::PI / 180)
function Dist($lat1, $lon1, $lat2, $lon2) { $dx = ($lon2 - $lon1) * 111320.0 * $cosLat; $dy = ($lat2 - $lat1) * 111320.0; return [Math]::Sqrt($dx * $dx + $dy * $dy) }
function DistSeg($lat, $lon, $aLat, $aLon, $bLat, $bLon) {
    $px = ($lon - $aLon) * 111320.0 * $cosLat; $py = ($lat - $aLat) * 111320.0
    $vx = ($bLon - $aLon) * 111320.0 * $cosLat; $vy = ($bLat - $aLat) * 111320.0
    $l2 = $vx * $vx + $vy * $vy; if ($l2 -eq 0) { return [Math]::Sqrt($px * $px + $py * $py) }
    $t = [Math]::Max(0, [Math]::Min(1, ($px * $vx + $py * $vy) / $l2))
    $dx = $px - $t * $vx; $dy = $py - $t * $vy; return [Math]::Sqrt($dx * $dx + $dy * $dy)
}
function DistVia($lat, $lon, $nome) {
    $m = 1e9
    foreach ($w in $ways) { if ($w['tags']['name'] -ne $nome) { continue }; $g = $w['geometry']; for ($i = 0; $i -lt $g.Count - 1; $i++) { $d = DistSeg $lat $lon ([double]$g[$i]['lat']) ([double]$g[$i]['lon']) ([double]$g[$i + 1]['lat']) ([double]$g[$i + 1]['lon']); if ($d -lt $m) { $m = $d } } }
    return $m
}
function Nos($nome) { foreach ($w in $ways) { if ($w['tags']['name'] -eq $nome) { $g = $w['geometry']; "  way $($w['id']) ($($g.Count) nós, highway=$($w['tags']['highway'])): " + (($g | ForEach-Object { '{0:F5},{1:F5}' -f [double]$_['lat'], [double]$_['lon'] }) -join ' ') } } }

"== Distância do eixo da Rua Redentor ao eixo da Barão da Torre (amostra de nós do Redentor) =="
foreach ($w in $ways) { if ($w['tags']['name'] -eq 'Rua Redentor') { foreach ($p in $w['geometry']) { $d = DistVia ([double]$p['lat']) ([double]$p['lon']) 'Rua Barão da Torre'; '  nó {0:F5},{1:F5} -> {2:F0} m' -f [double]$p['lat'], [double]$p['lon'], $d } } }
"== Nascimento Silva -> Barão da Torre (amostra) =="
$k = 0; foreach ($w in $ways) { if ($w['tags']['name'] -eq 'Rua Nascimento Silva') { foreach ($p in $w['geometry']) { $k++; if ($k % 3 -ne 0) { continue }; $d = DistVia ([double]$p['lat']) ([double]$p['lon']) 'Rua Barão da Torre'; '  nó {0:F5},{1:F5} -> {2:F0} m' -f [double]$p['lat'], [double]$p['lon'], $d } } }
"== Números do Redentor e da Barão da Torre: distância aos dois eixos =="
$num = $ser.DeserializeObject([System.IO.File]::ReadAllText("$wt\overpass\numeros.json", [System.Text.Encoding]::UTF8))
foreach ($e in $num['elements']) { $r = $e['tags']['addr:street']; if ($r -ne 'Rua Redentor' -and $r -ne 'Rua Barão da Torre') { continue }; $la = $e['lat']; $lo = $e['lon']; if ($e.ContainsKey('center')) { $la = $e['center']['lat']; $lo = $e['center']['lon'] }; if ($null -eq $la) { continue }
    '  {0,-20} nº {1,-5} {2:F5},{3:F5}  dBT={4:F0} m  dRed={5:F0} m' -f $r, $e['tags']['addr:housenumber'], [double]$la, [double]$lo, (DistVia ([double]$la) ([double]$lo) 'Rua Barão da Torre'), (DistVia ([double]$la) ([double]$lo) 'Rua Redentor') }
"== Rita Ludolf / Dias Ferreira / Aristides Espínola: distância ao eixo da Visc. de Albuquerque =="
foreach ($n in 'Rua Rita Ludolf', 'Rua Aristides Espínola', 'Rua Professor Azevedo Marques') { foreach ($w in $ways) { if ($w['tags']['name'] -eq $n) { foreach ($p in $w['geometry']) { '  {0,-30} nó {1:F5},{2:F5} -> VA {3:F0} m' -f $n, [double]$p['lat'], [double]$p['lon'], (DistVia ([double]$p['lat']) ([double]$p['lon']) 'Avenida Visconde de Albuquerque') } } } }
foreach ($e in $num['elements']) { $r = $e['tags']['addr:street']; if ($r -notin @('Rua Rita Ludolf', 'Rua Dias Ferreira', 'Avenida Ataulfo de Paiva', 'Avenida Visconde de Albuquerque')) { continue }; $la = $e['lat']; $lo = $e['lon']; if ($e.ContainsKey('center')) { $la = $e['center']['lat']; $lo = $e['center']['lon'] }; if ($null -eq $la) { continue }; $d = DistVia ([double]$la) ([double]$lo) 'Avenida Visconde de Albuquerque'; if ($d -gt 250) { continue }
    '  {0,-30} nº {1,-6} {2:F5},{3:F5} -> VA {4:F0} m' -f $r, $e['tags']['addr:housenumber'], [double]$la, [double]$lo, $d }
"== Nós: Avenida Visconde de Albuquerque (só lat < -22.984) =="
foreach ($w in $ways) { if ($w['tags']['name'] -eq 'Avenida Visconde de Albuquerque') { $g = $w['geometry']; if (([double]$g[0]['lat']) -gt -22.983 -and ([double]$g[$g.Count - 1]['lat']) -gt -22.983) { continue }; "  way $($w['id']) ($($g.Count) nós, $($w['tags']['highway']), oneway=$($w['tags']['oneway'])): " + (($g | ForEach-Object { '{0:F5},{1:F5}' -f [double]$_['lat'], [double]$_['lon'] }) -join ' ') } }
"== Nós: Rua Dias Ferreira =="; Nos 'Rua Dias Ferreira'
"== Nós: Rua Humberto de Campos =="; Nos 'Rua Humberto de Campos'
"== Nós: Avenida Henrique Dumont =="; Nos 'Avenida Henrique Dumont'
"== Nós: Rua Barão da Torre =="; Nos 'Rua Barão da Torre'
"== Nós: Borges de Medeiros com lon < -43.2140 e lat < -22.9810 =="
foreach ($w in $ways) { if ($w['tags']['name'] -eq 'Avenida Borges de Medeiros') { $g = $w['geometry']; $sel = @($g | Where-Object { [double]$_['lon'] -lt -43.2140 -and [double]$_['lat'] -lt -22.9810 }); if ($sel.Count -lt 2) { continue }; "  way $($w['id']) ($($sel.Count) nós, $($w['tags']['highway'])): " + (($sel | ForEach-Object { '{0:F5},{1:F5}' -f [double]$_['lat'], [double]$_['lon'] }) -join ' ') } }
"== Nós: Avenida Delfim Moreira (extremos) e Avenida Vieira Souto (extremos) =="
foreach ($n in 'Avenida Delfim Moreira', 'Avenida Vieira Souto') { $todos = @(); foreach ($w in $ways) { if ($w['tags']['name'] -eq $n) { foreach ($p in $w['geometry']) { $todos += [pscustomobject]@{ lat = [double]$p['lat']; lon = [double]$p['lon'] } } } }; $o = $todos | Sort-Object lon; "  $n : oeste {0:F5},{1:F5}  leste {2:F5},{3:F5}  n={4}" -f $o[0].lat, $o[0].lon, $o[-1].lat, $o[-1].lon, $o.Count }
