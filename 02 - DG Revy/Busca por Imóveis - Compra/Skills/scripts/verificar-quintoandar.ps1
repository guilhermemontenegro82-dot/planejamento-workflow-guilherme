<#
  verificar-quintoandar.ps1 — Verifica se anúncios do QuintoAndar continuam no ar.

  Para cada id, abre https://www.quintoandar.com.br/imovel/<id>/comprar (seguindo redirecionamentos)
  e lê o __NEXT_DATA__ da página:
    ATIVO           houseInfo presente e listings[businessContext=SALE].status = "publicado"
    INATIVO         houseInfo presente mas o anúncio de venda está suspenso/despublicado/vendido
                    (ou forSale = false)
    NAO_ENCONTRADO  HTTP 404, redirecionamento para a página de busca, ou página "Esse imóvel está
                    indisponível" (houseInfo vazio)
    ERRO            não deu para verificar (curl falhou nas 3 tentativas, 5xx, HTML sem __NEXT_DATA__,
                    JSON ilegível). NUNCA tratar ERRO como removido.

  Uso
    powershell -ExecutionPolicy Bypass -File verificar-quintoandar.ps1 -Chaves <csv> -Saida <pasta>
    powershell -ExecutionPolicy Bypass -File verificar-quintoandar.ps1 -Ids 894849326,895783557 -Saida <pasta>
    -Chaves  CSV (separador ';') com a coluna "chave" (QUINTOANDAR_<id>); linhas de outras fontes são ignoradas.
             Se houver coluna "fonte", só QUINTOANDAR é considerada.
    -Ids     lista de ids (alternativa ao CSV)
    -Saida   pasta de saída (padrão: _dados\<hoje>). Gera verificacao-quintoandar.csv
             (chave;status_site;preco_atual;verificado_em;evidencia) e verificar-quintoandar.log.

  Código de saída: 0 se todas as chaves foram verificadas; 2 se alguma ficou em ERRO.
#>
[CmdletBinding()]
param(
  [string]$Chaves = '',
  [string[]]$Ids = @(),
  [string]$Saida = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Saida) { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$Saida = (Resolve-Path $Saida).Path
$pastaTmp = Join-Path $Saida '_tmp-verificar-quintoandar'
New-Item -ItemType Directory -Force -Path $pastaTmp | Out-Null
$logPath = Join-Path $Saida 'verificar-quintoandar.log'
$csvPath = Join-Path $Saida 'verificacao-quintoandar.csv'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

function Log([string]$msg) {
  $linha = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg
  [System.IO.File]::AppendAllText($logPath, $linha + "`r`n", $utf8bom)
  Write-Host $linha
}
Log "== verificar-quintoandar: início =="
Log "saída: $Saida"

# user-agent do criterios.json (se existir)
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$arqCrit = Join-Path $raiz 'Sites e critérios para Busca\criterios.json'
if (Test-Path $arqCrit) { try { $crit = Get-Content -Raw -Encoding UTF8 -Path $arqCrit | ConvertFrom-Json; if ($crit.user_agent) { $ua = $crit.user_agent } } catch { } }

# ---------------------------------------------------------------- lista de ids
$listaIds = New-Object System.Collections.Generic.List[string]
foreach ($i in $Ids) { foreach ($parte in ("$i" -split '[,\s]+')) { $t = $parte.Trim() -replace '^QUINTOANDAR_', ''; if ($t -match '^\d+$' -and -not $listaIds.Contains($t)) { $listaIds.Add($t) } } }
if ($Chaves) {
  if (-not (Test-Path $Chaves)) { Log "ERRO: arquivo de chaves não encontrado: $Chaves"; exit 2 }
  $tabela = Import-Csv -Path $Chaves -Delimiter ';' -Encoding UTF8
  $temFonte = $false
  if ($tabela.Count -gt 0) { $temFonte = ($tabela[0].PSObject.Properties.Name -contains 'fonte') }
  foreach ($linha in $tabela) {
    if ($temFonte -and "$($linha.fonte)" -ne 'QUINTOANDAR') { continue }
    $ch = "$($linha.chave)"
    if ($ch -notmatch '^QUINTOANDAR_(\d+)$') { continue }
    $t = $Matches[1]
    if (-not $listaIds.Contains($t)) { $listaIds.Add($t) }
  }
}
if ($listaIds.Count -eq 0) { Log "nada a verificar (nenhum id QUINTOANDAR em -Chaves/-Ids)"; exit 0 }
Log ("ids a verificar: {0}" -f $listaIds.Count)

# ---------------------------------------------------------------- utilitários
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue
$js.RecursionLimit = 1000
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path $curl)) { Log "ERRO: curl.exe não encontrado em $curl"; exit 2 }

