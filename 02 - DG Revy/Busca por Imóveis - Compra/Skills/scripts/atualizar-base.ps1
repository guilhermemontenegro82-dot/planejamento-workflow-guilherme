# atualizar-base.ps1 — funde a coleta do dia com a base (fonte da verdade entre rodadas).
# Entra: coleta.csv (consolidada) + verificacao.csv (opcional). Sai: base.csv atualizada, backup da anterior
# e resumo-rodada.json com novos / removidos / reativados / preço alterado.
# Uso: powershell -ExecutionPolicy Bypass -File atualizar-base.ps1 -Pasta "<raiz>\_dados\2026-10-11" -Rodada 2026-10-11
param(
    [Parameter(Mandatory = $true)][string]$Pasta,
    [Parameter(Mandatory = $true)][string]$Rodada,
    [string]$Base = "",
    [string]$Coleta = "",
    [string]$Verificacao = ""
)
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$raizDados = Split-Path -Parent $Pasta
if (-not $Base) { $Base = Join-Path $raizDados 'base.csv' }
if (-not $Coleta) { $Coleta = Join-Path $Pasta 'coleta.csv' }
if (-not $Verificacao) { $Verificacao = Join-Path $Pasta 'verificacao.csv' }
$logPath = Join-Path $Pasta 'atualizar-base.log'
$linhasLog = New-Object System.Collections.Generic.List[string]
function Log([string]$msg) { $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $linhasLog.Add("$t  $msg"); Write-Host $msg }
function ToNum([string]$s) { if ($null -eq $s) { return $null }; $s = $s.Trim(); if ($s -eq '') { return $null }; $v = 0.0; if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$v)) { return $v }; return $null }
function FmtNum($v) { if ($null -eq $v) { return '' }; return ([double]$v).ToString('0.######', $inv) }

$colsColeta = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord','preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar','anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site','dentro_area','motivo_area','poligono','bairro','duplicata_grupo')
$colsBase = $colsColeta + @('status','primeira_captura','ultima_verificacao','removido_em','preco_anterior','preco_alterado_em','historico_precos','avaliacao_socios','observacoes')
# campos que a coleta do dia sobrescreve na base (o resto é preservado)
$colsAtualizaveis = @('link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','lat','lon','precisao_coord','preco','area_util','area_total','condominio_mes','iptu_mes','iptu_informado','quartos','banheiros','suites','vagas','andar','anunciante','tipo_anunciante','publicado_em','atualizado_em','capturado_em','fotos','destaques','descricao_resumo','status_site','dentro_area','motivo_area','poligono','bairro','duplicata_grupo')

Log "▶ atualizar-base.ps1 — rodada $Rodada"
if (-not (Test-Path $Coleta)) { Log "ERRO: coleta não encontrada: $Coleta"; $linhasLog | Set-Content $logPath -Encoding UTF8; exit 2 }
$colRows = @(Import-Csv -Path $Coleta -Delimiter ';' -Encoding UTF8)
Log "coleta.csv: $($colRows.Count) linhas"

# ---- base atual ----
$baseDic = @{}
$ordemBase = New-Object System.Collections.Generic.List[string]
if (Test-Path $Base) {
    $bk = Join-Path $Pasta 'base-anterior.csv'
    Copy-Item -Path $Base -Destination $bk -Force
    foreach ($b in @(Import-Csv -Path $Base -Delimiter ';' -Encoding UTF8)) {
        $o = [ordered]@{}
        foreach ($c in $colsBase) { $o[$c] = if ($b.PSObject.Properties[$c]) { [string]$b.$c } else { '' } }
        $baseDic[$o.chave] = [pscustomobject]$o; $ordemBase.Add($o.chave)
    }
    Log "base.csv anterior: $($baseDic.Count) linhas (backup em $bk)"
} else { Log "base.csv não existe ainda: primeira rodada" }

# ---- verificação de disponibilidade ----
$verifDic = @{}
if (Test-Path $Verificacao) {
    foreach ($v in @(Import-Csv -Path $Verificacao -Delimiter ';' -Encoding UTF8)) { if ($v.chave) { $verifDic[[string]$v.chave] = $v } }
    Log "verificacao.csv: $($verifDic.Count) chaves verificadas"
} else { Log "sem verificacao.csv (nada a verificar ou etapa pulada)" }

$novos = New-Object System.Collections.Generic.List[string]
$reativados = New-Object System.Collections.Generic.List[string]
$precoAlterado = New-Object System.Collections.Generic.List[string]
$removidos = New-Object System.Collections.Generic.List[string]
$foraCriterios = New-Object System.Collections.Generic.List[string]
$naoVerificados = New-Object System.Collections.Generic.List[string]
$vistosHoje = @{}

