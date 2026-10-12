<#
.SINOPSE
  Verifica se anúncios do Chaves na Mão continuam no ar.

.DESCRIÇÃO
  Para cada id consulta /api/realestate/details/?id=<id> (é o mesmo objeto que a página do anúncio renderiza):
    - objeto com active=true   -> ATIVO (preco_atual = rawPrice)
    - objeto com active=false  -> INATIVO (o site devolve url "/" e a página redireciona para a home)
    - {} ou {"digest":...}     -> NAO_ENCONTRADO
    - HTTP != 200 nas 3 tentativas -> ERRO (não marcar como removido)
  Para INATIVO e NAO_ENCONTRADO abre também a página do anúncio (link do CSV, se houver) e registra na evidência
  o que o site mostrou (página "Ops! Esta página não existe" / redirecionamento). -SemPagina desliga isso;
  -ConferirAtivos abre a página também para os ATIVO.

.PARÂMETROS
  -Chaves   CSV com coluna 'chave' (CHAVESNAMAO_<id>); usa também 'link' se existir. Linhas de outras fontes são ignoradas.
  -Ids      lista de ids (alternativa ao CSV)
  -Saida    pasta de saída (padrão _dados\<hoje>)

.SAÍDA
  <Saida>\verificacao-chavesnamao.csv  (chave;status_site;preco_atual;verificado_em;evidencia)
  <Saida>\verificar-chavesnamao.log ; exit 0 = tudo verificado; exit 2 = houve ERRO.
