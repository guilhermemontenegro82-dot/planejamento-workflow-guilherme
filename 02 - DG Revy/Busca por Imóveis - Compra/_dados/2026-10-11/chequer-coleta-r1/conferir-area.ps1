# conferir-area.ps1 - itens 6 e 7: roda o modulo area.ps1 nas linhas sorteadas (ASCII only no corpo).
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$dados = Split-Path -Parent $aqui
$raiz = Split-Path -Parent (Split-Path -Parent $dados)
. (Join-Path $raiz 'Skills\scripts\area.ps1')
$pastaPol = Join-Path ((Get-ChildItem -Path $raiz -Directory | Where-Object { $_.Name -like '*reas de interesse' }).FullName) 'poligonos'
$pols = Import-Poligonos -Pasta $pastaPol
Write-Output ("poligonos carregados de {0}: {1}" -f $pastaPol, (($pols.Keys | Sort-Object) -join ', '))
foreach ($k in ($pols.Keys | Sort-Object)) { Write-Output ("  {0}: {1} vertices, {2:N3} km2" -f $k, $pols[$k].anel.Count, (Get-AreaKm2 -Anel $pols[$k].anel)) }

$am = @(Import-Csv -Path (Join-Path $aqui 'amostras.csv') -Delimiter ';' -Encoding UTF8 | Where-Object { $_.item -eq '6' -or $_.item -eq '7' })
$col = @(Import-Csv -Path (Join-Path $dados 'coleta.csv') -Delimiter ';' -Encoding UTF8)
$idx = @{}; foreach ($r in $col) { $idx[$r.chave] = $r }

foreach ($a in $am) {
    $r = $idx[$a.chave]
    Write-Output ''
    Write-Output ("--- item {0}: {1} | rua='{2}' n='{3}' bairro_site={4} lat={5} lon={6} prec={7}" -f $a.item, $r.chave, $r.rua, $r.numero, $r.bairro_site, $r.lat, $r.lon, $r.precisao_coord)
    Write-Output ("    coleta.csv: dentro_area={0} | motivo_area='{1}' | poligono={2} | bairro={3}" -f $r.dentro_area, $r.motivo_area, $r.poligono, $r.bairro)
    $l = Test-RuaNaLista -Rua $r.rua -Numero $r.numero
    $linhaRua = if ($l.linha) { ("{0};{1};faixa='{2}';lado='{3}';situacao='{4}'" -f $l.linha.rua, $l.linha.poligono, $l.linha.faixa, $l.linha.lado, $l.linha.situacao_texto) } else { '(nenhuma)' }
    Write-Output ("    Test-RuaNaLista: situacao={0} | motivo='{1}' | linha ruas.csv: {2}" -f $l.situacao, $l.motivo, $linhaRua)
    if ($r.lat -ne '' -and $r.lon -ne '') {
        $p = Get-PoligonoDoPonto -Lat ([double]::Parse($r.lat, [cultureinfo]::InvariantCulture)) -Lon ([double]::Parse($r.lon, [cultureinfo]::InvariantCulture))
        Write-Output ("    Get-PoligonoDoPonto: dentro={0} poligono={1} distancia_borda_m={2}" -f $p.dentro, $p.poligono, $p.distancia)
    }
    $d = Resolve-DentroArea -Lat $r.lat -Lon $r.lon -PrecisaoCoord $r.precisao_coord -Rua $r.rua -Numero $r.numero -BairroSite $r.bairro_site
    $igual = ($d.dentro_area -eq $r.dentro_area)
    Write-Output ("    Resolve-DentroArea: dentro_area={0} | motivo='{1}' | poligono={2} | passo={3} | dist={4} | IGUAL AO CSV={5}" -f $d.dentro_area, $d.motivo_area, $d.poligono, $d.passo, $d.distancia_m, $igual)
}

# reprocessamento completo das linhas SIM/LIMITE/A CONFIRMAR (com coordenada, sem geocodificar) para medir divergencias do modulo x CSV
Write-Output ''
Write-Output '===== reprocessamento: todas as linhas com coordenada (sem geocode), modulo x CSV ====='
$dif = New-Object System.Collections.Generic.List[string]
$n = 0; $semCoord = 0
foreach ($r in $col) {
    if ($r.lat -eq '' -or $r.lon -eq '') { $semCoord++; continue }
    if ($r.precisao_coord -eq 'nenhuma' -or $r.precisao_coord -eq 'bairro') { $semCoord++; continue }
    $n++
    $d = Resolve-DentroArea -Lat $r.lat -Lon $r.lon -PrecisaoCoord $r.precisao_coord -Rua $r.rua -Numero $r.numero -BairroSite $r.bairro_site
    if ($d.dentro_area -ne $r.dentro_area) { $dif.Add(("{0}: csv={1} modulo={2} | rua='{3}' n='{4}' | csv_motivo='{5}' | mod_motivo='{6}'" -f $r.chave, $r.dentro_area, $d.dentro_area, $r.rua, $r.numero, $r.motivo_area, $d.motivo_area)) }
}
Write-Output ("linhas reprocessadas={0} | puladas (sem coordenada util)={1} | divergencias={2}" -f $n, $semCoord, $dif.Count)
$dif | Select-Object -First 20 | ForEach-Object { Write-Output "  $_" }