function Invoke-Curl {
  param([string]$Url, [string]$ArqSaida)
  $tentativa = 0; $ultimo = $null
  while ($tentativa -lt 3) {
    $tentativa++
    if (Test-Path $ArqSaida) { Remove-Item $ArqSaida -Force }
    $argumentos = @('-s', '-L', '-m', '40', '-A', $ua, '-o', $ArqSaida, '-w', '%{http_code}|%{url_effective}', $Url)
    $saida = & $curl @argumentos
    $exit = $LASTEXITCODE
    $codigo = ''; $urlFinal = ''
    if ($saida) { $partes = ("$saida" -split '\|', 2); $codigo = $partes[0].Trim(); if ($partes.Count -gt 1) { $urlFinal = $partes[1].Trim() } }
    $corpo = ''
    if (Test-Path $ArqSaida) { $corpo = [System.IO.File]::ReadAllText($ArqSaida, [System.Text.Encoding]::UTF8) }
    $ultimo = [pscustomobject]@{ Codigo = $codigo; UrlFinal = $urlFinal; Corpo = $corpo; Exit = $exit; Tentativas = $tentativa }
    if ($exit -eq 0 -and $codigo -match '^(200|404|410)$') { return $ultimo }
    Start-Sleep -Seconds 2
  }
  return $ultimo
}
function Pega($dic, [string]$chave) {
  # leitura segura de chave em Dictionary<string,object> (ContainsKey) / hashtable (Contains) / objeto
  if ($null -eq $dic) { return $null }
  if ($dic -is [System.Collections.Generic.Dictionary[string,object]]) { if ($dic.ContainsKey($chave)) { return $dic[$chave] } else { return $null } }
  if ($dic -is [System.Collections.IDictionary]) { if ($dic.Contains($chave)) { return $dic[$chave] } else { return $null } }
  if ($dic -is [string] -or $dic -is [System.Array] -or $dic -is [System.ValueType]) { return $null }
  try { return $dic.$chave } catch { return $null }
}
function Txt($v) { if ($null -eq $v) { return '' }; return (("$v" -replace '[\r\n\t]+', ' ') -replace '\s{2,}', ' ').Trim() }
function DataCurta($s) { if (-not $s) { return '' }; $t = "$s" -replace '([+-]\d{2})(\d{2})$', '$1:$2'; try { return ([datetimeoffset]::Parse($t, $inv)).ToLocalTime().ToString('yyyy-MM-dd') } catch { return "$s" } }