#>
[CmdletBinding()]
param(
    [string]$Chaves = '',
    [string[]]$Ids = @(),
    [string]$Saida = '',
    [switch]$SemPagina,
    [switch]$ConferirAtivos
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Saida) { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$arqCsv = Join-Path $Saida 'verificacao-chavesnamao.csv'
$arqLog = Join-Path $Saida 'verificar-chavesnamao.log'
$pastaTmp = Join-Path $Saida 'json\chavesnamao\_verificacao'
New-Item -ItemType Directory -Force -Path $pastaTmp | Out-Null
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$utf8sem = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($arqLog, '', $utf8bom)
function Log([string]$msg) {
    $linha = (Get-Date -Format 'HH:mm:ss') + ' ' + $msg
    Write-Host $linha
    [System.IO.File]::AppendAllText($arqLog, $linha + "`r`n", $utf8sem)
}

$critArq = Join-Path $raiz 'Sites e critérios para Busca\criterios.json'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$apiDetalhes = 'https://www.chavesnamao.com.br/api/realestate/details/'
if (Test-Path $critArq) {
    $crit = Get-Content -Raw -Encoding UTF8 $critArq | ConvertFrom-Json
    if ($crit.user_agent) { $UA = [string]$crit.user_agent }
    if ($crit.sites.CHAVESNAMAO.api_detalhes) { $apiDetalhes = [string]$crit.sites.CHAVESNAMAO.api_detalhes }
}
$siteBase = 'https://www.chavesnamao.com.br'

# ------------------------------------------------------------------ entrada
$alvos = New-Object System.Collections.Generic.List[object]   # @{ id; chave; link }
if ($Chaves) {
    if (-not (Test-Path $Chaves)) { Log "ERRO: CSV não encontrado: $Chaves"; exit 2 }
    $linhasCsv = Import-Csv -Path $Chaves -Delimiter ';' -Encoding UTF8
    foreach ($l in $linhasCsv) {
        $ch = [string]$l.chave
        if ($ch -notmatch '^CHAVESNAMAO_(\d+)$') { continue }
        $lk = ''; if ($l.PSObject.Properties['link']) { $lk = [string]$l.link }
        $alvos.Add(@{ id = $matches[1]; chave = $ch; link = $lk })
    }
}
# "-Ids 1,2,3" chega como um único texto quando o script roda via powershell.exe -File: separar por vírgula
$Ids = @($Ids | ForEach-Object { $_ -split '[,; ]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($i in $Ids) { $x = ([string]$i) -replace '^CHAVESNAMAO_', ''; if ($x -match '^\d+$') { $alvos.Add(@{ id = $x; chave = "CHAVESNAMAO_$x"; link = '' }) } }
Log ("Verificador Chaves na Mão | {0} anúncio(s) | saída: {1}" -f $alvos.Count, $Saida)
if ($alvos.Count -eq 0) { Log 'Nada a verificar (use -Chaves <csv> ou -Ids).'; exit 2 }

# ------------------------------------------------------------------ HTTP e JSON
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
function Baixar([string]$url, [string]$arquivo, [switch]$SeguirRedirect) {
    $ultimo = ''
    for ($tent = 1; $tent -le 3; $tent++) {
        $argumentos = @('-s', '-m', '40', '-A', $UA, '--compressed', '-o', $arquivo, '-w', '%{http_code}|%{url_effective}')
        if ($SeguirRedirect) { $argumentos += '-L' }
        $argumentos += $url
        $resp = & $curl @argumentos   # (não usar $saida: colide com o parâmetro -Saida, PowerShell não distingue caixa)
        $ultimo = "$resp"
        if ($LASTEXITCODE -eq 0 -and $ultimo -like '200|*' -and (Test-Path $arquivo)) { return $ultimo }
        if ($tent -lt 3) { Start-Sleep -Seconds 2 }
    }
    return $ultimo
}
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue
function EhDic($o) { return ($null -ne $o) -and ($o -is [System.Collections.IDictionary]) }
function Txt($v) { if ($null -eq $v) { return '' }; return ([string]$v).Trim() }

# ------------------------------------------------------------------ verificação
$resultados = New-Object System.Collections.Generic.List[object]
$erros = 0
$n = 0
foreach ($a in $alvos) {
    $n++
    $id = $a.id
    $status = 'ERRO'; $preco = ''; $evid = ''
    $arq = Join-Path $pastaTmp "details-$id.json"
    $r = Baixar "${apiDetalhes}?id=$id" $arq
    $code = ($r -split '\|')[0]
    if ($code -ne '200') {
        $evid = "details http=$code após 3 tentativas"
        $erros++
    }
    else {
        $txt = [System.IO.File]::ReadAllText($arq)
        $o = $null
        try { $o = $js.DeserializeObject($txt) } catch { $o = $null }
        if ((EhDic $o) -and $o.ContainsKey('active')) {
            $precos = $o['prices']
            if ((EhDic $precos) -and $precos.ContainsKey('rawPrice') -and $null -ne $precos['rawPrice']) { $preco = [string][int]$precos['rawPrice'] }
            $upd = Txt $o['updatedAt']; $url = Txt $o['url']; $tr = Txt $o['transaction']
            if ($o['active'] -eq $true) {
                $status = 'ATIVO'
                $evid = "details active=true; updatedAt=$upd; url=$url"
                if (-not $a.link -and $url -and $url -ne '/') { $a.link = $siteBase + $url }
            }
            else {
                $status = 'INATIVO'
                $evid = "details active=false; transaction=$tr; updatedAt=$upd; url=$url"
            }
        }
        else {
            $status = 'NAO_ENCONTRADO'
            $t = $txt.Trim(); if ($t.Length -gt 60) { $t = $t.Substring(0, 60) + '...' }
            $evid = "details sem anúncio (resposta: $t)"
        }
    }
    # página do anúncio: confirma o que o site mostra
    $abrir = (-not $SemPagina) -and (($status -eq 'INATIVO') -or ($status -eq 'NAO_ENCONTRADO') -or ($ConferirAtivos -and $status -eq 'ATIVO'))
    if ($abrir) {
        $link = $a.link
        if (-not $link) { $link = "$siteBase/imovel/anuncio/id-$id/" }
        $arqHtml = Join-Path $pastaTmp "pagina-$id.html"
        $rp = Baixar $link $arqHtml -SeguirRedirect
        $partes = $rp -split '\|', 2
        $codeP = $partes[0]; $urlFinal = if ($partes.Count -gt 1) { $partes[1] } else { '' }
        if ($codeP -ne '200') { $evid += " | página http=$codeP" }
        else {
            $h = [System.IO.File]::ReadAllText($arqHtml) -replace '\\"', '"'
            # "Ops! Esta página não existe" aparece em TODA página (componente not-found pré-renderizado no shell do Next.js);
            # só o digest NEXT_HTTP_ERROR_FALLBACK;404 marca 404 de verdade. Anúncio inativo: a URL devolve a home
            # (título "Classificados de imóveis...", sem o id). Anúncio válido: título "... - ID: <id> | Chaves na Mão" e "id":<id>,.
            $naoExiste = $h.Contains('NEXT_HTTP_ERROR_FALLBACK;404')
            $titulo = ''; if ($h -match '<title>(.*?)</title>') { $titulo = $matches[1] }
            $temId = $h.Contains('"id":' + $id + ',') -or ($titulo -match ('ID: ' + $id + '\b'))
            $redirHome = ($urlFinal.TrimEnd('/') -eq $siteBase)
            if ($redirHome) { $evid += " | página: redirecionou para a home ($urlFinal)" }
            elseif ($naoExiste) { $evid += " | página: 404 do site (NEXT_HTTP_ERROR_FALLBACK;404, 'Ops! Esta página não existe')" }
            elseif ($temId) { $evid += " | página: anúncio presente ($titulo)" }
            else { $evid += " | página: sem o anúncio, site mostrou a home no lugar ($titulo)" }
            # se a API não achou mas a página mostra o anúncio, prevalece a página (ATIVO)
            if ($status -eq 'NAO_ENCONTRADO' -and $temId -and -not $naoExiste -and -not $redirHome) { $status = 'ATIVO'; $evid += ' | status pela página' }
        }
        Remove-Item $arqHtml -ErrorAction SilentlyContinue
    }
    Remove-Item $arq -ErrorAction SilentlyContinue
    $verificadoEm = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $resultados.Add([pscustomobject]@{ chave = $a.chave; status_site = $status; preco_atual = $preco; verificado_em = $verificadoEm; evidencia = $evid })
    Log ("  {0}/{1} {2}: {3} | preco={4} | {5}" -f $n, $alvos.Count, $a.chave, $status, $preco, $evid)
    if ($n -lt $alvos.Count) { Start-Sleep -Milliseconds 500 }
}

# ------------------------------------------------------------------ saída
$resultados | Select-Object chave, status_site, preco_atual, verificado_em, evidencia | Export-Csv -Path $arqCsv -Delimiter ';' -NoTypeInformation -Encoding UTF8
$bytes = [System.IO.File]::ReadAllBytes($arqCsv)
if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
    $t = [System.IO.File]::ReadAllText($arqCsv, [System.Text.Encoding]::UTF8); [System.IO.File]::WriteAllText($arqCsv, $t, $utf8bom)
}
Remove-Item $pastaTmp -Recurse -Force -ErrorAction SilentlyContinue
$cont = ($resultados | Group-Object status_site | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ', '
Log ("Resumo: {0} | tempo {1:n0} s | CSV: {2}" -f $cont, $relogio.Elapsed.TotalSeconds, $arqCsv)
if ($erros -gt 0) { Log "RESULTADO: houve $erros ERRO(s) (exit 2)"; exit 2 }
Log 'RESULTADO: COMPLETO (exit 0)'
exit 0
