# gerar-html.ps1 — gera Áreas de interesse\poligonos\poligonos.html: Leaflet (CDN unpkg) sobre OpenStreetMap com os dois polígonos
# e os pontos de pontos-teste.csv (verde = SIM, laranja = LIMITE, vermelho = NAO, pelo resultado do módulo; anel vermelho grosso = FAIL).
$ErrorActionPreference = 'Stop'
$raiz = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra"
$pasta = "$raiz\Áreas de interesse\poligonos"
. "$raiz\Skills\scripts\area.ps1"
$inv = [System.Globalization.CultureInfo]::InvariantCulture
Import-Poligonos -Pasta $pasta | Out-Null

$geo = @{}
foreach ($n in @('ipanema', 'leblon')) { $geo[$n] = [System.IO.File]::ReadAllText("$pasta\$n.geojson", [System.Text.Encoding]::UTF8) }
$areaIpa = Get-AreaKm2 -Anel $script:AreaPoligonos['Ipanema'].anel
$areaLeb = Get-AreaKm2 -Anel $script:AreaPoligonos['Leblon'].anel

function JsStr([string]$s) { return '"' + ($s -replace '\\', '\\' -replace '"', '\"' -replace "`r", '' -replace "`n", ' ') + '"' }

$pontos = @(Import-Csv -Path "$pasta\pontos-teste.csv" -Delimiter ';' -Encoding UTF8)
$itens = New-Object System.Collections.Generic.List[string]
$nPass = 0; $nFail = 0
foreach ($p in $pontos) {
    $la = AreaToNum ([string]$p.lat); $lo = AreaToNum ([string]$p.lon)
    if ($null -eq $la -or $null -eq $lo) { continue }
    $r = Resolve-DentroArea -Lat $la -Lon $lo -PrecisaoCoord 'exata' -Rua $p.rua -Numero $p.numero -BairroSite $p.bairro
    $esperados = @(([string]$p.esperado) -split '\|' | ForEach-Object { $_.Trim() })
    $ok = $esperados -contains $r.dentro_area
    if ($ok) { $nPass++ } else { $nFail++ }
    $itens.Add('{lat:' + $la.ToString('0.0000000', $inv) + ',lon:' + $lo.ToString('0.0000000', $inv) + ',rua:' + (JsStr "$($p.rua), $($p.numero)") + ',bairro:' + (JsStr $p.bairro) +
               ',esperado:' + (JsStr $p.esperado) + ',obtido:' + (JsStr $r.dentro_area) + ',motivo:' + (JsStr $r.motivo_area) + ',obs:' + (JsStr $p.observacao) + ',ok:' + ($(if ($ok) { 'true' } else { 'false' })) + '}')
}
$gerado = (Get-Date).ToString('dd/MM/yyyy HH:mm')

$html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Áreas de interesse — Ipanema e Leblon</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<style>
  html, body { height: 100%; margin: 0; font-family: Segoe UI, Arial, sans-serif; }
  #mapa { height: 100%; }
  .painel { position: absolute; top: 10px; right: 10px; z-index: 1000; background: rgba(255,255,255,0.95); padding: 10px 14px; border-radius: 6px; box-shadow: 0 1px 6px rgba(0,0,0,0.3); font-size: 13px; max-width: 320px; }
  .painel h1 { font-size: 15px; margin: 0 0 6px 0; }
  .painel .sw { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 6px; vertical-align: middle; border: 1px solid #333; }
  .painel .lin { display: inline-block; width: 18px; height: 4px; margin-right: 6px; vertical-align: middle; }
  .painel small { color: #555; }
  .leaflet-popup-content { font-size: 13px; }
</style>
</head>
<body>
<div id="mapa"></div>
<div class="painel">
  <h1>Áreas de interesse (Busca por Imóveis)</h1>
  <div><span class="lin" style="background:#1f5fbf"></span>Ipanema + Arpoador — $($areaIpa.ToString('0.00', $inv)) km²</div>
  <div><span class="lin" style="background:#1a8f3c"></span>Leblon — $($areaLeb.ToString('0.00', $inv)) km²</div>
  <div style="margin-top:6px"><span class="sw" style="background:#2ecc40"></span>SIM (dentro) &nbsp; <span class="sw" style="background:#ff9f1c"></span>LIMITE &nbsp; <span class="sw" style="background:#e63946"></span>NAO (fora)</div>
  <div><small>Pontos de teste: $nPass PASS, $nFail FAIL (anel vermelho grosso = FAIL). Clique nos pontos e nos polígonos. Gerado em $gerado.</small></div>
</div>
<script>
var ipanema = $($geo['ipanema']);
var leblon = $($geo['leblon']);
var pontos = [
$($itens -join ",`n")
];
var mapa = L.map('mapa');
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; OpenStreetMap' }).addTo(mapa);
var camIpa = L.geoJSON(ipanema, { style: { color: '#1f5fbf', weight: 3, fillOpacity: 0.12 } }).bindPopup(function (l) { var p = l.feature.properties; return '<b>' + p.nome + '</b><br>' + p.area_km2 + ' km², ' + p.vertices + ' vértices<br><small>' + p.descricao_bordas + '</small>'; }).addTo(mapa);
var camLeb = L.geoJSON(leblon, { style: { color: '#1a8f3c', weight: 3, fillOpacity: 0.12 } }).bindPopup(function (l) { var p = l.feature.properties; return '<b>' + p.nome + '</b><br>' + p.area_km2 + ' km², ' + p.vertices + ' vértices<br><small>' + p.descricao_bordas + '</small>'; }).addTo(mapa);
var cores = { 'SIM': '#2ecc40', 'LIMITE': '#ff9f1c', 'NAO': '#e63946', 'A CONFIRMAR': '#9b59b6' };
pontos.forEach(function (p) {
  var m = L.circleMarker([p.lat, p.lon], { radius: 7, color: p.ok ? '#222' : '#c00', weight: p.ok ? 1.5 : 4, fillColor: cores[p.obtido] || '#999', fillOpacity: 0.9 }).addTo(mapa);
  m.bindPopup('<b>' + p.rua + '</b> (' + p.bairro + ')<br>esperado: ' + p.esperado + ' | obtido: <b>' + p.obtido + '</b>' + (p.ok ? '' : ' — <b style="color:#c00">FAIL</b>') + '<br>' + p.motivo + '<br><small>' + p.obs + '</small>');
});
mapa.fitBounds(L.featureGroup([camIpa, camLeb]).getBounds().pad(0.08));
</script>
</body>
</html>
"@
[System.IO.File]::WriteAllText("$pasta\poligonos.html", $html, (New-Object System.Text.UTF8Encoding($true)))
"poligonos.html gravado: $($pontos.Count) pontos ($nPass PASS, $nFail FAIL); Ipanema $($areaIpa.ToString('0.000', $inv)) km², Leblon $($areaLeb.ToString('0.000', $inv)) km²"
