# construir-poligonos.ps1 — monta ipanema.geojson e leblon.geojson a partir das geometrias reais das vias de borda
# (Overpass, arquivos em _trabalho\area\overpass\vias-*.json) com deslocamento perpendicular (margem) por trecho.
# Convenção: o anel é percorrido no sentido horário; margem positiva = deslocamento para a ESQUERDA do sentido de
# percurso (= para fora do polígono); margem negativa = para dentro.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File construir-poligonos.ps1
$ErrorActionPreference = 'Stop'
$raiz = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra"
$wt = "$raiz\_trabalho\area"
$saidaPasta = "$raiz\Áreas de interesse\poligonos"
. "$raiz\Skills\scripts\area.ps1"
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$ser = AreaSerializer

# ---- vias do Overpass, por id ----
$waysPorId = @{}
foreach ($arq in (Get-ChildItem "$wt\overpass\vias-*.json")) {
    $o = $ser.DeserializeObject([System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8))
    foreach ($w in $o['elements']) {
        if ($w['type'] -ne 'way' -or -not $w.ContainsKey('geometry')) { continue }
        $pts = @(); foreach ($p in $w['geometry']) { $pts += , @([double]$p['lat'], [double]$p['lon']) }
        $nome = if ($w.ContainsKey('tags') -and $w['tags'].ContainsKey('name')) { $w['tags']['name'] } elseif ($w['tags'].ContainsKey('natural')) { 'coastline' } else { '' }
        $waysPorId[[long]$w['id']] = @{ nome = $nome; pts = $pts }
    }
}

# Trecho de uma ou mais ways, em ordem de percurso. $Ids = lista de @(id, inverter?) ; $Filtro = scriptblock que recebe (lat, lon) e diz se o nó entra.
function Trecho($Ids, [scriptblock]$Filtro = $null) {
    $pts = @()
    foreach ($par in $Ids) {
        $id = [long]$par[0]; $inverter = [bool]$par[1]
        if (-not $waysPorId.ContainsKey($id)) { throw "way $id não está nos arquivos do Overpass" }
        $seq = [object[]]($waysPorId[$id].pts).Clone()   # cópia: Reverse altera no lugar
        if ($inverter) { [array]::Reverse($seq) }
        foreach ($p in $seq) {
            if ($null -ne $Filtro -and -not (& $Filtro $p[0] $p[1])) { continue }
            if ($pts.Count -gt 0 -and (AreaDistPontos $pts[-1][0] $pts[-1][1] $p[0] $p[1]) -lt 0.5) { continue }   # nó repetido na emenda
            $pts += , $p
        }
    }
    return , $pts
}

# Afina a cadeia: mantém só nós a pelo menos $minM do anterior (o último entra sempre)
function Afinar($pts, [double]$minM = 20) {
    if ($pts.Count -le 2) { return , $pts }
    $saida = @(, $pts[0])
    for ($i = 1; $i -lt $pts.Count - 1; $i++) { if ((AreaDistPontos $saida[-1][0] $saida[-1][1] $pts[$i][0] $pts[$i][1]) -ge $minM) { $saida += , $pts[$i] } }
    $saida += , $pts[-1]
    return , $saida
}

