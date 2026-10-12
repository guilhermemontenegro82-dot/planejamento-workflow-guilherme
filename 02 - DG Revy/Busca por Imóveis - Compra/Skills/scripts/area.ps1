# area.ps1 — Módulo de área da Busca por Imóveis (DG Revy): polígonos de Ipanema e Leblon, lista de ruas e geocodificação.
# Feito para dot-source pelo consolidar.ps1 (`. area.ps1`) e também para uso avulso na linha de comando:
#   powershell -NoProfile -ExecutionPolicy Bypass -File area.ps1 -Teste
#   powershell -NoProfile -ExecutionPolicy Bypass -File area.ps1 -Endereco "Rua Visconde de Pirajá" -Numero 540 -Bairro Ipanema
#
# Funções públicas:
#   Import-Poligonos [-Pasta]            carrega ipanema.geojson e leblon.geojson (padrão: <raiz>\Áreas de interesse\poligonos)
#   Test-PontoNoPoligono -Lat -Lon -Anel ray casting (anel = lista de pares [lon, lat])
#   Get-DistanciaBordaMetros -Lat -Lon -Anel  menor distância ponto-segmento, em metros (projeção equiretangular)
#   Normalize-Rua -Rua                   sem acento, minúsculas, abreviações expandidas, variantes de grafia unificadas
#   Test-RuaNaLista -Rua -Numero         situacao incluída | pendente | fora + linha casada de ruas.csv (faixa e lado par/ímpar)
#   Get-Geocode -Rua -Numero -Bairro     Nominatim (structured) + números de porta do OSM (Overpass); cache em _dados\geocache.csv
#   Resolve-DentroArea ...               passos 1 a 4 do CONTRATO-DADOS.md → dentro_area, motivo_area, poligono (+ lat/lon se geocodificou)
#   Get-AreaKm2 -Anel                    área do anel em km² (shoelace em metros)
#
# Regras da casa: HTTP só com curl.exe; Nominatim a 1 pedido por segundo com User-Agent "busca-imoveis-dg/1.0";
# Overpass por POST com --data-urlencode "data@arquivo". Nada é gravado fora da raiz do projeto.
# Todo estado interno usa o prefixo $script:Area… para não colidir com variáveis de quem faz o dot-source.
param(
    [switch]$Teste,
    [string]$Endereco = '',
    [string]$Numero = '',
    [string]$Bairro = '',
    [string]$PastaPoligonos = ''
)

# ---------------------------------------------------------------------------------------------
# Estado do módulo
# ---------------------------------------------------------------------------------------------
# $PSScriptRoot vem vazio no bloco param do PS 5.1, mas aqui no corpo já existe (também quando o arquivo é dot-sourced).
$script:AreaDirScript = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:AreaRaiz = Split-Path -Parent (Split-Path -Parent $script:AreaDirScript)
$script:AreaPastaPoligonosPadrao = Join-Path $script:AreaRaiz 'Áreas de interesse\poligonos'
$script:AreaArquivoRuas = Join-Path $script:AreaRaiz 'Listagem das ruas\ruas.csv'
$script:AreaArquivoCriterios = Join-Path $script:AreaRaiz 'Sites e critérios para Busca\criterios.json'
$script:AreaGeocachePath = Join-Path $script:AreaRaiz '_dados\geocache.csv'
$script:AreaPastaTmp = Join-Path $script:AreaRaiz '_dados\_tmp'
$script:AreaPoligonos = $null          # hashtable nome -> @{ nome; anel; arquivo }
$script:AreaRuas = $null               # linhas de ruas.csv com o núcleo do nome normalizado
$script:AreaGeocache = $null           # hashtable chave -> objeto do cache
$script:AreaOverpassCache = @{}        # por rodada: núcleo OSM -> @{ numeros; vias }
$script:AreaUltimoNominatim = [datetime]::MinValue
$script:AreaUltimoOverpass = [datetime]::MinValue
$script:AreaInv = [System.Globalization.CultureInfo]::InvariantCulture
$script:AreaMetrosPorGrau = 111320.0
$script:AreaCosLat = [Math]::Cos(-22.985 * [Math]::PI / 180)
$script:AreaCurl = Join-Path $env:SystemRoot 'System32\curl.exe'
$script:AreaUA = 'busca-imoveis-dg/1.0'
$script:AreaBBox = '(-23.00,-43.25,-22.95,-43.15)'
$script:AreaSer = $null
$script:AreaLimites = @{ limite = 50.0; aproxDentro = 150.0; aproxFora = 300.0; geocodeVia = 400.0 }
$script:AreaBairrosAceitos = @('ipanema', 'leblon', 'arpoador', 'copacabana')
try {
    if (Test-Path $script:AreaArquivoCriterios) {
        $AreaCrit = Get-Content -Path $script:AreaArquivoCriterios -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($AreaCrit.borda_limite_m) { $script:AreaLimites.limite = [double]$AreaCrit.borda_limite_m }
        if ($AreaCrit.borda_aproximada_dentro_m) { $script:AreaLimites.aproxDentro = [double]$AreaCrit.borda_aproximada_dentro_m }
        if ($AreaCrit.borda_aproximada_fora_m) { $script:AreaLimites.aproxFora = [double]$AreaCrit.borda_aproximada_fora_m }
    }
} catch { }

# ---------------------------------------------------------------------------------------------
# Utilitários internos
# ---------------------------------------------------------------------------------------------
function AreaSerializer {
    if ($null -eq $script:AreaSer) {
        Add-Type -AssemblyName System.Web.Extensions
        $script:AreaSer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $script:AreaSer.MaxJsonLength = [int]::MaxValue
    }
    return $script:AreaSer
}

function AreaSemAcento([string]$s) {
    if ($null -eq $s) { return '' }
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $n.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function AreaToNum($v) {
    if ($null -eq $v) { return $null }
    if ($v -is [double] -or $v -is [int] -or $v -is [long] -or $v -is [decimal] -or $v -is [single]) { return [double]$v }
    $s = ([string]$v).Trim()
    if ($s -eq '') { return $null }
    $d = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $script:AreaInv, [ref]$d)) { return $d }
    if ([double]::TryParse(($s -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $script:AreaInv, [ref]$d)) { return $d }
    return $null
}

function AreaFmt($v, [int]$casas = 6) { if ($null -eq $v) { return '' }; return ([double]$v).ToString('0.' + ('#' * $casas), $script:AreaInv) }

function AreaSoDigitos([string]$s) { if ($null -eq $s) { return '' }; $m = [regex]::Match($s, '\d+'); if ($m.Success) { return $m.Value } else { return '' } }

# Coordenadas geográficas -> metros (x para leste, y para norte) em relação a uma origem
function AreaXY([double]$lat, [double]$lon, [double]$lat0, [double]$lon0) {
    return @((($lon - $lon0) * $script:AreaMetrosPorGrau * $script:AreaCosLat), (($lat - $lat0) * $script:AreaMetrosPorGrau))
}
function AreaLatLon([double]$x, [double]$y, [double]$lat0, [double]$lon0) {
    return @(($lat0 + $y / $script:AreaMetrosPorGrau), ($lon0 + $x / ($script:AreaMetrosPorGrau * $script:AreaCosLat)))
}

function AreaDistPontos([double]$lat1, [double]$lon1, [double]$lat2, [double]$lon2) {
    $dx = ($lon2 - $lon1) * $script:AreaMetrosPorGrau * $script:AreaCosLat
    $dy = ($lat2 - $lat1) * $script:AreaMetrosPorGrau
    return [Math]::Sqrt($dx * $dx + $dy * $dy)
}

