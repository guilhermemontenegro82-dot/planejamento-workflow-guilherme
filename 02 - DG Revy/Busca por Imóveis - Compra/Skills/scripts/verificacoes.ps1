# verificacoes.ps1 — apoio à checagem de disponibilidade.
#   -Modo listar : compara base.csv com coleta.csv e grava a-verificar-<fonte>.csv (chaves da base que não vieram hoje)
#   -Modo juntar : junta verificacao-*.csv em verificacao.csv (formato do contrato)
# Uso: powershell -ExecutionPolicy Bypass -File verificacoes.ps1 -Modo listar -Pasta "<raiz>\_dados\2026-10-11"
param(
    [Parameter(Mandatory = $true)][ValidateSet('listar', 'juntar')][string]$Modo,
    [Parameter(Mandatory = $true)][string]$Pasta,
    [string]$Base = "",
    [string]$Coleta = "",
    [string]$Fontes = "VIVAREAL,QUINTOANDAR,CHAVESNAMAO"
)
$ErrorActionPreference = 'Stop'
if (-not $Base) { $Base = Join-Path (Split-Path -Parent $Pasta) 'base.csv' }
if (-not $Coleta) { $Coleta = Join-Path $Pasta 'coleta.csv' }

if ($Modo -eq 'listar') {
    if (-not (Test-Path $Base)) { Write-Host "base.csv não existe: nada a verificar (primeira rodada)"; exit 0 }
    $vistos = @{}
    if (Test-Path $Coleta) { foreach ($c in @(Import-Csv -Path $Coleta -Delimiter ';' -Encoding UTF8)) { if ($c.chave) { $vistos[[string]$c.chave] = $true } } }
    $baseRows = @(Import-Csv -Path $Base -Delimiter ';' -Encoding UTF8)
    $total = 0
    foreach ($f in ($Fontes -split ',')) {
        $fonte = $f.Trim().ToUpperInvariant(); if ($fonte -eq '') { continue }
        $faltam = @($baseRows | Where-Object { $_.fonte -eq $fonte -and $_.status -ne 'REMOVIDO' -and -not $vistos.ContainsKey([string]$_.chave) })
        $arq = Join-Path $Pasta "a-verificar-$($fonte.ToLowerInvariant()).csv"
        if ($faltam.Count -gt 0) {
            $faltam | Select-Object chave, fonte, codigo, link, preco | Export-Csv -Path $arq -Delimiter ';' -NoTypeInformation -Encoding UTF8
        } elseif (Test-Path $arq) { Remove-Item $arq -Force }
        Write-Host "${fonte}: $($faltam.Count) chaves a verificar -> $(if ($faltam.Count -gt 0) { $arq } else { '(nenhuma)' })"
        $total += $faltam.Count
    }
    Write-Host "Total a verificar: $total"
    exit 0
}

if ($Modo -eq 'juntar') {
    $arqs = @(Get-ChildItem -Path $Pasta -Filter 'verificacao-*.csv')
    $linhas = New-Object System.Collections.Generic.List[object]
    foreach ($a in $arqs) {
        foreach ($v in @(Import-Csv -Path $a.FullName -Delimiter ';' -Encoding UTF8)) {
            if (-not $v.chave) { continue }
            $linhas.Add([pscustomobject]@{
                chave = [string]$v.chave
                status_site = if ($v.PSObject.Properties['status_site']) { ([string]$v.status_site).Trim().ToUpperInvariant() } else { 'ERRO' }
                preco_atual = if ($v.PSObject.Properties['preco_atual']) { [string]$v.preco_atual } else { '' }
                verificado_em = if ($v.PSObject.Properties['verificado_em']) { [string]$v.verificado_em } else { (Get-Date).ToString('yyyy-MM-dd HH:mm') }
                evidencia = if ($v.PSObject.Properties['evidencia']) { [string]$v.evidencia } else { '' }
            })
        }
    }
    $saida = Join-Path $Pasta 'verificacao.csv'
    if ($linhas.Count -gt 0) { $linhas | Export-Csv -Path $saida -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
    elseif (Test-Path $saida) { Remove-Item $saida -Force }
    $cont = $linhas | Group-Object status_site | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Host "verificacao.csv: $($linhas.Count) linhas de $($arqs.Count) arquivo(s) [$($cont -join ', ')]"
    exit 0
}
