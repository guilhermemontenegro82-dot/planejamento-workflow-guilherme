# consolidar.ps1 — junta os brutos dos coletores, reconfere os critérios, decide a área (polígono + ruas)
# e marca possíveis duplicatas. Saída: <Pasta>\coleta.csv + consolidar.log + consolidar-resumo.json
# Uso: powershell -ExecutionPolicy Bypass -File consolidar.ps1 -Pasta "<raiz>\_dados\2026-10-11"
param(
    [Parameter(Mandatory = $true)][string]$Pasta,
    [string]$Raiz = "",
    [string]$Criterios = "",
    [string]$Ruas = "",
    [string]$AreaScript = ""
)
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
# $PSScriptRoot só existe no corpo do script (no bloco param ele vem vazio no PS 5.1)
if (-not $Raiz) { $Raiz = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
if (-not $Criterios) { $Criterios = Join-Path $Raiz 'Sites e critérios para Busca\criterios.json' }
if (-not $Ruas) { $Ruas = Join-Path $Raiz 'Listagem das ruas\ruas.csv' }
if (-not $AreaScript) { $AreaScript = Join-Path $PSScriptRoot 'area.ps1' }
$logPath = Join-Path $Pasta 'consolidar.log'
$linhasLog = New-Object System.Collections.Generic.List[string]
function Log([string]$msg) { $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $linhasLog.Add("$t  $msg"); Write-Host $msg }
function ToNum([string]$s) {
    if ($null -eq $s) { return $null }
    $s = $s.Trim(); if ($s -eq '') { return $null }
    $v = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$v)) { return $v }
    return $null
}
function FmtNum($v) { if ($null -eq $v) { return '' } ; return ([double]$v).ToString('0.######', $inv) }
function Remove-Acento([string]$s) {
    if ($null -eq $s) { return '' }
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $n.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) } }
    return $sb.ToString()
}
function Get-ChaveEndereco([string]$rua, [string]$numero) {
    if ([string]::IsNullOrWhiteSpace($rua) -or [string]::IsNullOrWhiteSpace($numero)) { return '' }
    $r = (Remove-Acento $rua).ToLowerInvariant()
    $r = $r -replace '^(r\.|rua)\s+', '' -replace '^(av\.|avenida)\s+', '' -replace '\s+', ' '
    $r = $r -replace "d'avila", 'davila' -replace 'elisabeth', 'elizabeth' -replace 'moraes', 'morais' -replace 'gois', 'goes' -replace 'lira', 'lira'
    $num = ($numero -replace '[^0-9]', '')
    if ($num -eq '') { return '' }
    return "$r|$num"
}

Log "▶ consolidar.ps1 — pasta $Pasta"
$crit = Get-Content -Path $Criterios -Raw -Encoding UTF8 | ConvertFrom-Json
$precoMin = [double]$crit.preco_min; $precoMax = [double]$crit.preco_max
$areaMin = [double]$crit.area_util_min; $areaMax = [double]$crit.area_util_max
$tiposOk = @($crit.tipos_incluidos | ForEach-Object { $_.ToString().ToLowerInvariant() })

# ---- módulo de área ----
$temArea = $false
if (Test-Path $AreaScript) {
    . $AreaScript
    $temArea = (Get-Command Resolve-DentroArea -ErrorAction SilentlyContinue) -ne $null
    if ($temArea -and (Get-Command Import-Poligonos -ErrorAction SilentlyContinue)) {
        try { Import-Poligonos -Pasta (Join-Path $Raiz 'Áreas de interesse\poligonos') | Out-Null } catch { try { Import-Poligonos | Out-Null } catch { Log "AVISO: Import-Poligonos falhou: $($_.Exception.Message)" } }
    }
}
if (-not $temArea) { Log "AVISO: area.ps1 indisponível — dentro_area ficará 'A CONFIRMAR' para tudo" }

# ---- colunas do contrato ----
$colsBruto = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord','preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar','anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site')
$colsExtra = @('dentro_area','motivo_area','poligono','bairro','duplicata_grupo')

