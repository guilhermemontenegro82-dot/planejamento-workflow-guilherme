<#
.SINOPSE
  Conta grupos de anúncios "irmãos" (mesmo imóvel publicado mais de uma vez) num bruto-vivareal.csv, por bairro_site.
  Dois critérios: (1) exato: rua + número + área + preço iguais; (2) o do consolidador: rua + número (ou CEP quando
  não há número) com área ±2 m² e preço ±2 %. Teste do componente, 11/10/2026.
  Uso: powershell -NoProfile -ExecutionPolicy Bypass -File contar-irmaos-vivareal.ps1 -Csv "<pasta>\bruto-vivareal.csv"
  Grava <pasta>\irmaos.txt.
#>
param([string]$Csv = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$inv = [System.Globalization.CultureInfo]::InvariantCulture
if ($Csv -eq '') { throw 'informe -Csv' }
$saida = New-Object System.Collections.Generic.List[string]
function Linha([string]$t) { $saida.Add($t); Write-Host $t }
$tab = @(Import-Csv -LiteralPath $Csv -Delimiter ';' -Encoding UTF8)
Linha ("=== Irmaos em {0} ({1}) ===" -f $Csv, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
foreach ($bairro in @('Ipanema', 'Leblon', 'Copacabana')) {
  $linhas = @($tab | Where-Object { $_.bairro_site -eq $bairro })
  if ($linhas.Count -eq 0) { continue }
  # (1) exato
  $g1 = @($linhas | Group-Object { $_.rua + '|' + $_.numero + '|' + $_.area_util + '|' + $_.preco })
  $g1dup = @($g1 | Where-Object { $_.Count -gt 1 })
  $n1 = ($g1dup | Measure-Object Count -Sum).Sum; if ($null -eq $n1) { $n1 = 0 }
  # (2) consolidador: chave rua+numero (ou cep sem numero), depois agrupamento guloso por area ±2 e preco ±2 %
  $chaves = @($linhas | Group-Object { if ($_.numero -ne '') { 'N|' + $_.rua + '|' + $_.numero } elseif ($_.cep -ne '') { 'C|' + $_.rua + '|' + $_.cep } else { 'X|' + $_.codigo } })
  $grupos2 = New-Object System.Collections.Generic.List[object]
  foreach ($c in $chaves) {
    $pend = New-Object System.Collections.Generic.List[object]; foreach ($x in $c.Group) { $pend.Add($x) }
    while ($pend.Count -gt 0) {
      $base = $pend[0]; $pend.RemoveAt(0)
      $grupo = New-Object System.Collections.Generic.List[object]; $grupo.Add($base)
      $a0 = [double]::Parse($base.area_util, $inv); $p0 = [double]::Parse($base.preco, $inv)
      for ($k = $pend.Count - 1; $k -ge 0; $k--) {
        $y = $pend[$k]; $a = [double]::Parse($y.area_util, $inv); $p = [double]::Parse($y.preco, $inv)
        if ([math]::Abs($a - $a0) -le 2 -and [math]::Abs($p - $p0) -le 0.02 * $p0) { $grupo.Add($y); $pend.RemoveAt($k) }
      }
      $grupos2.Add($grupo)
    }
  }
  $g2dup = @($grupos2 | Where-Object { $_.Count -gt 1 })
  $n2 = 0; foreach ($g in $g2dup) { $n2 += $g.Count }
  $semEndereco = @($linhas | Where-Object { $_.numero -eq '' -and $_.cep -eq '' }).Count
  Linha ("{0}: {1} anuncios" -f $bairro, $linhas.Count)
  Linha ("  (1) exato rua+numero+area+preco: {0} grupos com 2+ anuncios ({1} anuncios neles; maior grupo {2}); imoveis distintos = {3}" -f $g1dup.Count, $n1, $(if ($g1dup.Count) { ($g1dup | Measure-Object Count -Maximum).Maximum } else { 0 }), $g1.Count)
  Linha ("  (2) consolidador rua+numero(ou CEP), area +-2 m2, preco +-2%: {0} grupos com 2+ anuncios ({1} anuncios neles; maior grupo {2}); imoveis distintos = {3}; sem numero e sem CEP: {4}" -f $g2dup.Count, $n2, $(if ($g2dup.Count) { ($g2dup | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum } else { 0 }), $grupos2.Count, $semEndereco)
  $semNumero = @($linhas | Where-Object { $_.numero -eq '' }).Count
  Linha ("  sem numero (agrupados so por rua+CEP, portanto grupos (2) podem juntar unidades diferentes do mesmo predio): {0} de {1}" -f $semNumero, $linhas.Count)
  foreach ($g in ($g2dup | Sort-Object { -$_.Count } | Select-Object -First 5)) {
    Linha ("    ex.: {0}, {1} | {2} m2 | R$ {3} -> {4}" -f $g[0].rua, $(if ($g[0].numero -ne '') { $g[0].numero } else { 'CEP ' + $g[0].cep }), $g[0].area_util, $g[0].preco, (($g | ForEach-Object { $_.codigo + ' (' + $_.anunciante + ')' }) -join ' ; '))
  }
}
[System.IO.File]::WriteAllLines((Join-Path (Split-Path $Csv -Parent) 'irmaos.txt'), $saida, (New-Object System.Text.UTF8Encoding($true)))