foreach ($c in $colRows) {
    $ch = [string]$c.chave
    if ([string]::IsNullOrWhiteSpace($ch) -or $vistosHoje.ContainsKey($ch)) { continue }
    $vistosHoje[$ch] = $true
    $precoNovo = ToNum ([string]$c.preco)
    $foraArea = ([string]$c.dentro_area -eq 'NAO')
    if ($baseDic.ContainsKey($ch)) {
        $b = $baseDic[$ch]
        $precoAnt = ToNum $b.preco
        $statusAnt = $b.status
        foreach ($k in $colsAtualizaveis) { if ($c.PSObject.Properties[$k]) { $b.$k = [string]$c.$k } }
        if ($null -ne $precoAnt -and $null -ne $precoNovo -and [math]::Abs($precoAnt - $precoNovo) -ge 1) {
            $b.preco_anterior = FmtNum $precoAnt; $b.preco_alterado_em = $Rodada
            $b.historico_precos = (@($b.historico_precos, "${Rodada}:$(FmtNum $precoNovo)") | Where-Object { $_ -ne '' }) -join ' | '
            $precoAlterado.Add("$ch $(FmtNum $precoAnt) -> $(FmtNum $precoNovo)")
        }
        if ($foraArea) { $b.status = 'FORA DOS CRITÉRIOS'; $foraCriterios.Add("$ch fora da área: $($c.motivo_area)") }
        else {
            if ($statusAnt -eq 'REMOVIDO') { $reativados.Add($ch); $b.removido_em = '' }
            $b.status = 'ATIVO'
        }
        $b.ultima_verificacao = $Rodada
    } else {
        if ($foraArea) { continue }   # fora da área nunca entra na base
        $o = [ordered]@{}
        foreach ($k in $colsColeta) { $o[$k] = if ($c.PSObject.Properties[$k]) { [string]$c.$k } else { '' } }
        $o['status'] = 'ATIVO'; $o['primeira_captura'] = $Rodada; $o['ultima_verificacao'] = $Rodada; $o['removido_em'] = ''
        $o['preco_anterior'] = ''; $o['preco_alterado_em'] = ''; $o['historico_precos'] = "${Rodada}:$(FmtNum $precoNovo)"
        $o['avaliacao_socios'] = ''; $o['observacoes'] = ''
        $baseDic[$ch] = [pscustomobject]$o; $ordemBase.Add($ch); $novos.Add($ch)
    }
}

# ---- quem estava na base e não veio hoje ----
foreach ($ch in @($ordemBase)) {
    if ($vistosHoje.ContainsKey($ch)) { continue }
    $b = $baseDic[$ch]
    if ($verifDic.ContainsKey($ch)) {
        $v = $verifDic[$ch]; $st = ([string]$v.status_site).Trim().ToUpperInvariant()
        $b.ultima_verificacao = $Rodada
        if ($st -eq 'ATIVO') {
            $pa = ToNum ([string]$v.preco_atual); $pb = ToNum $b.preco
            if ($null -ne $pa -and $null -ne $pb -and [math]::Abs($pa - $pb) -ge 1) {
                $b.preco_anterior = FmtNum $pb; $b.preco = FmtNum $pa; $b.preco_alterado_em = $Rodada
                $b.historico_precos = (@($b.historico_precos, "${Rodada}:$(FmtNum $pa)") | Where-Object { $_ -ne '' }) -join ' | '
                $precoAlterado.Add("$ch $(FmtNum $pb) -> $(FmtNum $pa) (fora da busca)")
            }
            if ($b.status -ne 'REMOVIDO') { $b.status = 'FORA DOS CRITÉRIOS'; $foraCriterios.Add("$ch ainda no ar, mas fora da busca de hoje") }
        } elseif ($st -eq 'INATIVO' -or $st -eq 'NAO_ENCONTRADO') {
            if ($b.status -ne 'REMOVIDO') { $b.status = 'REMOVIDO'; $b.removido_em = $Rodada; $removidos.Add("$ch ($st)") }
        } else { $naoVerificados.Add("$ch (verificação: $st)") }
    } else {
        if ($b.status -ne 'REMOVIDO') { $naoVerificados.Add("$ch (sem verificação)") }
    }
}

# ---- grava ----
$lista = foreach ($ch in $ordemBase) { $baseDic[$ch] }
$lista | Select-Object -Property $colsBase | Export-Csv -Path $Base -Delimiter ';' -NoTypeInformation -Encoding UTF8
$ativos = @($lista | Where-Object { $_.status -eq 'ATIVO' }).Count
$porFonte = [ordered]@{}
foreach ($g in ($colRows | Where-Object { $_.dentro_area -ne 'NAO' } | Group-Object fonte)) { $porFonte[$g.Name] = $g.Count }
$resumo = [ordered]@{
    rodada = $Rodada; coletados = $porFonte; coletados_na_area = $porFonte; coleta_total = $colRows.Count
    observacao = "novos $($novos.Count), removidos $($removidos.Count), preço alterado $($precoAlterado.Count), não verificados $($naoVerificados.Count)"
    novos = $novos.Count; reativados = $reativados.Count; removidos = $removidos.Count; preco_alterado = $precoAlterado.Count
    fora_criterios = $foraCriterios.Count; nao_verificados = $naoVerificados.Count; total_base = $lista.Count; total_ativo = $ativos
    a_confirmar = @($lista | Where-Object { $_.status -eq 'ATIVO' -and $_.dentro_area -eq 'A CONFIRMAR' }).Count
    limite = @($lista | Where-Object { $_.status -eq 'ATIVO' -and $_.dentro_area -eq 'LIMITE' }).Count
    listas = [ordered]@{ novos = $novos; reativados = $reativados; removidos = $removidos; preco_alterado = $precoAlterado; fora_criterios = $foraCriterios; nao_verificados = $naoVerificados }
    gerado_em = (Get-Date).ToString('yyyy-MM-dd HH:mm')
}
($resumo | ConvertTo-Json -Depth 6) | Set-Content -Path (Join-Path $Pasta 'resumo-rodada.json') -Encoding UTF8
Log "base.csv: $($lista.Count) linhas, $ativos ativas | novos $($novos.Count) | reativados $($reativados.Count) | removidos $($removidos.Count) | preço alterado $($precoAlterado.Count) | fora dos critérios $($foraCriterios.Count) | não verificados $($naoVerificados.Count)"
$linhasLog | Set-Content -Path $logPath -Encoding UTF8
exit 0