# ---------------------------------------------------------------- verificação
$resultados = New-Object System.Collections.Generic.List[object]
$contagem = @{ ATIVO = 0; INATIVO = 0; NAO_ENCONTRADO = 0; ERRO = 0 }
$indice = 0
foreach ($id in $listaIds) {
  $indice++
  $url = "https://www.quintoandar.com.br/imovel/$id/comprar"
  $arq = Join-Path $pastaTmp "pagina-$id.html"
  # O site às vezes responde HTTP 200 com a página "Esse imóvel está indisponível" (houseInfo vazio) por
  # instabilidade, mesmo para anúncio no ar (visto em 11/10/2026). Quando isso acontece, a leitura é
  # repetida até 3 vezes antes de concluir NAO_ENCONTRADO.
  $rodada = 0
  do {
  $rodada++
  if ($rodada -gt 1) { Start-Sleep -Seconds 2 }
  $houseVazio = $false
  $r = Invoke-Curl -Url $url -ArqSaida $arq
  $status = 'ERRO'; $preco = ''; $evidencia = ''
  $urlFinal = $r.UrlFinal
  if ($r.Exit -ne 0 -or -not $r.Codigo -or $r.Codigo -eq '000') {
    $evidencia = "curl exit $($r.Exit) após $($r.Tentativas) tentativas (HTTP '$($r.Codigo)')"
  } elseif ($r.Codigo -eq '404' -or $r.Codigo -eq '410') {
    $status = 'NAO_ENCONTRADO'; $evidencia = "HTTP $($r.Codigo)"
  } elseif ($urlFinal -match '/(comprar|alugar)/imovel/' -or ($urlFinal -and $urlFinal -notmatch "/imovel/$id(/|$|\?)")) {
    $status = 'NAO_ENCONTRADO'; $evidencia = "HTTP $($r.Codigo); redirecionou para $urlFinal"
  } elseif ($r.Codigo -ne '200') {
    $evidencia = "HTTP $($r.Codigo) após $($r.Tentativas) tentativas"
  } else {
    $m = [regex]::Match($r.Corpo, '<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', 'Singleline')
    if (-not $m.Success) {
      $evidencia = "HTTP 200 sem __NEXT_DATA__ (tamanho $($r.Corpo.Length))"
    } else {
      $hi = $null
      try { $o = $js.DeserializeObject($m.Groups[1].Value); $hi = Pega (Pega (Pega (Pega (Pega $o 'props') 'pageProps') 'initialState') 'house') 'houseInfo' } catch { $evidencia = "JSON ilegível: $($_.Exception.Message)" }
      if ($hi -ne $null -or $evidencia -eq '') {
        if ($null -eq $hi -or "$(Pega $hi 'id')" -eq '') {
          $status = 'NAO_ENCONTRADO'; $houseVazio = $true
          $aviso = ''; if ($r.Corpo -match 'im[óo]vel est[áa] indispon[íi]vel') { $aviso = '; página diz "Esse imóvel está indisponível"' }
          $evidencia = "HTTP 200; houseInfo vazio (id ausente) em $rodada leitura(s)$aviso"
        } else {
          $preco = "$(Pega $hi 'salePrice')"
          $forSale = Pega $hi 'forSale'
          $listingSale = $null
          foreach ($l in @(Pega $hi 'listings')) { if ("$(Pega $l 'businessContext')" -eq 'SALE') { $listingSale = $l } }
          if ($listingSale) {
            $st = "$(Pega $listingSale 'status')"; $motivo = "$(Pega $listingSale 'statusReason')"
            $evidencia = "HTTP 200; listings[SALE].status=$st"
            if ($motivo) { $evidencia += " ($motivo)" }
            $evidencia += "; publicado=" + (DataCurta (Pega $listingSale 'firstPublicationDate')) + "; atualizado=" + (DataCurta (Pega $listingSale 'lastPublicationDate')) + "; salePrice=$preco; forSale=$forSale"
            if ($st -eq 'publicado' -and $forSale -ne $false) { $status = 'ATIVO' } else { $status = 'INATIVO' }
          } else {
            $st = "$(Pega $hi 'status')"
            $evidencia = "HTTP 200; sem listing SALE; houseInfo.status=$st; forSale=$forSale; salePrice=$preco"
            if ($st -eq 'publicado' -and $forSale -eq $true) { $status = 'ATIVO' } else { $status = 'INATIVO' }
          }
          if ((Pega $hi 'isReserved') -eq $true) { $evidencia += '; isReserved=true' }
        }
      }
    }
  }
  } while ($houseVazio -and $rodada -lt 3)
  if ($status -ne 'ATIVO' -and $status -ne 'INATIVO') { $preco = '' }
  if ($rodada -gt 1 -and -not $houseVazio) { $evidencia += "; ok na leitura $rodada (antes o site respondeu 'indisponível')" }
  $contagem[$status]++
  $resultados.Add([pscustomobject][ordered]@{
    chave = "QUINTOANDAR_$id"; status_site = $status; preco_atual = $preco
    verificado_em = (Get-Date -Format 'yyyy-MM-dd HH:mm'); evidencia = (Txt $evidencia)
  })
  Log ("{0}/{1} {2}: {3} | {4}" -f $indice, $listaIds.Count, $id, $status, (Txt $evidencia))
  if (Test-Path $arq) { Remove-Item $arq -Force }
  if ($indice -lt $listaIds.Count) { Start-Sleep -Milliseconds 500 }
}

# ---------------------------------------------------------------- CSV
$resultados | Export-Csv -Path $csvPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
$bytes = [System.IO.File]::ReadAllBytes($csvPath)
if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
  $conteudo = [System.IO.File]::ReadAllText($csvPath, [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllText($csvPath, $conteudo, $utf8bom)
}
Remove-Item $pastaTmp -Recurse -Force -ErrorAction SilentlyContinue

$relogio.Stop()
Log "== resumo =="
Log ("verificados: {0} | ATIVO {1} | INATIVO {2} | NAO_ENCONTRADO {3} | ERRO {4}" -f $listaIds.Count, $contagem.ATIVO, $contagem.INATIVO, $contagem.NAO_ENCONTRADO, $contagem.ERRO)
Log ("tempo total: {0:n1} s" -f $relogio.Elapsed.TotalSeconds)
Log ("CSV: {0}" -f $csvPath)
if ($contagem.ERRO -gt 0) { Log "RESULTADO: com ERRO (exit 2)"; exit 2 }
Log "RESULTADO: COMPLETO (exit 0)"
exit 0