# ---- lê os brutos ----
$brutos = Get-ChildItem -Path $Pasta -Filter 'bruto-*.csv' | Sort-Object Name
if ($brutos.Count -eq 0) { Log "ERRO: nenhum bruto-*.csv em $Pasta"; $linhasLog | Set-Content -Path $logPath -Encoding UTF8; exit 2 }
$linhas = New-Object System.Collections.Generic.List[object]
$resumo = [ordered]@{ rodada = (Split-Path -Leaf $Pasta); fontes = [ordered]@{}; }
$vistos = @{}
foreach ($arq in $brutos) {
    $dados = @(Import-Csv -Path $arq.FullName -Delimiter ';' -Encoding UTF8)
    $fonteArq = ($arq.BaseName -replace '^bruto-', '').ToUpperInvariant()
    $faltando = @($colsBruto | Where-Object { -not ($dados.Count -gt 0 -and $dados[0].PSObject.Properties[$_]) })
    if ($dados.Count -gt 0 -and $faltando.Count -gt 0) { Log "AVISO: $($arq.Name) sem as colunas: $($faltando -join ', ')" }
    $nFora = 0; $nDup = 0; $nOk = 0
    foreach ($d in $dados) {
        $ch = [string]$d.chave
        if ([string]::IsNullOrWhiteSpace($ch)) { continue }
        if ($vistos.ContainsKey($ch)) { $nDup++; continue }
        $vistos[$ch] = $true
        $preco = ToNum ([string]$d.preco); $area = ToNum ([string]$d.area_util)
        $tipo = ([string]$d.tipo).Trim()
        $motivoFora = ''
        if ($null -eq $preco -or $preco -lt $precoMin -or $preco -gt $precoMax) { $motivoFora = "preço $preco fora de $precoMin-$precoMax" }
        elseif ($null -eq $area -or $area -lt $areaMin -or $area -gt $areaMax) { $motivoFora = "área $area fora de $areaMin-$areaMax" }
        elseif ($tipo -ne '' -and -not ($tiposOk -contains $tipo.ToLowerInvariant())) { $motivoFora = "tipo '$tipo' não incluído" }
        if ($motivoFora -ne '') { $nFora++; Log "  fora dos critérios: $ch ($motivoFora)"; continue }
        $stSite = ([string]$d.status_site).Trim().ToUpperInvariant()
        if ($stSite -ne '' -and $stSite -ne 'ATIVO') { $nFora++; Log "  status_site=$stSite no bruto (anúncio já inativo no site): $ch"; continue }
        $o = [ordered]@{}
        foreach ($c in $colsBruto) { $o[$c] = if ($d.PSObject.Properties[$c]) { [string]$d.$c } else { '' } }
        $o['preco'] = FmtNum $preco; $o['area_util'] = FmtNum $area
        foreach ($c in $colsExtra) { $o[$c] = '' }
        $linhas.Add([pscustomobject]$o); $nOk++
    }
    $resumo.fontes[$fonteArq] = [ordered]@{ brutos = $dados.Count; fora_criterios = $nFora; duplicados_chave = $nDup; aceitos = $nOk }
    Log "$($arq.Name): $($dados.Count) linhas, $nFora fora dos critérios, $nDup chave repetida, $nOk aceitas"
}

# ---- área ----
$contArea = [ordered]@{ SIM = 0; LIMITE = 0; 'A CONFIRMAR' = 0; NAO = 0 }
$i = 0
foreach ($l in $linhas) {
    $i++
    $lat = ToNum $l.lat; $lon = ToNum $l.lon
    $res = $null
    if ($temArea) {
        try {
            $res = Resolve-DentroArea -Lat $lat -Lon $lon -PrecisaoCoord $l.precisao_coord -Rua $l.rua -Numero $l.numero -BairroSite $l.bairro_site
        } catch { Log "AVISO: Resolve-DentroArea falhou em $($l.chave): $($_.Exception.Message)" }
    }
    if ($null -eq $res) {
        $l.dentro_area = 'A CONFIRMAR'; $l.motivo_area = 'módulo de área indisponível'; $l.poligono = ''
    } else {
        $l.dentro_area = [string]$res.dentro_area; $l.motivo_area = [string]$res.motivo_area; $l.poligono = [string]$res.poligono
        if ($res.PSObject.Properties['lat'] -and $res.lat -and -not $lat) { $l.lat = FmtNum $res.lat; $l.lon = FmtNum $res.lon; if ($l.precisao_coord -eq '' -or $l.precisao_coord -eq 'nenhuma' -or $l.precisao_coord -eq 'bairro') { $l.precisao_coord = 'exata' } }
    }
    if (-not $contArea.Contains($l.dentro_area)) { $l.dentro_area = 'A CONFIRMAR' }
    $contArea[$l.dentro_area] = [int]$contArea[$l.dentro_area] + 1
    $bs = ([string]$l.bairro_site).Trim()
    if ($l.poligono -eq 'Ipanema') { $l.bairro = if ((Remove-Acento $bs).ToLowerInvariant() -match 'copacabana|arpoador') { 'Ipanema/Arpoador' } else { 'Ipanema' } }
    elseif ($l.poligono -eq 'Leblon') { $l.bairro = 'Leblon' }
    else { $l.bairro = if ($bs -ne '') { $bs } else { '' } }
    if ($i % 100 -eq 0) { Log "  área: $i de $($linhas.Count)" }
}
Log "Área: SIM $($contArea.SIM) | LIMITE $($contArea.LIMITE) | A CONFIRMAR $($contArea['A CONFIRMAR']) | NAO $($contArea.NAO)"