# Distância (m) do ponto ao segmento A-B, com a projeção do ponto no segmento
function AreaDistSegmento([double]$lat, [double]$lon, [double]$aLat, [double]$aLon, [double]$bLat, [double]$bLon) {
    $px = ($lon - $aLon) * $script:AreaMetrosPorGrau * $script:AreaCosLat
    $py = ($lat - $aLat) * $script:AreaMetrosPorGrau
    $vx = ($bLon - $aLon) * $script:AreaMetrosPorGrau * $script:AreaCosLat
    $vy = ($bLat - $aLat) * $script:AreaMetrosPorGrau
    $l2 = $vx * $vx + $vy * $vy
    if ($l2 -le 0) { return [Math]::Sqrt($px * $px + $py * $py) }
    $t = ($px * $vx + $py * $vy) / $l2
    if ($t -lt 0) { $t = 0 } elseif ($t -gt 1) { $t = 1 }
    $dx = $px - $t * $vx; $dy = $py - $t * $vy
    return [Math]::Sqrt($dx * $dx + $dy * $dy)
}

function AreaGarantirPastaTmp { if (-not (Test-Path $script:AreaPastaTmp)) { New-Item -ItemType Directory -Force -Path $script:AreaPastaTmp | Out-Null } }

# GET via curl.exe gravando num arquivo temporário dentro da raiz (evita o problema de codificação do console). Devolve o texto ou $null.
function AreaHttpGet([string]$Url, [string]$Nome) {
    AreaGarantirPastaTmp
    $arq = Join-Path $script:AreaPastaTmp "$Nome.json"
    for ($tent = 1; $tent -le 2; $tent++) {
        if (Test-Path $arq) { Remove-Item $arq -Force -ErrorAction SilentlyContinue }
        & $script:AreaCurl -s -A $script:AreaUA --max-time 40 -o $arq $Url 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $arq)) {
            $txt = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)
            Remove-Item $arq -Force -ErrorAction SilentlyContinue
            if ($txt.Trim() -ne '') { return $txt }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

# POST Overpass com --data-urlencode "data@arquivo" (a consulta tem acentos; passar por arquivo preserva o UTF-8)
function AreaOverpassPost([string]$Consulta, [string]$Nome) {
    AreaGarantirPastaTmp
    $arqQ = Join-Path $script:AreaPastaTmp "$Nome-q.txt"
    $arqR = Join-Path $script:AreaPastaTmp "$Nome.json"
    [System.IO.File]::WriteAllText($arqQ, $Consulta, (New-Object System.Text.UTF8Encoding($false)))
    $txt = $null
    # O overpass-api.de dá 504 ("Dispatcher_Client ... timeout") de vez em quando e às vezes 200 com "remark" de erro: até 5 tentativas, pausas crescentes
    $pausas = @(3, 6, 10, 15, 0)
    for ($tent = 1; $tent -le 5; $tent++) {
        $espera = 1.0 - ((Get-Date) - $script:AreaUltimoOverpass).TotalSeconds
        if ($espera -gt 0) { Start-Sleep -Milliseconds ([int]($espera * 1000) + 50) }
        if (Test-Path $arqR) { Remove-Item $arqR -Force -ErrorAction SilentlyContinue }
        $codigo = & $script:AreaCurl -s -A $script:AreaUA --max-time 90 -o $arqR -w '%{http_code}' --data-urlencode "data@$arqQ" 'https://overpass-api.de/api/interpreter' 2>$null
        $script:AreaUltimoOverpass = Get-Date
        if ($LASTEXITCODE -eq 0 -and "$codigo" -eq '200' -and (Test-Path $arqR)) {
            $t = [System.IO.File]::ReadAllText($arqR, [System.Text.Encoding]::UTF8)
            if ($t -match '"elements"' -and -not ($t -match '"remark"\s*:\s*"[^"]*(error|timed out|timeout)')) { $txt = $t; break }
        }
        Start-Sleep -Seconds $pausas[$tent - 1]
    }
    Remove-Item $arqQ -Force -ErrorAction SilentlyContinue
    Remove-Item $arqR -Force -ErrorAction SilentlyContinue
    return $txt
}

# ---------------------------------------------------------------------------------------------
# Polígonos
# ---------------------------------------------------------------------------------------------
function Import-Poligonos {
    param([string]$Pasta = '')
    if ([string]::IsNullOrWhiteSpace($Pasta)) { $Pasta = $script:AreaPastaPoligonosPadrao }
    if (-not (Test-Path $Pasta)) { throw "Pasta de polígonos não encontrada: $Pasta" }
    $ser = AreaSerializer
    $tabela = @{}
    foreach ($arq in (Get-ChildItem -Path $Pasta -Filter '*.geojson' | Sort-Object Name)) {
        $obj = $ser.DeserializeObject([System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8))
        $feat = $obj
        if ($obj.ContainsKey('features')) { $feat = $obj['features'][0] }
        $geom = $feat['geometry']
        if ($geom['type'] -ne 'Polygon') { throw "$($arq.Name): geometria $($geom['type']) não é Polygon" }
        $coords = $geom['coordinates'][0]
        $anel = New-Object System.Collections.Generic.List[object]
        foreach ($c in $coords) { $anel.Add([double[]]@([double]$c[0], [double]$c[1])) }
        $nome = ''
        if ($feat.ContainsKey('properties') -and $feat['properties'].ContainsKey('nome')) { $nome = [string]$feat['properties']['nome'] }
        if ($nome -eq '') { $nome = (Get-Culture).TextInfo.ToTitleCase($arq.BaseName) }
        $tabela[$nome] = @{ nome = $nome; anel = $anel.ToArray(); arquivo = $arq.FullName }
    }
    if ($tabela.Count -eq 0) { throw "Nenhum .geojson em $Pasta" }
    $script:AreaPoligonos = $tabela
    return $tabela
}

function AreaPoligonosCarregados {
    if ($null -eq $script:AreaPoligonos) { Import-Poligonos -Pasta $script:AreaPastaPoligonosPadrao | Out-Null }
    return $script:AreaPoligonos
}

# Ray casting. $Anel = lista de pares [lon, lat] (anel fechado ou não, tanto faz).
function Test-PontoNoPoligono {
    param([Parameter(Mandatory = $true)][double]$Lat, [Parameter(Mandatory = $true)][double]$Lon, [Parameter(Mandatory = $true)]$Anel)
    $n = $Anel.Count
    $dentro = $false
    $j = $n - 1
    for ($i = 0; $i -lt $n; $i++) {
        $xi = [double]$Anel[$i][0]; $yi = [double]$Anel[$i][1]
        $xj = [double]$Anel[$j][0]; $yj = [double]$Anel[$j][1]
        if ((($yi -gt $Lat) -ne ($yj -gt $Lat)) -and ($Lon -lt (($xj - $xi) * ($Lat - $yi) / ($yj - $yi) + $xi))) { $dentro = -not $dentro }
        $j = $i
    }
    return $dentro
}

# Menor distância (m) do ponto à borda do anel
function Get-DistanciaBordaMetros {
    param([Parameter(Mandatory = $true)][double]$Lat, [Parameter(Mandatory = $true)][double]$Lon, [Parameter(Mandatory = $true)]$Anel)
    $n = $Anel.Count
    $menor = [double]::MaxValue
    for ($i = 0; $i -lt $n - 1; $i++) {
        $d = AreaDistSegmento $Lat $Lon ([double]$Anel[$i][1]) ([double]$Anel[$i][0]) ([double]$Anel[$i + 1][1]) ([double]$Anel[$i + 1][0])
        if ($d -lt $menor) { $menor = $d }
    }
    # fecha o anel se o último ponto não repete o primeiro
    if ($n -ge 2 -and (([double]$Anel[0][0] -ne [double]$Anel[$n - 1][0]) -or ([double]$Anel[0][1] -ne [double]$Anel[$n - 1][1]))) {
        $d = AreaDistSegmento $Lat $Lon ([double]$Anel[$n - 1][1]) ([double]$Anel[$n - 1][0]) ([double]$Anel[0][1]) ([double]$Anel[0][0])
        if ($d -lt $menor) { $menor = $d }
    }
    return $menor
}