# Desloca a cadeia perpendicularmente: margem > 0 = esquerda do sentido de percurso
function Deslocar($pts, [double]$margem) {
    if ([Math]::Abs($margem) -lt 0.01 -or $pts.Count -lt 2) { return , $pts }
    $lat0 = $pts[0][0]; $lon0 = $pts[0][1]
    $xy = @(); foreach ($p in $pts) { $xy += , (AreaXY $p[0] $p[1] $lat0 $lon0) }
    $saida = @()
    for ($i = 0; $i -lt $xy.Count; $i++) {
        $nx = 0.0; $ny = 0.0; $k = 0
        if ($i -gt 0) { $dx = $xy[$i][0] - $xy[$i - 1][0]; $dy = $xy[$i][1] - $xy[$i - 1][1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy); if ($l -gt 0) { $nx += -$dy / $l; $ny += $dx / $l; $k++ } }
        if ($i -lt $xy.Count - 1) { $dx = $xy[$i + 1][0] - $xy[$i][0]; $dy = $xy[$i + 1][1] - $xy[$i][1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy); if ($l -gt 0) { $nx += -$dy / $l; $ny += $dx / $l; $k++ } }
        $ln = [Math]::Sqrt($nx * $nx + $ny * $ny); if ($ln -eq 0) { $saida += , $pts[$i]; continue }
        $nx /= $ln; $ny /= $ln
        $ll = AreaLatLon ($xy[$i][0] + $margem * $nx) ($xy[$i][1] + $margem * $ny) $lat0 $lon0
        $saida += , @($ll[0], $ll[1])
    }
    return , $saida
}

# Ponto deslocado em metros (dN para norte, dE para leste)
function Mover([double]$lat, [double]$lon, [double]$dN, [double]$dE) { $ll = AreaLatLon $dE $dN $lat $lon; return , @($ll[0], $ll[1]) }

# Verifica auto-interseção do anel (segmentos não adjacentes)
function SegmentosCruzam($a, $b, $c, $d) {
    function Orient($p, $q, $r) { return ([Math]::Sign(($q[1] - $p[1]) * ($r[0] - $p[0]) - ($q[0] - $p[0]) * ($r[1] - $p[1]))) }
    $o1 = Orient $a $b $c; $o2 = Orient $a $b $d; $o3 = Orient $c $d $a; $o4 = Orient $c $d $b
    return ($o1 -ne $o2 -and $o3 -ne $o4 -and $o1 -ne 0 -and $o2 -ne 0 -and $o3 -ne 0 -and $o4 -ne 0)
}
function Cruzamentos($anel) {
    $n = $anel.Count - 1   # anel fechado: último = primeiro
    $lista = @()
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = $i + 2; $j -lt $n; $j++) {
            if ($i -eq 0 -and $j -eq $n - 1) { continue }
            if (SegmentosCruzam $anel[$i] $anel[$i + 1] $anel[$j] $anel[$j + 1]) { $lista += "seg $i x seg $j" }
        }
    }
    return , $lista
}