# ---- duplicatas (mesmo endereço ou CEP, área ±2 m², preço ±2 %) ----
$grupos = New-Object System.Collections.Generic.List[object]
foreach ($l in $linhas) {
    if ($l.dentro_area -eq 'NAO') { continue }
    $ke = Get-ChaveEndereco $l.rua $l.numero
    $kc = ([string]$l.cep -replace '[^0-9]', '')
    if ($ke -eq '' -and $kc -eq '') { continue }
    $p = ToNum $l.preco; $a = ToNum $l.area_util
    $achou = $null
    foreach ($g in $grupos) {
        $mesmoEnd = ($ke -ne '' -and $g.ke -eq $ke) -or ($ke -eq '' -and $kc -ne '' -and $g.kc -eq $kc -and $g.ke -eq '')
        if (-not $mesmoEnd) { continue }
        if ([math]::Abs($g.a - $a) -le 2 -and [math]::Abs($g.p - $p) -le (0.02 * [math]::Max($g.p, $p))) { $achou = $g; break }
    }
    if ($null -eq $achou) { $grupos.Add([pscustomobject]@{ ke = $ke; kc = $kc; a = $a; p = $p; membros = (New-Object System.Collections.Generic.List[object]) }); $achou = $grupos[$grupos.Count - 1] }
    $achou.membros.Add($l)
}
# D = mesmo endereço com número (provável mesmo imóvel em várias imobiliárias/filiais)
# P = só CEP/rua sem número (mesmo prédio ou lançamento: podem ser unidades diferentes)
$nGrupo = 0; $nPredio = 0
foreach ($g in $grupos) {
    if ($g.membros.Count -lt 2) { continue }
    if ($g.ke -ne '') { $nGrupo++; $id = 'D{0:000}' -f $nGrupo } else { $nPredio++; $id = 'P{0:000}' -f $nPredio }
    foreach ($m in $g.membros) { $m.duplicata_grupo = $id }
}
Log "Duplicatas: $nGrupo grupos por endereço+número (D) e $nPredio só por rua/CEP sem número (P)"

# ---- grava ----
$saida = Join-Path $Pasta 'coleta.csv'
$ordem = $colsBruto + $colsExtra
$linhas | Select-Object -Property $ordem | Export-Csv -Path $saida -Delimiter ';' -NoTypeInformation -Encoding UTF8
$resumo['total_aceitos'] = $linhas.Count
$resumo['area'] = $contArea
$resumo['para_planilha'] = @($linhas | Where-Object { $_.dentro_area -ne 'NAO' }).Count
$resumo['grupos_duplicata'] = $nGrupo
$resumo['gerado_em'] = (Get-Date).ToString('yyyy-MM-dd HH:mm')
($resumo | ConvertTo-Json -Depth 5) | Set-Content -Path (Join-Path $Pasta 'consolidar-resumo.json') -Encoding UTF8
Log "coleta.csv: $($linhas.Count) linhas ($($resumo.para_planilha) vão para a planilha)"
$linhasLog | Set-Content -Path $logPath -Encoding UTF8
exit 0