# Área do anel em km² (shoelace em metros, projeção equiretangular)
function Get-AreaKm2 {
    param([Parameter(Mandatory = $true)]$Anel)
    $n = $Anel.Count
    if ($n -lt 3) { return 0.0 }
    $lat0 = [double]$Anel[0][1]; $lon0 = [double]$Anel[0][0]
    $soma = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $k = ($i + 1) % $n
        $a = AreaXY ([double]$Anel[$i][1]) ([double]$Anel[$i][0]) $lat0 $lon0
        $b = AreaXY ([double]$Anel[$k][1]) ([double]$Anel[$k][0]) $lat0 $lon0
        $soma += $a[0] * $b[1] - $b[0] * $a[1]
    }
    return [Math]::Abs($soma) / 2.0 / 1e6
}

# Em qual polígono o ponto cai (ou o mais próximo, se fora) e a distância à borda
function Get-PoligonoDoPonto {
    param([Parameter(Mandatory = $true)][double]$Lat, [Parameter(Mandatory = $true)][double]$Lon)
    $pols = AreaPoligonosCarregados
    $dentroDe = ''; $distDentro = [double]::MaxValue
    $maisProximo = ''; $distFora = [double]::MaxValue
    foreach ($nome in ($pols.Keys | Sort-Object)) {
        $anel = $pols[$nome].anel
        $d = Get-DistanciaBordaMetros -Lat $Lat -Lon $Lon -Anel $anel
        if (Test-PontoNoPoligono -Lat $Lat -Lon $Lon -Anel $anel) {
            if ($d -lt $distDentro -or $dentroDe -eq '') { $dentroDe = $nome; $distDentro = $d }
        }
        if ($d -lt $distFora) { $maisProximo = $nome; $distFora = $d }
    }
    if ($dentroDe -ne '') { return [pscustomobject]@{ dentro = $true; poligono = $dentroDe; distancia = [Math]::Round($distDentro, 1) } }
    return [pscustomobject]@{ dentro = $false; poligono = $maisProximo; distancia = [Math]::Round($distFora, 1) }
}