function GravarGeoJson([string]$arquivo, [string]$nome, $anel, [string]$descricao, [string]$fonte) {
    # anel em (lat, lon); grava [lon, lat]; orientação anti-horária (RFC 7946)
    $anelLonLat = @(); foreach ($p in $anel) { $anelLonLat += , @($p[1], $p[0]) }
    $areaKm2 = Get-AreaKm2 -Anel $anelLonLat
    $soma = 0.0
    for ($i = 0; $i -lt $anelLonLat.Count - 1; $i++) { $soma += ($anelLonLat[$i + 1][0] - $anelLonLat[$i][0]) * ($anelLonLat[$i + 1][1] + $anelLonLat[$i][1]) }
    if ($soma -gt 0) { [array]::Reverse($anelLonLat) }   # horário -> anti-horário
    $coords = ($anelLonLat | ForEach-Object { '[' + $_[0].ToString('0.000000', $inv) + ',' + $_[1].ToString('0.000000', $inv) + ']' }) -join ','
    $esc = { param($s) ($s -replace '\\', '\\' -replace '"', '\"') }
    $json = '{"type":"Feature","properties":{"nome":"' + $nome + '","fonte":"' + (& $esc $fonte) + '","gerado_em":"' + (Get-Date).ToString('yyyy-MM-dd HH:mm') +
            '","descricao_bordas":"' + (& $esc $descricao) + '","area_km2":' + $areaKm2.ToString('0.000', $inv) + ',"vertices":' + ($anelLonLat.Count - 1) +
            '},"geometry":{"type":"Polygon","coordinates":[[' + $coords + ']]}}'
    [System.IO.File]::WriteAllText($arquivo, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $areaKm2
}

$fonte = 'OpenStreetMap via Overpass (vias e linha de costa, 11/10/2026); margens aplicadas pelo script _trabalho/area/construir-poligonos.ps1 conforme a marcação do Guilherme'

# =============================================================================================
# IPANEMA + ARPOADOR (sentido horário a partir do canto noroeste)
# =============================================================================================
$mBT = 15      # Barão da Torre (incluída): margem para o norte. 35 m não serve: a Rua Redentor (fora) corre a só 60-80 m.
$mFS = 25      # Rua Francisco Sá (pendente): margem para noroeste
$mHD = 35      # Av. Henrique Dumont (incluída): margem para oeste
$mMar = 80     # orla: mar adentro

$bt = Trecho @(, @(220552826, $true)) { param($la, $lo) $lo -ge -43.21345 -and $la -ge -22.98365 }   # BT de oeste (Henrique Dumont) para leste, sem o gancho final de 13 m para o sul na Praça General Osório
$btOff = Deslocar (Afinar $bt 25) $mBT
$cantoNO = Mover $bt[0][0] $bt[0][1] $mBT (-$mHD)

$fs = Trecho @(@(29626811, $false), @(795437750, $false), @(162651831, $false), @(341671987, $false))   # junção Gomes Carneiro -> Atlântica
$fsOff = Deslocar (Afinar $fs 20) $mFS
# Diagonal do fim da Barão da Torre à junção Gomes Carneiro/Bulhões/Francisco Sá: na marcação ela passa ~40 m ao norte do fim da BT e
# ~50-75 m ao norte da junção (medido no mapa); o trecho NO da Bulhões de Carvalho (rumo à Sá Ferreira) fica fora, perto da borda.
$fimBT = Mover $bt[-1][0] $bt[-1][1] 35 0
$fsOff[0] = Mover $fs[0][0] $fs[0][1] 60 (-10)

$copa = Trecho @(, @(70574890, $true)) { param($la, $lo) $la -le -22.98240 -and $la -ge -22.98535 }   # orla de Copacabana, de Francisco Sá até antes da curva do Forte (curva côncava faria o deslocamento se cruzar), rumo sul
$copaOff = Deslocar (Afinar $copa 25) $mMar
$cantoNE = Mover $fs[-1][0] $fs[-1][1] 22 ($mMar + 55)    # Francisco Sá x Atlântica, levado até 80 m mar adentro (a faixa de areia ali tem ~55 m)

$praiaIpa = Trecho @(, @(371511361, $true)) { param($la, $lo) $lo -ge -43.21374 }    # orla de Ipanema, do Arpoador para oeste
$praiaOff = Deslocar (Afinar $praiaIpa 60) $mMar
$cantoSO = Mover $praiaIpa[-1][0] -43.21374 (-$mMar) 0   # Henrique Dumont é quase reta N-S: a borda oeste é a vertical lon -43.21374 do canto SO ao canto NO

$anelIpa = @()
$anelIpa += , $cantoNO
$anelIpa += $btOff
$anelIpa += , $fimBT
$anelIpa += $fsOff
$anelIpa += , $cantoNE
$anelIpa += $copaOff
$anelIpa += , @(-22.98900, -43.18650)    # mar, a sudeste da Praia do Diabo (corta a península do Forte, sem edificação residencial)
$anelIpa += , @(-22.99150, -43.19000)    # mar, a sudeste da Pedra do Arpoador
$anelIpa += , @(-22.99050, -43.19220)    # mar, a sudoeste da Pedra do Arpoador
$anelIpa += $praiaOff
$anelIpa += , $cantoSO
$anelIpa += , $cantoNO
$descIpa = "Norte: Rua Barão da Torre (incluída) + $mBT m (a Rua Redentor, fora, corre a 60-80 m); nordeste: diagonal 35-45 m ao norte do fim da Barão da Torre e da junção Gomes Carneiro/Bulhões de Carvalho, depois a Rua Francisco Sá (pendente) + $mFS m até a Av. Atlântica (Posto 5/6); " +
           "leste/sul: linha de costa + $mMar m mar adentro, cortando a península do Forte de Copacabana/Pedra do Arpoador; oeste: Av. Henrique Dumont (incluída) + $mHD m. " +
           "Fora: Nascimento Silva, Redentor, Alberto de Campos, Barão de Jaguaripe, Epitácio Pessoa, Saint Roman, Sá Ferreira e o resto de Copacabana."
$areaIpa = GravarGeoJson "$saidaPasta\ipanema.geojson" 'Ipanema' $anelIpa $descIpa $fonte
"Ipanema: $($anelIpa.Count - 1) vértices, área $($areaIpa.ToString('0.000', $inv)) km²; cruzamentos: $((Cruzamentos $anelIpa) -join ', ')"

# =============================================================================================
# LEBLON (sentido horário a partir do canto sudoeste)
# =============================================================================================
$mVA = -65     # Av. Visconde de Albuquerque (fora): a linha vermelha corre 70-110 m a LESTE do eixo (entre a VA e a Rita Ludolf) -> margem para dentro;
               # 65 m (e não 80) para a Rua Dias Ferreira (incluída) ficar com os dois lados a mais de 50 m da borda
$mHC = 35      # Rua Humberto de Campos (incluída): margem para o norte
$mBM = 35      # Av. Borges de Medeiros (incluída): margem para leste
$mDF = 35      # Rua Dias Ferreira (incluída, "conferir limite"): margem para noroeste no trecho em que ela é a borda

$va = Trecho @(@(370164934, $false), @(799528762, $false), @(37319456, $false), @(799528761, $false), @(23186144, $false), @(910960665, $false), @(549560903, $false)) { param($la, $lo) $la -le -22.98305 }
$vaOff = Deslocar (Afinar $va 25) $mVA

# Dias Ferreira: eixo da via (way 180211960, de SO para NE) deslocado 35 m para noroeste, do ponto em que a VA+80 m encontra o eixo até o fim NE
$df = Trecho @(@(180211960, $true), @(917999874, $true))
$dfOff = Deslocar (Afinar $df 30) $mDF
$dfOffNorte = @($dfOff | Where-Object { $_[0] -gt -22.98300 })

$hc = Trecho @(@(119860676, $false), @(190627094, $false)) { param($la, $lo) $lo -ge -43.22385 }   # Humberto de Campos, de Bartolomeu Mitre para leste
$hcOff = Deslocar (Afinar $hc 30) $mHC
$cantoNE = Mover $hc[-1][0] $hc[-1][1] $mHC $mBM

$bm = Trecho @(@(962083688, $false), @(224433806, $false), @(964424138, $false), @(1008936632, $false), @(787839653, $false), @(329056671, $false), @(787329643, $false), @(957238723, $false))
$bmOff = Deslocar (Afinar $bm 25) $mBM
$cantoSE = @(-22.98800, $bmOff[-1][1])

$praiaLeb = Trecho @(, @(371512811, $true))    # orla do Leblon, do canal para oeste
$praiaLebOff = Deslocar (Afinar $praiaLeb 60) $mMar
$cantoSO = @(-22.99020, $vaOff[0][1])

$anelLeb = @()
$anelLeb += , $cantoSO
$anelLeb += $vaOff
$anelLeb += $dfOffNorte
$anelLeb += $hcOff
$anelLeb += , $cantoNE
$anelLeb += $bmOff
$anelLeb += , $cantoSE
$anelLeb += $praiaLebOff
$anelLeb += , $cantoSO
$descLeb = "Oeste: Av. Visconde de Albuquerque (fora) com a borda $([Math]::Abs($mVA)) m a leste do eixo (traçado da marcação, entre a VA e a Rua Rita Ludolf); " +
           "noroeste: Rua Dias Ferreira (incluída) + $mDF m; norte: Rua Humberto de Campos (incluída) + $mHC m, de Bartolomeu Mitre à Borges de Medeiros; " +
           "leste: Av. Borges de Medeiros (incluída) + $mBM m junto ao Jardim de Alah; sul: linha de costa + $mMar m mar adentro. " +
           "Fora: Gilberto Cardoso, Timóteo da Costa, Igarapava, Codajás, o norte de Bartolomeu Mitre/Afrânio de Melo Franco."
$areaLeb = GravarGeoJson "$saidaPasta\leblon.geojson" 'Leblon' $anelLeb $descLeb $fonte
"Leblon: $($anelLeb.Count - 1) vértices, área $($areaLeb.ToString('0.000', $inv)) km²; cruzamentos: $((Cruzamentos $anelLeb) -join ', ')"

# ---- pontos de controle (números de porta do OSM) para conferir as margens ----
Import-Poligonos -Pasta $saidaPasta | Out-Null
$controle = @(
    @('Barão da Torre 398 (lado N)', -22.98292, -43.20661), @('Barão da Torre 632', -22.98319, -43.20542), @('Redentor 95 (lado S)', -22.98263, -43.20733), @('Redentor 188 (lado N)', -22.98224, -43.20995),
    @('Nascimento Silva (eixo)', -22.98210, -43.20483), @('Henrique Dumont 110', -22.98355, -43.21331), @('Francisco Sá 90', -22.98354, -43.19325), @('Francisco Sá 17', -22.98319, -43.19064),
    @('N S Copacabana 1260', -22.98276, -43.19108), @('Sá Ferreira 202', -22.98154, -43.19473), @('Francisco Otaviano 177', -22.98794, -43.19380), @('Francisco Otaviano 20C', -22.98641, -43.18919),
    @('Rainha Elizabeth 440', -22.98552, -43.19379), @('Gomes Carneiro 84', -22.98529, -43.19571), @('Raul Pompéia 94', -22.98478, -43.19132),
    @('VA 694 (lado E)', -22.98328, -43.22743), @('Dias Ferreira 78', -22.98537, -43.22816), @('Dias Ferreira 106', -22.98522, -43.22799), @('Dias Ferreira 420', -22.98318, -43.22599), @('Dias Ferreira 679 (fim NE)', -22.98163, -43.22407),
    @('Rita Ludolf 87', -22.98621, -43.22801), @('Ataulfo de Paiva 1240', -22.98596, -43.22737), @('Bartolomeu Mitre 613 (lado O)', -22.98157, -43.22404), @('Humberto de Campos 315', -22.98175, -43.21862),
    @('Humberto de Campos 802', -22.98220, -43.22290), @('Gilberto Cardoso 997', -22.97893, -43.21995), @('Afrânio de Melo Franco 290 (shopping)', -22.98256, -43.21734), @('Borges de Medeiros 701', -22.98091, -43.21493),
    @('Cupertino Durão 56', -22.98520, -43.22035), @('Timóteo da Costa 297', -22.98377, -43.23211), @('Saddock de Sá 266', -22.98048, -43.20329),
    @('Bulhões de Carvalho 530 (trecho NO, QuintoAndar)', -22.9829776, -43.1942359), @('Saint Roman (QuintoAndar)', -22.982815, -43.1956278), @('Gomes Carneiro 130 (QuintoAndar)', -22.9853641, -43.1959259),
    @('Alberto de Campos 25 (QuintoAndar)', -22.9811248, -43.2030681), @('Bartolomeu Mitre 448 (QuintoAndar)', -22.9828463, -43.2232562), @('Bartolomeu Mitre 990 (QuintoAndar)', -22.9784931, -43.2244654)
)
"--- pontos de controle (coordenada exata) ---"
foreach ($c in $controle) {
    $r = Resolve-DentroArea -Lat $c[1] -Lon $c[2] -PrecisaoCoord 'exata'
    '  {0,-40} {1,-12} {2}' -f $c[0], $r.dentro_area, $r.motivo_area
}