# ---------------------------------------------------------------------------------------------
# Nomes de rua
# ---------------------------------------------------------------------------------------------
function Normalize-Rua {
    param([string]$Rua)
    if ([string]::IsNullOrWhiteSpace($Rua)) { return '' }
    $s = (AreaSemAcento $Rua).ToLowerInvariant().Trim()
    $s = $s -replace '\s+-\s+.*$', ''      # sufixo tipo "Rua X - Copacabana Rio de Janeiro - RJ Brasil" (lixo de alguns sites)
    $s = $s -replace '[,;]', ' '
    $s = $s -replace '[’‘`´]', "'"
    $s = $s -replace '\s+', ' '
    # tipo de via abreviado no início
    $s = $s -replace '^r\.?\s+', 'rua '
    $s = $s -replace '^av(da)?\.?\s+', 'avenida '
    $s = $s -replace '^p(ca|c|raca)\.?\s+', 'praca '
    $s = $s -replace '^al\.?\s+', 'alameda '
    $s = $s -replace '^(tv|trav)\.?\s+', 'travessa '
    $s = $s -replace '^estr\.?\s+', 'estrada '
    # abreviações dentro do nome
    $s = $s -replace '\bvisc\.?\s+', 'visconde '
    $s = $s -replace '\bgen\.?\s+', 'general '
    $s = $s -replace '\bprof\.?\s+', 'professor '
    $s = $s -replace '\balm\.?\s+', 'almirante '
    $s = $s -replace '\bdes\.?\s+', 'desembargador '
    $s = $s -replace '\bn\.?\s*s(ra|r)?\.?\s+(de\s+)?copacabana', 'nossa senhora de copacabana'
    $s = $s -replace '\bnossa\s+sra\.?\s+', 'nossa senhora '
    # variantes de grafia
    $s = $s -replace '\belisabeth\b', 'elizabeth'
    $s = $s -replace '\s+da\s+belgica$', ''
    $s = $s -replace '\bmoraes\b', 'morais'
    $s = $s -replace '\bgois\b', 'goes'
    $s = $s -replace "\bd\s*'\s*avila\b|\bd\s+avila\b", 'davila'
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

# Nome normalizado sem o tipo de via ("rua visconde de piraja" -> "visconde de piraja")
function AreaNucleoRua([string]$normalizado) {
    if ([string]::IsNullOrWhiteSpace($normalizado)) { return '' }
    return ($normalizado -replace '^(rua|avenida|praca|alameda|travessa|estrada|largo|ladeira|beco)\s+', '').Trim()
}

# Núcleo sem os conectivos de/da/do/das/dos/e (para a segunda chance do casamento de nomes)
function AreaSemConectivos([string]$nucleo) {
    if ([string]::IsNullOrWhiteSpace($nucleo)) { return '' }
    return (($nucleo -replace '\b(de|da|do|das|dos|e)\b', ' ') -replace '\s+', ' ').Trim()
}

# Faixa de números de ruas.csv ("até 158", "160 a 376", "672 ao fim", "até 125/126", "127/128 ao fim") -> @{ min; max }
function AreaFaixa([string]$faixa) {
    $f = (AreaSemAcento $faixa).ToLowerInvariant().Trim()
    if ($f -eq '') { return @{ min = $null; max = $null } }
    $nums = @([regex]::Matches($f, '\d+') | ForEach-Object { [int]$_.Value })
    if ($nums.Count -eq 0) { return @{ min = $null; max = $null } }
    if ($f -match '^ate\b') { return @{ min = $null; max = ($nums | Measure-Object -Maximum).Maximum } }
    if ($f -match 'ao fim$') { return @{ min = ($nums | Measure-Object -Minimum).Minimum; max = $null } }
    if ($nums.Count -ge 2) { return @{ min = $nums[0]; max = $nums[$nums.Count - 1] } }
    return @{ min = $nums[0]; max = $nums[0] }
}

function AreaRuasCarregadas {
    if ($null -ne $script:AreaRuas) { return $script:AreaRuas }
    if (-not (Test-Path $script:AreaArquivoRuas)) { throw "ruas.csv não encontrado: $($script:AreaArquivoRuas)" }
    $linhas = @(Import-Csv -Path $script:AreaArquivoRuas -Delimiter ';' -Encoding UTF8)
    $lista = New-Object System.Collections.Generic.List[object]
    foreach ($l in $linhas) {
        if ([string]::IsNullOrWhiteSpace($l.rua)) { continue }
        $fx = AreaFaixa ([string]$l.faixa)
        $lado = (AreaSemAcento ([string]$l.lado)).ToLowerInvariant().Trim()
        $sit = (AreaSemAcento ([string]$l.situacao)).ToLowerInvariant().Trim()
        $lista.Add([pscustomobject]@{
            rua = [string]$l.rua; nucleo = AreaNucleoRua (Normalize-Rua ([string]$l.rua)); poligono = [string]$l.poligono
            bairro_cep = [string]$l.bairro_cep; cep = [string]$l.cep; faixa = [string]$l.faixa; min = $fx.min; max = $fx.max
            lado = $lado; situacao = $sit; situacao_texto = [string]$l.situacao; observacao = [string]$l.observacao
        })
    }
    $script:AreaRuas = $lista.ToArray()
    return $script:AreaRuas
}

# situacao: incluida | pendente | fora ; linha = linha de ruas.csv que casou (ou $null)
function Test-RuaNaLista {
    param([string]$Rua, [string]$Numero = '')
    $nucleo = AreaNucleoRua (Normalize-Rua $Rua)
    if ($nucleo -eq '') { return [pscustomobject]@{ situacao = 'fora'; linha = $null; poligono = ''; motivo = 'sem rua' } }
    $ruas = AreaRuasCarregadas
    $candidatas = @($ruas | Where-Object { $_.nucleo -eq $nucleo })
    if ($candidatas.Count -eq 0) {
        # segunda chance: sem os conectivos ("Bulhões Carvalho" = "Bulhões de Carvalho")
        $semConectivo = AreaSemConectivos $nucleo
        $candidatas = @($ruas | Where-Object { (AreaSemConectivos $_.nucleo) -eq $semConectivo })
    }
    if ($candidatas.Count -eq 0) { return [pscustomobject]@{ situacao = 'fora'; linha = $null; poligono = ''; motivo = 'rua fora da lista' } }
    $numTxt = AreaSoDigitos $Numero
    if ($numTxt -eq '') {
        # sem número: vale a situação da rua (se houver pendente e incluída misturadas, prevalece a incluída)
        $inc = @($candidatas | Where-Object { $_.situacao -eq 'incluida' })
        $l = if ($inc.Count -gt 0) { $inc[0] } else { $candidatas[0] }
        return [pscustomobject]@{ situacao = $l.situacao; linha = $l; poligono = $l.poligono; motivo = "rua na lista ($($l.situacao_texto)); sem número" }
    }
    $num = [int]$numTxt
    $par = ($num % 2 -eq 0)
    foreach ($l in $candidatas) {
        if ($l.lado -eq 'par' -and -not $par) { continue }
        if ($l.lado -eq 'impar' -and $par) { continue }
        if ($null -ne $l.min -and $num -lt $l.min) { continue }
        if ($null -ne $l.max -and $num -gt $l.max) { continue }
        $fx = if ($l.faixa -ne '') { " (faixa $($l.faixa)$(if ($l.lado) { ", $($l.lado)" }))" } else { '' }
        return [pscustomobject]@{ situacao = $l.situacao; linha = $l; poligono = $l.poligono; motivo = "rua na lista ($($l.situacao_texto))$fx" }
    }
    return [pscustomobject]@{ situacao = 'fora'; linha = $null; poligono = ''; motivo = "rua na lista, mas nº $num fora das faixas listadas" }
}

# ---------------------------------------------------------------------------------------------
# Geocodificação
# ---------------------------------------------------------------------------------------------
function AreaChaveCache([string]$rua, [string]$numero, [string]$bairro) {
    return ((AreaNucleoRua (Normalize-Rua $rua)) + '|' + (AreaSoDigitos $numero) + '|' + (AreaSemAcento ([string]$bairro)).ToLowerInvariant().Trim())
}

function AreaGeocacheCarregado {
    if ($null -ne $script:AreaGeocache) { return $script:AreaGeocache }
    $tab = @{}
    if (Test-Path $script:AreaGeocachePath) {
        foreach ($l in @(Import-Csv -Path $script:AreaGeocachePath -Delimiter ';' -Encoding UTF8)) {
            $k = AreaChaveCache ([string]$l.rua) ([string]$l.numero) ([string]$l.bairro)
            # a última ocorrência da chave vale (uma consulta refeita depois de falha transitória do Overpass é acrescentada no fim)
            $det = if ($l.PSObject.Properties['detalhe']) { [string]$l.detalhe } else { '' }
            $tab[$k] = [pscustomobject]@{ lat = (AreaToNum ([string]$l.lat)); lon = (AreaToNum ([string]$l.lon)); precisao = [string]$l.precisao; detalhe = $det; consultado_em = [string]$l.consultado_em; origem = 'cache' }
        }
    }
    $script:AreaGeocache = $tab
    return $tab
}

function AreaGeocacheGravar([string]$rua, [string]$numero, [string]$bairro, $res) {
    $pasta = Split-Path -Parent $script:AreaGeocachePath
    if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }
    $novo = -not (Test-Path $script:AreaGeocachePath)
    $utf8bom = New-Object System.Text.UTF8Encoding($true)
    if ($novo) { [System.IO.File]::WriteAllText($script:AreaGeocachePath, "rua;numero;bairro;lat;lon;precisao;consultado_em;detalhe`r`n", $utf8bom) }
    $campos = @($rua, $numero, $bairro, (AreaFmt $res.lat 7), (AreaFmt $res.lon 7), $res.precisao, $res.consultado_em, $res.detalhe) | ForEach-Object {
        $v = [string]$_
        if ($v -match '[;"\r\n]') { '"' + ($v -replace '"', '""') + '"' } else { $v }
    }
    [System.IO.File]::AppendAllText($script:AreaGeocachePath, (($campos -join ';') + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# Consulta Nominatim (structured), respeitando 1,1 s entre pedidos. Devolve a lista de resultados (dicionários) ou @().
function AreaNominatim([string]$rua, [string]$numero) {
    $espera = 1.1 - ((Get-Date) - $script:AreaUltimoNominatim).TotalSeconds
    if ($espera -gt 0) { Start-Sleep -Milliseconds ([int]($espera * 1000) + 20) }
    $street = if ($numero -ne '') { "$numero $rua" } else { $rua }
    $url = 'https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=3&street=' + [Uri]::EscapeDataString($street) +
           '&city=Rio%20de%20Janeiro&state=RJ&country=Brazil'
    $txt = AreaHttpGet $url 'nominatim'
    $script:AreaUltimoNominatim = Get-Date
    if ($null -eq $txt) { return $null }   # falha de rede
    try { $obj = (AreaSerializer).DeserializeObject($txt) } catch { return $null }
    if ($obj -is [System.Collections.IDictionary]) { return @() }   # {"error":...}
    return @($obj)
}

# Overpass: números de porta e geometria das vias com esse nome (núcleo na grafia do OSM). Cache por rodada.
function AreaOverpassRua([string]$nomeOsm) {
    $core = ($nomeOsm -replace '^(Rua|Avenida|Praça|Praca|Alameda|Travessa|Estrada|Largo|Ladeira|Beco)\s+', '').Trim()
    if ($core -eq '') { return $null }
    $k = $core.ToLowerInvariant()
    if ($script:AreaOverpassCache.ContainsKey($k)) { return $script:AreaOverpassCache[$k] }
    $rx = $core -replace '([.+*?()\[\]{}|^$\\])', '\$1'
    # Duas saídas separadas: "out center tags" para os endereços (com "geom" junto o Overpass omite o center dos prédios) e "out geom" para as vias
    $q = "[out:json][timeout:60];nwr[""addr:housenumber""][""addr:street""~""$rx"",i]$($script:AreaBBox);out center tags;way[""highway""][""name""~""$rx"",i]$($script:AreaBBox);out geom;"
    $txt = AreaOverpassPost $q 'overpass'
    if ($null -eq $txt) { $script:AreaOverpassCache[$k] = $null; return $null }
    $obj = (AreaSerializer).DeserializeObject($txt)
    $numeros = New-Object System.Collections.Generic.List[object]
    $vias = New-Object System.Collections.Generic.List[object]
    foreach ($e in $obj['elements']) {
        $tags = if ($e.ContainsKey('tags')) { $e['tags'] } else { @{} }
        if ($e['type'] -eq 'way' -and $tags.ContainsKey('highway') -and $e.ContainsKey('geometry')) {
            $pts = New-Object System.Collections.Generic.List[object]
            foreach ($p in $e['geometry']) { $pts.Add(@([double]$p['lat'], [double]$p['lon'])) }
            if ($pts.Count -ge 2) { $vias.Add($pts.ToArray()) }
            continue
        }
        if (-not $tags.ContainsKey('addr:housenumber')) { continue }
        $la = $null; $lo = $null
        if ($e.ContainsKey('center')) { $la = $e['center']['lat']; $lo = $e['center']['lon'] }
        elseif ($e.ContainsKey('lat')) { $la = $e['lat']; $lo = $e['lon'] }
        elseif ($e.ContainsKey('geometry')) {
            # reserva: centroide dos nós da geometria (way de prédio devolvido com geom)
            $sl = 0.0; $so = 0.0; $nn = 0
            foreach ($p in $e['geometry']) { if ($null -ne $p -and $p.ContainsKey('lat')) { $sl += [double]$p['lat']; $so += [double]$p['lon']; $nn++ } }
            if ($nn -gt 0) { $la = $sl / $nn; $lo = $so / $nn }
        }
        if ($null -eq $la) { continue }
        $nTxt = AreaSoDigitos ([string]$tags['addr:housenumber'])
        if ($nTxt -eq '') { continue }
        $numeros.Add([pscustomobject]@{ n = [int]$nTxt; lat = [double]$la; lon = [double]$lo })
    }
    $r = @{ numeros = $numeros.ToArray(); vias = $vias.ToArray() }
    $script:AreaOverpassCache[$k] = $r
    return $r
}

# Posição do número a partir dos números de porta do OSM: exato, ou interpolado ao longo do eixo da via (ajuste linear nº x posição,
# lado por paridade), ou o número mais próximo. Devolve @{lat;lon;precisao;detalhe} ou $null.
function AreaInterpolarNumero([int]$num, $dados) {
    if ($null -eq $dados) { return $null }
    $numeros = @($dados.numeros); $vias = @($dados.vias)
    if ($numeros.Count -eq 0) { return $null }
    # exato (média dos elementos com o mesmo número)
    $exatos = @($numeros | Where-Object { $_.n -eq $num })
    if ($exatos.Count -gt 0) {
        $la = ($exatos | Measure-Object -Property lat -Average).Average; $lo = ($exatos | Measure-Object -Property lon -Average).Average
        return @{ lat = $la; lon = $lo; precisao = 'numero'; detalhe = "nº $num existe no OSM (addr:housenumber)" }
    }
    if ($vias.Count -gt 0) {
        # eixo principal da via por PCA dos nós (em metros)
        $todos = New-Object System.Collections.Generic.List[object]
        foreach ($v in $vias) { foreach ($p in $v) { $todos.Add($p) } }
        $lat0 = ($todos | ForEach-Object { $_[0] } | Measure-Object -Average).Average
        $lon0 = ($todos | ForEach-Object { $_[1] } | Measure-Object -Average).Average
        $sxx = 0.0; $syy = 0.0; $sxy = 0.0
        foreach ($p in $todos) { $xy = AreaXY $p[0] $p[1] $lat0 $lon0; $sxx += $xy[0] * $xy[0]; $syy += $xy[1] * $xy[1]; $sxy += $xy[0] * $xy[1] }
        $ang = 0.5 * [Math]::Atan2(2 * $sxy, $sxx - $syy)
        $dx = [Math]::Cos($ang); $dy = [Math]::Sin($ang)      # direção do eixo
        $nx = -$dy; $ny = $dx                                 # normal (esquerda)
        # posição de cada número conhecido: s = projeção no eixo PCA (ordem ao longo da rua); perp = distância ao segmento mais próximo
        # da via (eixo local, porque a rua pode ser curva), com sinal dado pela normal PCA (lado consistente)
        $segs = @()
        foreach ($v in $vias) { for ($i = 0; $i -lt $v.Count - 1; $i++) { $segs += , @((AreaXY $v[$i][0] $v[$i][1] $lat0 $lon0), (AreaXY $v[$i + 1][0] $v[$i + 1][1] $lat0 $lon0)) } }
        $conhecidos = @($numeros | ForEach-Object {
            $xy = AreaXY $_.lat $_.lon $lat0 $lon0
            $melhorD = [double]::MaxValue; $vx = 0.0; $vy = 0.0
            foreach ($sg in $segs) {
                $ax = $sg[0][0]; $ay = $sg[0][1]; $bx = $sg[1][0]; $by = $sg[1][1]
                $ux = $bx - $ax; $uy = $by - $ay; $l2 = $ux * $ux + $uy * $uy
                $tt = if ($l2 -gt 0) { (($xy[0] - $ax) * $ux + ($xy[1] - $ay) * $uy) / $l2 } else { 0 }
                if ($tt -lt 0) { $tt = 0 } elseif ($tt -gt 1) { $tt = 1 }
                $qx = $ax + $tt * $ux; $qy = $ay + $tt * $uy
                $dd = [Math]::Sqrt(($xy[0] - $qx) * ($xy[0] - $qx) + ($xy[1] - $qy) * ($xy[1] - $qy))
                if ($dd -lt $melhorD) { $melhorD = $dd; $vx = $xy[0] - $qx; $vy = $xy[1] - $qy }
            }
            $sinalLocal = [Math]::Sign($vx * $nx + $vy * $ny); if ($sinalLocal -eq 0) { $sinalLocal = 1 }
            [pscustomobject]@{ n = $_.n; s = ($xy[0] * $dx + $xy[1] * $dy); perp = ($sinalLocal * $melhorD) }
        })
        $par = ($num % 2 -eq 0)
        $mesmaParidade = @($conhecidos | Where-Object { ($_.n % 2 -eq 0) -eq $par })
        # primeiro o ajuste só com os números do mesmo lado (paridade); se ele não alcança o número pedido, o ajuste com todos
        $conjuntos = @()
        if (@($mesmaParidade | Select-Object -ExpandProperty n -Unique).Count -ge 2) { $conjuntos += , $mesmaParidade }
        if (@($conhecidos | Select-Object -ExpandProperty n -Unique).Count -ge 2) { $conjuntos += , $conhecidos }
        for ($ci = 0; $ci -lt $conjuntos.Count; $ci++) {
          $conj = $conjuntos[$ci]
          $lado = if ($ci -eq 0 -and $conjuntos.Count -eq 2) { 'mesma paridade' } else { 'todos os números' }
          $distintos = @($conj | Select-Object -ExpandProperty n -Unique)
          if ($distintos.Count -ge 2) {
            # mínimos quadrados: n = a + b*s
            $mediaS = ($conj | Measure-Object -Property s -Average).Average
            $mediaN = ($conj | Measure-Object -Property n -Average).Average
            $sss = 0.0; $ssn = 0.0; $snn = 0.0
            foreach ($c in $conj) { $sss += ($c.s - $mediaS) * ($c.s - $mediaS); $ssn += ($c.s - $mediaS) * ($c.n - $mediaN); $snn += ($c.n - $mediaN) * ($c.n - $mediaN) }
            if ($sss -gt 0 -and $snn -gt 0) {
                $b = $ssn / $sss; $a = $mediaN - $b * $mediaS
                $r2 = ($ssn * $ssn) / ($sss * $snn)
                $sMin = ($conj | Measure-Object -Property s -Minimum).Minimum; $sMax = ($conj | Measure-Object -Property s -Maximum).Maximum
                if ([Math]::Abs($b) -gt 1e-6 -and $r2 -ge 0.7) {
                    $sAlvo = ($num - $a) / $b
                    if ($sAlvo -ge $sMin - 120 -and $sAlvo -le $sMax + 120) {
                        # ponto do eixo com projeção sAlvo (procura um segmento que a contenha)
                        $melhor = $null; $melhorPerp = [double]::MaxValue
                        foreach ($v in $vias) {
                            for ($i = 0; $i -lt $v.Count - 1; $i++) {
                                $p1 = AreaXY $v[$i][0] $v[$i][1] $lat0 $lon0; $p2 = AreaXY $v[$i + 1][0] $v[$i + 1][1] $lat0 $lon0
                                $s1 = $p1[0] * $dx + $p1[1] * $dy; $s2 = $p2[0] * $dx + $p2[1] * $dy
                                if (($sAlvo -ge [Math]::Min($s1, $s2)) -and ($sAlvo -le [Math]::Max($s1, $s2)) -and ([Math]::Abs($s2 - $s1) -gt 0.01)) {
                                    $t = ($sAlvo - $s1) / ($s2 - $s1)
                                    $px = $p1[0] + $t * ($p2[0] - $p1[0]); $py = $p1[1] + $t * ($p2[1] - $p1[1])
                                    $perpAqui = [Math]::Abs($px * $nx + $py * $ny)
                                    if ($perpAqui -lt $melhorPerp) { $melhorPerp = $perpAqui; $melhor = @($px, $py) }
                                }
                            }
                        }
                        if ($null -eq $melhor) {
                            # fora de qualquer segmento: nó com projeção mais próxima
                            $noMaisPerto = $null; $difMin = [double]::MaxValue
                            foreach ($p in $todos) { $xy = AreaXY $p[0] $p[1] $lat0 $lon0; $dif = [Math]::Abs(($xy[0] * $dx + $xy[1] * $dy) - $sAlvo); if ($dif -lt $difMin) { $difMin = $dif; $noMaisPerto = $xy } }
                            $melhor = $noMaisPerto
                        }
                        # lado da via pela paridade (sinal médio dos números conhecidos da mesma paridade; senão o oposto da outra)
                        $sinal = 0.0; $mag = 15.0
                        $mp = @($mesmaParidade)
                        if ($mp.Count -gt 0) { $sinal = [Math]::Sign(($mp | Measure-Object -Property perp -Average).Average); $mag = [Math]::Abs(($mp | Measure-Object -Property perp -Average).Average) }
                        elseif ($conhecidos.Count -gt 0) { $sinal = -[Math]::Sign(($conhecidos | Measure-Object -Property perp -Average).Average); $mag = [Math]::Abs(($conhecidos | Measure-Object -Property perp -Average).Average) }
                        if ($mag -lt 8) { $mag = 8 } elseif ($mag -gt 25) { $mag = 25 }
                        $fx = $melhor[0] + $sinal * $mag * $nx; $fy = $melhor[1] + $sinal * $mag * $ny
                        $ll = AreaLatLon $fx $fy $lat0 $lon0
                        $nMin = ($conj | Measure-Object -Property n -Minimum).Minimum; $nMax = ($conj | Measure-Object -Property n -Maximum).Maximum
                        $extra = if ($num -lt $nMin -or $num -gt $nMax) { ', extrapolado' } else { '' }
                        return @{ lat = $ll[0]; lon = $ll[1]; precisao = 'interpolado'; detalhe = "interpolado pelos nºs OSM $nMin-$nMax ($($conj.Count) pontos, $lado, R2 $([Math]::Round($r2, 2))$extra)" }
                    }
                }
            }
          }
        }
    }
    # número mais próximo (até 60 de diferença) vale como ponto da rua
    $perto = $numeros | Sort-Object { [Math]::Abs($_.n - $num) } | Select-Object -First 1
    if ($null -ne $perto -and [Math]::Abs($perto.n - $num) -le 60) {
        return @{ lat = $perto.lat; lon = $perto.lon; precisao = 'rua'; detalhe = "nº OSM mais próximo: $($perto.n)" }
    }
    return $null
}

# Get-Geocode -Rua -Numero -Bairro -> @{ lat; lon; precisao (numero|interpolado|rua|falhou); detalhe; origem (cache|consulta) }
function Get-Geocode {
    param([string]$Rua, [string]$Numero = '', [string]$Bairro = '')
    $ruaTxt = ([string]$Rua).Trim(); $numTxt = AreaSoDigitos $Numero; $bairroTxt = ([string]$Bairro).Trim()
    if ($ruaTxt -eq '') { return [pscustomobject]@{ lat = $null; lon = $null; precisao = 'falhou'; detalhe = 'sem rua'; origem = 'nenhuma' } }
    $cache = AreaGeocacheCarregado
    $k = AreaChaveCache $ruaTxt $numTxt $bairroTxt
    # nunca repete consulta que está no cache (inclusive as que falharam); a única exceção é resultado degradado por
    # indisponibilidade momentânea do Overpass, que pode ser refeito (a nova linha é acrescentada e passa a valer)
    if ($cache.ContainsKey($k) -and -not ($cache[$k].detalhe -match 'Overpass indisponível')) { return $cache[$k] }

    $agora = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    $res = @{ lat = $null; lon = $null; precisao = 'falhou'; detalhe = ''; consultado_em = $agora }
    $nucleo = AreaNucleoRua (Normalize-Rua $ruaTxt)
    $resultados = AreaNominatim $ruaTxt $numTxt
    if ($null -eq $resultados) {
        # falha de rede/serviço: não grava no cache, para tentar de novo na próxima rodada
        return [pscustomobject]@{ lat = $null; lon = $null; precisao = 'falhou'; detalhe = 'Nominatim indisponível'; origem = 'erro' }
    }
    $nomeOsm = ''; $viaResultado = $null; $poiNaRua = $null
    foreach ($r in $resultados) {
        $addr = if ($r.ContainsKey('address')) { $r['address'] } else { @{} }
        $road = if ($addr.ContainsKey('road')) { [string]$addr['road'] } else { '' }
        $nomeRes = if ($r.ContainsKey('name')) { [string]$r['name'] } else { '' }
        $tipoEnd = if ($r.ContainsKey('addresstype')) { [string]$r['addresstype'] } else { '' }
        $hn = if ($addr.ContainsKey('house_number')) { AreaSoDigitos ([string]$addr['house_number']) } else { '' }
        $roadOk = ($road -ne '' -and (AreaNucleoRua (Normalize-Rua $road)) -eq $nucleo)
        $nomeOk = ($tipoEnd -eq 'road' -and $nomeRes -ne '' -and (AreaNucleoRua (Normalize-Rua $nomeRes)) -eq $nucleo)
        if ($roadOk -and $nomeOsm -eq '') { $nomeOsm = $road }
        if ($nomeOk -and $nomeOsm -eq '') { $nomeOsm = $nomeRes }
        if ($numTxt -ne '' -and $hn -eq $numTxt -and ($roadOk -or ((AreaSemAcento ([string]$r['display_name'])).ToLowerInvariant() -match [regex]::Escape($nucleo)))) {
            $res.lat = [double]$r['lat']; $res.lon = [double]$r['lon']; $res.precisao = 'numero'
            $res.detalhe = "Nominatim: $($r['display_name'])"
            break
        }
        if ($null -eq $viaResultado -and $nomeOk) { $viaResultado = $r }
        if ($null -eq $poiNaRua -and $roadOk -and $tipoEnd -ne 'road') { $poiNaRua = $r }
    }
    if ($res.precisao -ne 'numero' -and $nomeOsm -ne '') {
        # números de porta do OSM na própria via (Overpass)
        $dados = $null
        try { $dados = AreaOverpassRua $nomeOsm } catch { $dados = $null }
        if ($numTxt -ne '') {
            $inter = AreaInterpolarNumero ([int]$numTxt) $dados
            if ($null -ne $inter) { $res.lat = $inter.lat; $res.lon = $inter.lon; $res.precisao = $inter.precisao; $res.detalhe = $inter.detalhe }
        }
        if ($res.precisao -eq 'falhou') {
            # fica com a via: resultado "road" com o mesmo nome, ou outro resultado que caia a menos de 400 m de uma via com esse nome
            $cand = $null
            if ($null -ne $viaResultado) { $cand = $viaResultado; $res.detalhe = "ponto da via (Nominatim): $($viaResultado['display_name'])" }
            elseif ($null -ne $poiNaRua) {
                $cand = $poiNaRua
                $dMin = [double]::MaxValue
                if ($null -ne $dados -and $dados.vias.Count -gt 0) {
                    foreach ($v in $dados.vias) { for ($i = 0; $i -lt $v.Count - 1; $i++) { $d = AreaDistSegmento ([double]$poiNaRua['lat']) ([double]$poiNaRua['lon']) $v[$i][0] $v[$i][1] $v[$i + 1][0] $v[$i + 1][1]; if ($d -lt $dMin) { $dMin = $d } } }
                    if ($dMin -gt $script:AreaLimites.geocodeVia) { $cand = $null }
                }
                if ($null -ne $cand) { $res.detalhe = "resultado na mesma via (Nominatim): $($poiNaRua['display_name'])" }
            }
            if ($null -ne $cand) { $res.lat = [double]$cand['lat']; $res.lon = [double]$cand['lon']; $res.precisao = 'rua' }
        }
        if ($null -eq $dados -and $res.precisao -ne 'numero') { $res.detalhe += ' [Overpass indisponível]' }
    }
    if ($res.precisao -eq 'falhou' -and $res.detalhe -eq '') { $res.detalhe = if ($resultados.Count -eq 0) { 'Nominatim sem resultado' } else { 'Nominatim sem resultado na via pedida' } }
    AreaGeocacheGravar $ruaTxt $numTxt $bairroTxt $res
    $obj = [pscustomobject]@{ lat = $res.lat; lon = $res.lon; precisao = $res.precisao; detalhe = $res.detalhe; consultado_em = $res.consultado_em; origem = 'consulta' }
    $cache[$k] = $obj
    return $obj
}

# ---------------------------------------------------------------------------------------------
# Decisão de área (passos 1 a 4 do contrato)
# ---------------------------------------------------------------------------------------------
function AreaDecidirPorCoordenada([double]$lat, [double]$lon, [string]$modo, $listaRua) {
    # $modo = 'exata' (passo 1) | 'aproximada' (passo 2); $listaRua = resultado de Test-RuaNaLista (para o motivo)
    $p = Get-PoligonoDoPonto -Lat $lat -Lon $lon
    $d = [Math]::Round($p.distancia)
    $lim = $script:AreaLimites
    $sufixoRua = ''
    if ($null -ne $listaRua) {
        if ($listaRua.situacao -eq 'incluida') { $sufixoRua = '; rua na lista' }
        elseif ($listaRua.situacao -eq 'pendente') { $sufixoRua = '; via pendente' }
        elseif ($listaRua.motivo -ne 'sem rua') { $sufixoRua = '; rua fora da lista' }
    }
    # ---- Regras v2 (11/10/2026, depois da primeira coleta real): a lista de ruas do Guilherme pesa como
    # conferência. Ver Skills\CONTRATO-DADOS.md, "Regras de área". Ruas sem classificação caem na regra antiga abaixo.
    $sit = 'semrua'
    if ($null -ne $listaRua) {
        if ($listaRua.situacao -eq 'incluida') { $sit = 'incluida' }
        elseif ($listaRua.situacao -eq 'pendente') { $sit = 'pendente' }
        elseif ($listaRua.motivo -ne 'sem rua') { $sit = 'fora' }
    }
    $pol = $p.poligono
    $tipoCoord = if ($modo -eq 'exata') { 'coordenada' } else { 'coordenada aproximada' }
    $podeConfirmar = ($modo -ne 'exata' -and $p.distancia -le $lim.aproxFora)
    if ($sit -eq 'incluida') {
        if ($p.dentro) { return @{ dentro_area = 'SIM'; motivo_area = "rua na lista; $tipoCoord dentro de $pol, $d m da borda"; poligono = $pol; distancia = $p.distancia } }
        if ($p.distancia -le $lim.limite) { return @{ dentro_area = 'SIM'; motivo_area = "rua na lista; $tipoCoord na borda de $pol ($d m fora)"; poligono = $pol; distancia = $p.distancia } }
        if ($podeConfirmar) { return @{ dentro_area = 'A CONFIRMAR'; motivo_area = "rua na lista, mas $tipoCoord a $d m fora de $pol"; poligono = $pol; distancia = $p.distancia } }
        return @{ dentro_area = 'NAO'; motivo_area = "rua na lista ($($listaRua.motivo)), mas $tipoCoord a $d m fora de $pol (a marcação do mapa prevalece)"; poligono = ''; distancia = $p.distancia }
    }
    if ($sit -eq 'pendente') {
        $nomeVia = if ($null -ne $listaRua.linha) { $listaRua.linha.rua } else { 'pendente' }
        if ($p.dentro) { return @{ dentro_area = 'LIMITE'; motivo_area = "via pendente ($nomeVia); $tipoCoord dentro de $pol, $d m da borda"; poligono = $pol; distancia = $p.distancia } }
        if ($p.distancia -le $lim.limite) { return @{ dentro_area = 'LIMITE'; motivo_area = "via pendente ($nomeVia); $tipoCoord a $d m fora de $pol"; poligono = $pol; distancia = $p.distancia } }
        if ($podeConfirmar) { return @{ dentro_area = 'A CONFIRMAR'; motivo_area = "via pendente ($nomeVia); $tipoCoord a $d m fora de $pol"; poligono = $pol; distancia = $p.distancia } }
        return @{ dentro_area = 'NAO'; motivo_area = "via pendente ($nomeVia); $tipoCoord a $d m fora de $pol"; poligono = ''; distancia = $p.distancia }
    }
    if ($sit -eq 'fora') {
        if ($p.dentro) {
            if ($p.distancia -gt $lim.limite) { return @{ dentro_area = 'SIM'; motivo_area = "$tipoCoord dentro de $pol ($d m da borda); rua não listada ($($listaRua.motivo))"; poligono = $pol; distancia = $p.distancia } }
            return @{ dentro_area = 'LIMITE'; motivo_area = "$tipoCoord dentro de $pol a $d m da borda; rua não listada ($($listaRua.motivo))"; poligono = $pol; distancia = $p.distancia }
        }
        return @{ dentro_area = 'NAO'; motivo_area = "$tipoCoord a $d m fora de $pol; $($listaRua.motivo)"; poligono = ''; distancia = $p.distancia }
    }
    # ---- sem rua: só a coordenada decide (regra original)
    if ($modo -eq 'exata') {
        if ($p.dentro) {
            if ($p.distancia -lt $lim.limite) { return @{ dentro_area = 'LIMITE'; motivo_area = "polígono $($p.poligono), $d m da borda (dentro)$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia } }
            return @{ dentro_area = 'SIM'; motivo_area = "polígono $($p.poligono), $d m da borda$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia }
        }
        if ($p.distancia -lt $lim.limite) { return @{ dentro_area = 'LIMITE'; motivo_area = "fora do polígono $($p.poligono) por $d m$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia } }
        return @{ dentro_area = 'NAO'; motivo_area = "fora dos polígonos ($d m do $($p.poligono))$sufixoRua"; poligono = ''; distancia = $p.distancia }
    }
    # aproximada
    if ($p.dentro) {
        if ($p.distancia -gt $lim.aproxDentro) { return @{ dentro_area = 'SIM'; motivo_area = "coordenada aproximada dentro do polígono $($p.poligono), $d m da borda$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia } }
        return @{ dentro_area = 'LIMITE'; motivo_area = "coordenada aproximada a $d m da borda (dentro de $($p.poligono))$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia }
    }
    if ($p.distancia -gt $lim.aproxFora) {
        if ($null -ne $listaRua -and ($listaRua.situacao -eq 'incluida' -or $listaRua.situacao -eq 'pendente')) {
            # a coordenada aproximada diz fora, mas a rua está na lista: a rua cruza a borda — fica para conferir
            return @{ dentro_area = 'A CONFIRMAR'; motivo_area = "coordenada aproximada a $d m fora do $($p.poligono), mas $($listaRua.motivo)"; poligono = $listaRua.poligono; distancia = $p.distancia }
        }
        return @{ dentro_area = 'NAO'; motivo_area = "coordenada aproximada a $d m fora dos polígonos$sufixoRua"; poligono = ''; distancia = $p.distancia }
    }
    return @{ dentro_area = 'A CONFIRMAR'; motivo_area = "coordenada aproximada a $d m fora do $($p.poligono)$sufixoRua"; poligono = $p.poligono; distancia = $p.distancia }
}

function Resolve-DentroArea {
    param($Lat = $null, $Lon = $null, [string]$PrecisaoCoord = '', [string]$Rua = '', [string]$Numero = '', [string]$BairroSite = '')
    AreaPoligonosCarregados | Out-Null
    $latN = AreaToNum $Lat; $lonN = AreaToNum $Lon
    if ($null -ne $latN -and $null -ne $lonN -and $latN -lt -40 -and $lonN -gt -30) { $tmp = $latN; $latN = $lonN; $lonN = $tmp }   # lat/lon trocados
    $temCoord = ($null -ne $latN -and $null -ne $lonN -and $latN -ne 0 -and $lonN -ne 0)
    $prec = (AreaSemAcento ([string]$PrecisaoCoord)).ToLowerInvariant().Trim()
    if ($temCoord -and ($prec -eq 'bairro' -or $prec -eq 'nenhuma')) { $temCoord = $false }   # centroide do bairro = sem coordenada
    if ($temCoord -and $prec -eq '') { $prec = 'aproximada' }                                   # coordenada sem precisão informada: conservador
    $ruaTxt = ([string]$Rua).Trim(); $numTxt = AreaSoDigitos $Numero
    $lista = if ($ruaTxt -ne '') { Test-RuaNaLista -Rua $ruaTxt -Numero $numTxt } else { $null }
    $saida = [ordered]@{ dentro_area = ''; motivo_area = ''; poligono = ''; lat = $null; lon = $null; distancia_m = $null; passo = 0; precisao_usada = '' }

    # passos 1 e 2: coordenada do próprio anúncio
    if ($temCoord) {
        $modo = if ($prec -eq 'exata') { 'exata' } else { 'aproximada' }
        $r = AreaDecidirPorCoordenada $latN $lonN $modo $lista
        $saida.dentro_area = $r.dentro_area; $saida.motivo_area = $r.motivo_area; $saida.poligono = $r.poligono; $saida.distancia_m = $r.distancia
        $saida.passo = if ($modo -eq 'exata') { 1 } else { 2 }; $saida.precisao_usada = $modo
        return [pscustomobject]$saida
    }

    # passo 3: sem coordenada, com rua e número -> geocodificar
    if ($ruaTxt -ne '' -and $numTxt -ne '') {
        $g = Get-Geocode -Rua $ruaTxt -Numero $numTxt -Bairro $BairroSite
        if ($null -ne $g -and $g.precisao -ne 'falhou' -and $null -ne $g.lat -and $null -ne $g.lon) {
            # número exato ou interpolado pelos números de porta = tratado como exata; ponto da via = aproximada
            $modo = if ($g.precisao -eq 'rua') { 'aproximada' } else { 'exata' }
            $r = AreaDecidirPorCoordenada ([double]$g.lat) ([double]$g.lon) $modo $lista
            $saida.dentro_area = $r.dentro_area; $saida.poligono = $r.poligono; $saida.distancia_m = $r.distancia
            $saida.motivo_area = "geocodificado ($($g.precisao)): " + $r.motivo_area
            $saida.lat = [double]$g.lat; $saida.lon = [double]$g.lon; $saida.passo = 3; $saida.precisao_usada = "geocode-$($g.precisao)"
            return [pscustomobject]$saida
        }
    }

    # passo 4: sem coordenada útil
    $saida.passo = 4; $saida.precisao_usada = 'nenhuma'
    if ($ruaTxt -ne '') {
        if ($lista.situacao -eq 'incluida') { $saida.dentro_area = 'A CONFIRMAR'; $saida.motivo_area = 'rua na lista; sem coordenada'; $saida.poligono = $lista.poligono }
        elseif ($lista.situacao -eq 'pendente') { $saida.dentro_area = 'LIMITE'; $saida.motivo_area = "via pendente ($($lista.linha.rua)); sem coordenada"; $saida.poligono = $lista.poligono }
        else { $saida.dentro_area = 'NAO'; $saida.motivo_area = $lista.motivo; $saida.poligono = '' }
        if ($numTxt -ne '' -and $saida.dentro_area -ne 'NAO') { $saida.motivo_area += '; geocodificação falhou' }
        if ($numTxt -eq '' -and $lista.situacao -ne 'fora') { $saida.motivo_area = $saida.motivo_area -replace 'sem coordenada', 'nº oculto, sem coordenada' }
        return [pscustomobject]$saida
    }
    $bairroN = (AreaSemAcento ([string]$BairroSite)).ToLowerInvariant().Trim()
    $bairroOk = $false
    foreach ($b in $script:AreaBairrosAceitos) { if ($bairroN -match [regex]::Escape($b)) { $bairroOk = $true } }
    if ($bairroOk) { $saida.dentro_area = 'A CONFIRMAR'; $saida.motivo_area = "sem rua e sem coordenada; bairro do site '$BairroSite'" }
    else { $saida.dentro_area = 'NAO'; $saida.motivo_area = "sem rua e sem coordenada; bairro do site '$BairroSite' fora da área" }
    return [pscustomobject]$saida
}

# ---------------------------------------------------------------------------------------------
# Modo linha de comando (só quando chamado com -Teste ou -Endereco; no dot-source nada disto roda)
# ---------------------------------------------------------------------------------------------
if ($Teste) {
    $pastaPol = if ($PastaPoligonos) { $PastaPoligonos } else { $script:AreaPastaPoligonosPadrao }
    Import-Poligonos -Pasta $pastaPol | Out-Null
    foreach ($nomePol in ($script:AreaPoligonos.Keys | Sort-Object)) {
        $anelPol = $script:AreaPoligonos[$nomePol].anel
        Write-Host ("Polígono {0}: {1} vértices, {2:F3} km²" -f $nomePol, $anelPol.Count, (Get-AreaKm2 -Anel $anelPol))
    }
    $arqPontos = Join-Path $pastaPol 'pontos-teste.csv'
    if (-not (Test-Path $arqPontos)) { Write-Host "pontos-teste.csv não encontrado em $pastaPol"; exit 2 }
    $pontos = @(Import-Csv -Path $arqPontos -Delimiter ';' -Encoding UTF8)
    $nPass = 0; $nFail = 0
    foreach ($pt in $pontos) {
        $latP = AreaToNum ([string]$pt.lat); $lonP = AreaToNum ([string]$pt.lon)
        $esperados = @(([string]$pt.esperado) -split '\|' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ -ne '' })
        if ($null -ne $latP -and $null -ne $lonP) {
            $r = Resolve-DentroArea -Lat $latP -Lon $lonP -PrecisaoCoord 'exata' -Rua $pt.rua -Numero $pt.numero -BairroSite $pt.bairro
        } else {
            $r = Resolve-DentroArea -Lat $null -Lon $null -PrecisaoCoord '' -Rua $pt.rua -Numero $pt.numero -BairroSite $pt.bairro
        }
        $ok = $esperados -contains $r.dentro_area
        if ($ok) { $nPass++ } else { $nFail++ }
        $tag = if ($ok) { 'PASS' } else { 'FAIL' }
        Write-Host ("{0}  {1}, {2} ({3}): esperado {4} | obtido {5} — {6}" -f $tag, $pt.rua, $pt.numero, $pt.bairro, $pt.esperado, $r.dentro_area, $r.motivo_area)
    }
    Write-Host ("TOTAL: {0}/{1} PASS, {2} FAIL" -f $nPass, $pontos.Count, $nFail)
    if ($nFail -gt 0) { exit 1 } else { exit 0 }
}
elseif ($Endereco -ne '') {
    $pastaPol = if ($PastaPoligonos) { $PastaPoligonos } else { $script:AreaPastaPoligonosPadrao }
    Import-Poligonos -Pasta $pastaPol | Out-Null
    $g = Get-Geocode -Rua $Endereco -Numero $Numero -Bairro $Bairro
    Write-Host ("Geocode: precisao={0} lat={1} lon={2} origem={3} — {4}" -f $g.precisao, (AreaFmt $g.lat 7), (AreaFmt $g.lon 7), $g.origem, $g.detalhe)
    $lista = Test-RuaNaLista -Rua $Endereco -Numero $Numero
    Write-Host ("Lista de ruas: {0} — {1}" -f $lista.situacao, $lista.motivo)
    $r = Resolve-DentroArea -Lat $null -Lon $null -PrecisaoCoord '' -Rua $Endereco -Numero $Numero -BairroSite $Bairro
    Write-Host ("Resultado: dentro_area={0} poligono={1} passo={2} — {3}" -f $r.dentro_area, $r.poligono, $r.passo, $r.motivo_area)
    exit 0
}
