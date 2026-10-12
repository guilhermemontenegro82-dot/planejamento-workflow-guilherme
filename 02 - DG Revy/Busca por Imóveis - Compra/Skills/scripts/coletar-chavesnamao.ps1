<#
.SINOPSE
  Coleta anúncios do Chaves na Mão (venda, Ipanema / Leblon / Arpoador) e grava bruto-chavesnamao.csv
  conforme o contrato de dados (Skills\CONTRATO-DADOS.md).

.DESCRIÇÃO
  Fonte principal: API interna do mapa  /api/realestate/search-map-items/  (paginação por cursor, completa).
  Alternativa (-Endpoint lista):        /api/realestate/listing/items/     (paginação por pg; trava em 25 páginas
                                        e depois devolve "similares" da cidade inteira — detectado por metadata.pageBreak).
  Para cada anúncio consulta /api/realestate/details/?id=<id> (mesmo objeto que a página renderiza: active,
  updatedAt, preços, descrição completa) e grava o trecho útil em <Saida>\json\chavesnamao\<id>.json.
  Abre N páginas HTML de anúncio (-ConferirPaginas) só para conferir rótulos (Condomínio "/mês", IPTU sem base)
  e as datas do ld+json.

.PARÂMETROS
  -Saida            pasta de saída (padrão _dados\<hoje>)
  -Criterios        caminho do criterios.json (padrão Sites e critérios para Busca\criterios.json)
  -Endpoint         mapa (padrão) | lista
  -Level3           lista de bairros (ex.: ipanema,leblon) para buscar por bairro em vez de caixa (só com -Endpoint lista)
  -Level1           tipo de imóvel na URL (padrão: o de criterios.json ou imoveis-a-venda)
  -SemDetalhes      não consulta /details/ por anúncio (coleta rápida)
  -ConferirPaginas  quantas páginas HTML de anúncio abrir para conferência (padrão 3; 0 desliga)

.SAÍDA
  <Saida>\bruto-chavesnamao.csv, <Saida>\json\chavesnamao\<id>.json, <Saida>\coletar-chavesnamao.log
  exit 0 = completo; exit 2 = alguma página/lote/detalhe falhou nas 3 tentativas (ver log).
#>
[CmdletBinding()]
param(
    [string]$Saida = '',
    [string]$Criterios = '',
    [ValidateSet('mapa', 'lista')][string]$Endpoint = 'mapa',
    [string[]]$Level3 = @(),
    [string[]]$Complemento = @(),
    [switch]$SemComplemento,
    [string]$Level1 = '',
    [switch]$SemDetalhes,
    [int]$ConferirPaginas = 3
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

# ------------------------------------------------------------------ caminhos
$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Criterios) { $Criterios = Join-Path $raiz 'Sites e critérios para Busca\criterios.json' }
if (-not $Saida) { $Saida = Join-Path $raiz ('_dados\' + (Get-Date -Format 'yyyy-MM-dd')) }
$pastaJson = Join-Path $Saida 'json\chavesnamao'
$pastaLotes = Join-Path $pastaJson '_lotes'
New-Item -ItemType Directory -Force -Path $pastaLotes | Out-Null
$arqCsv = Join-Path $Saida 'bruto-chavesnamao.csv'
$arqLog = Join-Path $Saida 'coletar-chavesnamao.log'
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$utf8sem = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($arqLog, '', $utf8bom)

function Log([string]$msg) {
    $linha = (Get-Date -Format 'HH:mm:ss') + ' ' + $msg
    Write-Host $linha
    [System.IO.File]::AppendAllText($arqLog, $linha + "`r`n", $utf8sem)
}

# ------------------------------------------------------------------ critérios
$crit = Get-Content -Raw -Encoding UTF8 $Criterios | ConvertFrom-Json
$pmin = [int]$crit.preco_min; $pmax = [int]$crit.preco_max
$amin = [int]$crit.area_util_min; $amax = [int]$crit.area_util_max
$cnm = $crit.sites.CHAVESNAMAO
$UA = if ($crit.user_agent) { [string]$crit.user_agent } else { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36' }
$apiLista = if ($cnm.api) { [string]$cnm.api } else { 'https://www.chavesnamao.com.br/api/realestate/listing/items/' }
$apiMapa = if ($cnm.api_mapa) { [string]$cnm.api_mapa } else { 'https://www.chavesnamao.com.br/api/realestate/search-map-items/' }
$apiDetalhes = if ($cnm.api_detalhes) { [string]$cnm.api_detalhes } else { 'https://www.chavesnamao.com.br/api/realestate/details/' }
if (-not $Level1) { $Level1 = if ($cnm.level1) { [string]$cnm.level1 } else { 'imoveis-a-venda' } }
$iptuLimiteMensal = if ($cnm.iptu_limite_mensal) { [int]$cnm.iptu_limite_mensal } else { 700 }
$siteBase = 'https://www.chavesnamao.com.br'
$filtro = "pmin:$pmin,pmax:$pmax,amin:$amin,amax:$amax"
$filtroEnc = [uri]::EscapeDataString($filtro)

# "-Level3 ipanema,leblon" chega como um único texto quando o script roda via powershell.exe -File: separar aqui
$Level3 = @($Level3 | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
# Complemento: bairros buscados por nome além das caixas (pega anúncios com lat/lon trocados no site)
if ($Complemento.Count -eq 0 -and $cnm.level3_complemento) { $Complemento = @($cnm.level3_complemento) }
$Complemento = @($Complemento | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($SemComplemento) { $Complemento = @() }
$caixas = @()
foreach ($p in $cnm.caixas.PSObject.Properties) {
    $caixas += [pscustomobject]@{ nome = $p.Name; N = [double]$p.Value.mapNorth; S = [double]$p.Value.mapSouth; E = [double]$p.Value.mapEast; W = [double]$p.Value.mapWest }
}
if ($Level3.Count -gt 0 -and $Endpoint -eq 'mapa') {
    Log "AVISO: level3 só funciona no endpoint 'lista' (o do mapa exige caixa) — trocando para -Endpoint lista."
    $Endpoint = 'lista'
}

Log "Coletor Chaves na Mão | endpoint=$Endpoint | level1=$Level1 | filtro=$filtro"
Log "Saída: $Saida"
if ($Level3.Count -gt 0) { Log ("Escopos (level3): " + ($Level3 -join ', ')) }
else {
    foreach ($cx in $caixas) { Log ("Caixa {0}: N={1} S={2} E={3} W={4}" -f $cx.nome, $cx.N.ToString($inv), $cx.S.ToString($inv), $cx.E.ToString($inv), $cx.W.ToString($inv)) }
    if ($Complemento.Count -gt 0) { Log ("Complemento por bairro (level3, endpoint lista): " + ($Complemento -join ', ')) }
}

# ------------------------------------------------------------------ HTTP (só curl.exe; .NET é barrado pelo Cloudflare)
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
function Baixar([string]$url, [string]$arquivo, [switch]$SeguirRedirect) {
    $ultimo = ''
    for ($tent = 1; $tent -le 3; $tent++) {
        $argumentos = @('-s', '-m', '40', '-A', $UA, '--compressed', '-o', $arquivo, '-w', '%{http_code}')
        if ($SeguirRedirect) { $argumentos += '-L' }
        $argumentos += $url
        $code = & $curl @argumentos
        $ultimo = "$code"
        if ($LASTEXITCODE -eq 0 -and $ultimo -eq '200' -and (Test-Path $arquivo)) { return '200' }
        if ($tent -lt 3) { Start-Sleep -Seconds 2 }
    }
    return $ultimo
}

$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue
$js.RecursionLimit = 500
function LerJson([string]$arquivo) {
    $txt = [System.IO.File]::ReadAllText($arquivo)
    return $js.DeserializeObject($txt)
}
function EhDic($o) { return ($null -ne $o) -and ($o -is [System.Collections.IDictionary]) }

# ------------------------------------------------------------------ acumuladores
$itens = [ordered]@{}      # id -> item (dicionário da API)
$origem = @{}              # id -> lista de escopos onde apareceu
$falhas = 0                # falhas de rede após 3 tentativas
$incompletos = 0           # escopos em que o site declarou mais resultados do que entregou (cobertura truncada)
$resumoEscopos = New-Object System.Collections.Generic.List[string]

function Registrar($it, [string]$escopo) {
    $id = [string]$it['id']
    if (-not $script:itens.Contains($id)) {
        $script:itens[$id] = $it
        $script:origem[$id] = New-Object System.Collections.Generic.List[string]
        $script:novosNoEscopo++
    }
    if (-not $script:origem[$id].Contains($escopo)) { $script:origem[$id].Add($escopo) }
}

function CaixaQuery($cx) {
    return ('mapNorth={0}&mapSouth={1}&mapEast={2}&mapWest={3}&locationScope=area' -f $cx.N.ToString($inv), $cx.S.ToString($inv), $cx.E.ToString($inv), $cx.W.ToString($inv))
}

# --- endpoint do mapa: cursor ---------------------------------------------------------------
function ColetarMapa($cx) {
    $nome = $cx.nome
    $script:novosNoEscopo = 0
    $cursor = ''; $lote = 0; $total = -1; $recebidos = 0; $lotesOk = 0; $lotesFalha = 0
    while ($true) {
        $lote++
        $url = "${apiMapa}?level1=$Level1&level2=rj-rio-de-janeiro&" + (CaixaQuery $cx) + "&filtro=$filtroEnc"
        if ($cursor) { $url += "&cursor=$cursor" }
        $arq = Join-Path $pastaLotes ("$nome-lote{0:D3}.json" -f $lote)
        $code = Baixar $url $arq
        if ($code -ne '200') { Log "  [FALHA] $nome lote $lote http=$code (3 tentativas)"; $lotesFalha++; $script:falhas++; break }
        $o = LerJson $arq
        if (-not (EhDic $o)) { Log "  [FALHA] $nome lote ${lote}: resposta não é JSON de objeto"; $lotesFalha++; $script:falhas++; break }
        if ($total -lt 0) { $total = [int]$o['totalResults'] }
        $lista = @(); if ($o.ContainsKey('items') -and $o['items']) { $lista = @($o['items']) }
        $n = 0
        foreach ($it in $lista) { if ((EhDic $it) -and $it.ContainsKey('id')) { Registrar $it $nome; $n++ } }
        $recebidos += $n; $lotesOk++
        $prox = ''; if ($o.ContainsKey('cursor') -and $o['cursor']) { $prox = [string]$o['cursor'] }
        if ($n -eq 0 -or -not $prox) { break }
        if ($prox -eq $cursor) { Log "  AVISO: $nome lote ${lote}: o site repetiu o cursor; parando para não entrar em laço"; break }
        if ($lote -ge 400) { Log "  AVISO: $nome atingiu o limite de segurança de 400 lotes; parando"; break }
        $cursor = $prox
        Start-Sleep -Milliseconds 400
    }
    $msg = "Caixa ${nome}: totalResults(site)=$total | itens recebidos=$recebidos | novos (não vistos antes)=$($script:novosNoEscopo) | lotes ok=$lotesOk falha=$lotesFalha"
    Log $msg; $script:resumoEscopos.Add($msg)
    # cobertura truncada nunca passa em silêncio: conta como incompleto (exit 2) mesmo sem falha de rede
    if ($total -ge 0 -and $recebidos -lt $total) {
        $script:incompletos++
        Log ("  INCOMPLETO: {0} entregou {1} de {2} resultados declarados pelo site (faltam {3})" -f $nome, $recebidos, $total, ($total - $recebidos))
    }
}

# --- coordenadas: o site às vezes grava lat e lon trocados (lat=-43.19, lon=-22.98); corrigir ao ler -------------
function LerCoord($gp) {
    $r = @{ ok = $false; la = 0.0; lo = 0.0; trocada = $false }
    if (-not (EhDic $gp)) { return $r }
    $la = 0.0; $lo = 0.0
    if (-not [double]::TryParse(([string]$gp['lat']).Trim(), [System.Globalization.NumberStyles]::Float, $inv, [ref]$la)) { return $r }
    if (-not [double]::TryParse(([string]$gp['lon']).Trim(), [System.Globalization.NumberStyles]::Float, $inv, [ref]$lo)) { return $r }
    if ($la -eq 0 -or $lo -eq 0) { return $r }
    if ($la -lt -30 -and $lo -gt -30) { $tmp = $la; $la = $lo; $lo = $tmp; $r.trocada = $true }
    $r.ok = $true; $r.la = $la; $r.lo = $lo
    return $r
}

# --- endpoint da lista: pg + detecção de "similares" ---------------------------------------
function DentroDaCaixa($it, $cx) {
    if ($null -eq $cx) { return $true }
    $loc = $it['location']; if (-not (EhDic $loc)) { return $true }
    $c = LerCoord $loc['geoposition']
    if (-not $c.ok) { return $true }
    return ($c.la -le $cx.N -and $c.la -ge $cx.S -and $c.lo -le $cx.E -and $c.lo -ge $cx.W)
}
function ColetarLista($cx, [string]$bairro) {
    # $bairro (level3 do site) — nome diferente do parâmetro -Level3 do script para não confundir os escopos
    $nome = if ($bairro) { "level3-$bairro" } else { $cx.nome }
    $script:novosNoEscopo = 0
    $base = "${apiLista}?level1=$Level1&level2=rj-rio-de-janeiro"
    if ($bairro) { $base += "&level3=$bairro" } else { $base += '&' + (CaixaQuery $cx) }
    $base += "&filtro=$filtroEnc"
    $pg = 0; $total = -1; $reais = -1; $recebidos = 0; $foraCaixa = 0; $pagOk = 0; $pagFalha = 0; $motivoFim = 'fim das páginas'
    while ($true) {
        $pg++
        $arq = Join-Path $pastaLotes ("$nome-pg{0:D3}.json" -f $pg)
        $code = Baixar "$base&pg=$pg" $arq
        if ($code -ne '200') { Log "  [FALHA] $nome pg=$pg http=$code (3 tentativas)"; $pagFalha++; $script:falhas++; $motivoFim = 'falha'; break }
        $o = LerJson $arq
        $md = $null; if ((EhDic $o) -and $o.ContainsKey('metadata')) { $md = $o['metadata'] }
        if (-not (EhDic $md)) { Log "  [FALHA] $nome pg=${pg}: sem metadata"; $pagFalha++; $script:falhas++; $motivoFim = 'falha'; break }
        $tl = [int]$md['totalListing']
        $pb = @(); if ($md.ContainsKey('pageBreak') -and $md['pageBreak']) { $pb = @($md['pageBreak']) }
        if ($total -lt 0) { $total = $tl; $reais = if ($pb.Count -gt 0) { [int]$pb[0] } else { $tl } }
        if ($pb.Count -gt 1 -or $tl -ne $total) {
            $motivoFim = "pg=$pg veio com 'similares' da cidade (pageBreak=[" + ($pb -join ',') + "], totalListing=$tl): fim dos resultados reais"
            Log "  $nome $motivoFim"
            break
        }
        $lista = @(); if ($o.ContainsKey('items') -and $o['items']) { $lista = @($o['items']) }
        $n = 0
        foreach ($it in $lista) {
            if (-not ((EhDic $it) -and $it.ContainsKey('id'))) { continue }
            if (-not $bairro -and -not (DentroDaCaixa $it $cx)) { $foraCaixa++; continue }
            Registrar $it $nome; $n++
        }
        $recebidos += $n; $pagOk++
        $paginas = [int][math]::Ceiling($reais / 15.0)
        if ($pg -ge $paginas -or $lista.Count -le 1) { break }
        if ($pg -ge 60) { $motivoFim = 'limite de segurança (60 páginas)'; Log "  AVISO: $nome $motivoFim"; break }
        Start-Sleep -Milliseconds 400
    }
    $msg = "Escopo ${nome}: totalListing(site)=$total (reais=$reais) | itens recebidos=$recebidos | fora da caixa=$foraCaixa | novos=$($script:novosNoEscopo) | páginas ok=$pagOk falha=$pagFalha | $motivoFim"
    Log $msg; $script:resumoEscopos.Add($msg)
    if ($reais -ge 0 -and $recebidos -lt $reais -and $pagFalha -eq 0) { Log "  AVISO: recebidos < resultados reais declarados em $nome (o endpoint 'lista' mistura 'similares' nas últimas ~2 páginas e perde ~25 anúncios; use -Endpoint mapa)" }
}

# ------------------------------------------------------------------ 1) busca
Log '--- 1) Busca ---'
$tBusca = [System.Diagnostics.Stopwatch]::StartNew()
if ($Level3.Count -gt 0) { foreach ($lv in $Level3) { ColetarLista $null $lv } }
else {
    if ($Endpoint -eq 'mapa') { foreach ($cx in $caixas) { ColetarMapa $cx } }
    else { foreach ($cx in $caixas) { ColetarLista $cx '' } }
    foreach ($lv in $Complemento) { ColetarLista $null $lv }
}
$tBusca.Stop()
Log ("Busca: {0} anúncios únicos em {1:n0} s" -f $itens.Count, $tBusca.Elapsed.TotalSeconds)

# ------------------------------------------------------------------ utilitários de normalização
function Txt($v) { if ($null -eq $v) { return '' }; return ([string]$v).Trim() }
function Limpar($s) {
    $t = Txt $s
    if (-not $t) { return '' }
    $t = $t -replace '<ver_telefone>', ''
    $t = $t -replace '(?i)<br\s*/?>', ' '
    $t = $t -replace '<[^>]+>', ' '
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}
function NumBR($s) {
    # "R$ 1.600" -> 1600 ; "R$ 1.023,50" -> 1024 (arredonda) ; vazio -> $null
    $t = Txt $s; if (-not $t) { return $null }
    $t = $t -replace '[^\d,\.]', ''
    if (-not $t) { return $null }
    if ($t -match ',') { $t = ($t -replace '\.', '') -replace ',', '.' } elseif ($t -match '^\d{1,3}(\.\d{3})+$') { $t = $t -replace '\.', '' }
    $d = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return [int][math]::Round($d) }
    return $null
}
function NumArea($s) {
    $t = Txt $s; if (-not $t) { return $null }
    $t = ($t -replace '[^\d,\.]', '') -replace ',', '.'
    $d = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d) -and $d -gt 0) { return $d }
    return $null
}
function FmtNum($d) { if ($null -eq $d) { return '' }; return ([double]$d).ToString('0.##', $inv) }
function Inteiro($v) { if ($null -eq $v -or "$v" -eq '') { return '' }; try { return [string][int]$v } catch { return '' } }
function Coord($s) {
    $d = 0.0
    if ([double]::TryParse((Txt $s), [System.Globalization.NumberStyles]::Float, $inv, [ref]$d) -and $d -ne 0) { return $d.ToString('0.#######', $inv) }
    return ''
}
function DataIso($s) { $t = Txt $s; if ($t -match '^(\d{4}-\d{2}-\d{2})') { return $matches[1] }; return '' }
function Rua($s) {
    $t = Limpar $s
    if (-not $t) { return '' }
    return [regex]::Replace($t, '\b(De|Da|Do|Das|Dos|E)\b', [System.Text.RegularExpressions.MatchEvaluator] { param($m) $m.Value.ToLowerInvariant() })
}
function MapearTipo($nome) {
    $n = (Txt $nome).ToLowerInvariant()
    if ($n -match 'kitnet|kitinete|quitinete|st[uú]dio|studio|loft|conjugado') { return 'Kitnet/Studio' }
    if ($n -match 'cobertura') { return 'Cobertura' }
    if ($n -match '\bflat\b|apart.?hotel') { return 'Flat' }
    if ($n -match 'apartamento') { return 'Apartamento' }
    return 'Outro'
}
function IptuNumeros([string]$trecho) {
    # números em formato pt-BR dentro do trecho ("1.053", "105,30", "2.600,00", "330") -> lista de @{ valor; pos; fim }
    $lista = @()
    foreach ($m in [regex]::Matches($trecho, '(?<![\d,])(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?(?!\d)')) {
        $parteInt = $m.Groups[1].Value -replace '\.', ''
        $parteDec = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { '0' }
        $lista += @{ valor = [double]::Parse($parteInt + '.' + $parteDec, $inv); pos = $m.Index; fim = $m.Index + $m.Length }
    }
    return $lista
}
function Perto([double]$a, [double]$b) { return ([math]::Abs($a - $b) -le [math]::Max(1.0, $b * 0.01)) }
function NormalizarIptu($valor, [string]$descricao) {
    # O site não rotula a base do IPTU (Condomínio sai "/mês", IPTU sai só "R$ x"). Regra, nesta ordem:
    # 1) a descrição cita o IPTU com valor e base: valor igual ao do site com "/ano|anual" -> ano, com "/mês|mensal" -> mês;
    #    descrição dá a cota mensal e o site mostra 10x ou 12x a cota -> ano; "N cotas de R$ x" com x igual ao do site -> mês;
    #    descrição dá o anual e o site mostra 1/10 ou 1/12 dele -> mês;
    # 2) a descrição só diz a base (sem valor que case): usa a base, se for uma só;
    # 3) sem dica: valor <= limite => mensal (cota), acima => anual.
    # A janela de leitura começa em "iptu" e para em ";", em ponto que não seja separador de milhar ou em "condom"
    # (o "/mês" do condomínio vinha sendo atribuído ao IPTU quando os dois apareciam juntos).
    if ($null -eq $valor -or $valor -le 0) { return @{ mes = ''; informado = '' } }
    $d = $descricao.ToLowerInvariant()
    $base = ''; $origemBase = ''
    $reAno = 'anual|/\s*ano|ao ano|por ano|a\.a\.|\bano\b'
    $reMes = 'mensal|mensais|/\s*m[êe]s\b|por m[êe]s|ao m[êe]s|\bm[êe]s\b|cotas? de|parcelas? de'
    $viuAno = $false; $viuMes = $false
    foreach ($j in [regex]::Matches($d, 'iptu(?:(?!condom)(?:[^.;]|\.(?=\d))){0,90}')) {
        $txt = $j.Value
        if ($txt -match $reAno) { $viuAno = $true }
        if ($txt -match $reMes) { $viuMes = $true }
        foreach ($n in (IptuNumeros $txt)) {
            if ($n.valor -lt 10) { continue }   # ignora "2 quartos", "5º andar"
            $depois = $txt.Substring($n.fim, [math]::Min(14, $txt.Length - $n.fim))
            $ini = [math]::Max(0, $n.pos - 30); $antes = $txt.Substring($ini, $n.pos - $ini)
            $baseN = ''
            if ($depois -match '^\s*(/\s*ano|anual|ao ano|por ano|a\.a\.)') { $baseN = 'ano' }
            elseif ($depois -match '^\s*(/\s*m[êe]s|mensal|mensais|por m[êe]s|ao m[êe]s)') { $baseN = 'mês' }
            elseif ($antes -match '(anual|/\s*ano|ao ano|por ano)[^\d]*$') { $baseN = 'ano' }
            elseif ($antes -match '(mensal|mensais|/\s*m[êe]s|por m[êe]s|ao m[êe]s|cotas? de|parcelas? de)[^\d]*$') { $baseN = 'mês' }
            if (-not $baseN) { continue }
            if (Perto $n.valor $valor) { $base = $baseN; $origemBase = 'descrição'; break }
            if ($baseN -eq 'mês' -and ((Perto ($n.valor * 10) $valor) -or (Perto ($n.valor * 12) $valor))) { $base = 'ano'; $origemBase = 'descrição: cota mensal x 10 ou 12'; break }
            if ($baseN -eq 'ano' -and ((Perto ($valor * 10) $n.valor) -or (Perto ($valor * 12) $n.valor))) { $base = 'mês'; $origemBase = 'descrição: anual / 10 ou 12'; break }
        }
        if ($base) { break }
    }
    if (-not $base) {
        if ($viuAno -and -not $viuMes) { $base = 'ano'; $origemBase = 'descrição' }
        elseif ($viuMes -and -not $viuAno) { $base = 'mês'; $origemBase = 'descrição' }
        else { $base = if ($valor -le $iptuLimiteMensal) { 'mês' } else { 'ano' }; $origemBase = 'estimado pelo valor' }
    }
    $mes = if ($base -eq 'ano') { [int][math]::Round($valor / 12.0) } else { [int]$valor }
    return @{ mes = [string]$mes; informado = "$valor/$base ($origemBase)"; base = $base; origem = $origemBase }
}
function ExtrairAndar([string]$texto) {
    $t = $texto.ToLowerInvariant()
    # "\b" depois de "andar" evita ler "prédio de 10 andares" como andar 10
    if ($t -match '(?<![\w])(\d{1,2})\s*[ºo°]?\s*andar\b') { return [string][int]$matches[1] }   # "03" -> "3"
    if ($t -match '\bandar\s+(\d{1,2})\b(?!\s*h)') { return [string][int]$matches[1] }
    return ''
}
$mapaDestaques = [ordered]@{
    'varanda'              = 'varanda|sacada|terra[çc]o'
    'vista mar'            = 'vista (para o |pro |do |de |ao )?mar\b|vista[- ]mar|frente (para o |pro )?mar\b|vista oce[aâ]n'
    'vista livre'          = 'vista livre|vista desimpedida|vista panor[aâ]mica'
    'reformado'            = 'reformad|reforma recente'
    'garden'               = '\bgarden\b'
    'elevador'             = 'elevador'
    'portaria 24h'         = 'portaria 24|porteiro 24|portaria.{0,12}24 ?h|24 ?horas de portaria'
    'piscina'              = 'piscina'
    'academia'             = 'academia|fitness|\bgym\b'
    'mobiliado'            = 'mobiliad|mob[ií]lia\b'
    'andar alto'           = 'andar alto|andares altos|alto andar'
    'quadra da praia'      = 'quadra da praia|primeira quadra|1[ªa°º] quadra'
    'aceita financiamento' = 'financiamento|financi[aá]vel|aceita financ|\bfgts\b'
    'aceita permuta'       = 'permuta'
    'sol da manhã'         = 'sol da manh|nascente'
    'silencioso'           = 'silencios'
    'vaga na escritura'    = 'vaga (na )?escritura|escriturada'
    'dependência'          = 'depend[êe]ncia|quarto de empregada|\bdce\b|quarto e banheiro de servi'
    'churrasqueira'        = 'churrasqueira'
    'pet'                  = 'pet ?friendly|aceita pet|aceita animais|\bpets?\b'
    'lavabo'               = 'lavabo'
}
function Destaques($it, [string]$texto) {
    $t = $texto.ToLowerInvariant()
    $achados = New-Object System.Collections.Generic.List[string]
    foreach ($k in $mapaDestaques.Keys) { if ($t -match $mapaDestaques[$k]) { $achados.Add($k) } }
    # acceptTrade vem true em 100% dos anúncios (padrão do site), por isso NÃO entra como destaque; permuta só pelo texto
    if ($it.ContainsKey('petFriendly') -and $it['petFriendly'] -eq $true -and -not $achados.Contains('pet')) { $achados.Add('pet') }
    return ($achados -join ' | ')
}
function NomesItens($lista) {
    $n = @(); if ($lista) { foreach ($x in @($lista)) { if ((EhDic $x) -and $x.ContainsKey('name')) { $n += (Txt $x['name']) } } }
    return $n
}

$colunas = @('chave', 'fonte', 'codigo', 'link', 'link_alt', 'tipo', 'titulo', 'rua', 'numero', 'cep', 'bairro_site', 'lat', 'lon', 'precisao_coord',
    'preco', 'area_util', 'area_total', 'condominio_mes', 'iptu_mes', 'iptu_informado', 'quartos', 'banheiros', 'suites', 'vagas', 'andar',
    'anunciante', 'tipo_anunciante', 'publicado_em', 'atualizado_em', 'capturado_em', 'fotos', 'destaques', 'descricao_resumo', 'status_site', 'bruto_json')

function MontarLinha($it, [string]$capturado, [string]$statusSite, [string]$caminhoJson) {
    # $capturado: nome diferente da variável de script $capturadoEm (PowerShell não distingue caixa; evita sombra)
    $id = [string]$it['id']
    $loc = $it['location']
    $st = $null; $nb = $null; $gp = $null; $ngp = $null; $cep = ''; $pub = $true
    if (EhDic $loc) {
        if ($loc.ContainsKey('street')) { $st = $loc['street'] }
        if ($loc.ContainsKey('neighborhood')) { $nb = $loc['neighborhood'] }
        if ($loc.ContainsKey('geoposition')) { $gp = $loc['geoposition'] }
        if ((EhDic $nb) -and $nb.ContainsKey('geoposition')) { $ngp = $nb['geoposition'] }
        if ($loc.ContainsKey('zipCode')) { $cep = Txt $loc['zipCode'] }
        if ($loc.ContainsKey('publicAddress') -and $null -ne $loc['publicAddress']) { $pub = [bool]$loc['publicAddress'] }
    }
    $rua = ''; $numero = ''
    if (EhDic $st) {
        $rua = Rua $st['name']
        $numero = Txt $st['addressNumber']
        if ($numero -notmatch '\d') { $numero = '' }
    }
    if ($cep -match '^(\d{5})-?(\d{3})$') { $cep = $matches[1] + '-' + $matches[2] } else { $cep = '' }
    if ($cep -eq '00000-000') { $cep = '' }
    $lat = ''; $lon = ''; $prec = 'nenhuma'
    $c = LerCoord $gp
    if ($c.ok) {
        if ($c.trocada) { $script:coordTrocadas++ }
        $la = $c.la.ToString('0.#######', $inv); $lo = $c.lo.ToString('0.#######', $inv)
        $igualBairro = $false
        $cb = LerCoord $ngp
        if ($cb.ok) { $igualBairro = ([math]::Abs($c.la - $cb.la) -lt 0.0000005) -and ([math]::Abs($c.lo - $cb.lo) -lt 0.0000005) }
        if (-not $igualBairro) {
            $lat = $la; $lon = $lo
            # com número e endereço público, o ponto vem do endereço; sem número, é o ponto da rua (vários anúncios repetem a mesma coordenada)
            $prec = if ($numero -and $pub) { 'exata' } else { 'aproximada' }
        }
    }
    $precos = $it['prices']; if (-not (EhDic $precos)) { $precos = @{} }
    $preco = $null; if ($precos.ContainsKey('rawPrice') -and $null -ne $precos['rawPrice']) { $preco = [int]$precos['rawPrice'] }
    $area = $it['area']; if (-not (EhDic $area)) { $area = @{} }
    $areaUtil = $null; $areaTotal = $null
    if ($area.ContainsKey('useful')) { $areaUtil = NumArea $area['useful'] }
    if ($area.ContainsKey('total')) { $areaTotal = NumArea $area['total'] }
    if ($null -eq $areaUtil) { $areaUtil = $areaTotal }
    $cond = $null; if ($precos.ContainsKey('condominiumFee')) { $cond = NumBR $precos['condominiumFee'] }
    $iptuBruto = $null; if ($precos.ContainsKey('iptuValue')) { $iptuBruto = NumBR $precos['iptuValue'] }
    $titulo = Limpar $it['title']
    $descricao = ''
    if ($it.ContainsKey('descriptionRaw') -and (Txt $it['descriptionRaw'])) { $descricao = Limpar $it['descriptionRaw'] } elseif ($it.ContainsKey('description')) { $descricao = Limpar $it['description'] }
    $iptu = NormalizarIptu $iptuBruto $descricao
    $priv = NomesItens $it['privativeItems']; $com = NomesItens $it['commonItems']
    $textoBusca = ($titulo + ' ' + $descricao + ' ' + ($priv -join ' ') + ' ' + ($com -join ' '))
    $pubr = $it['publisher']; if (-not (EhDic $pubr)) { $pubr = @{} }
    $tipoAnunciante = ''
    if ($pubr.ContainsKey('type')) { switch ((Txt $pubr['type']).ToUpperInvariant()) { 'PJ' { $tipoAnunciante = 'Imobiliária' } 'PF' { $tipoAnunciante = 'Particular' } } }
    $anunciante = ''; if ($pubr.ContainsKey('name')) { $anunciante = Limpar $pubr['name'] }
    if ($tipoAnunciante -eq 'Imobiliária' -and $anunciante -match '(?i)construtora|incorporadora') { $tipoAnunciante = 'Construtora' }
    function Cont($k) { $x = $it[$k]; if ((EhDic $x) -and $x.ContainsKey('count')) { return Inteiro $x['count'] }; return '' }
    $fotos = ''; $pics = $it['pictures']; if ((EhDic $pics) -and $pics.ContainsKey('count')) { $fotos = Inteiro $pics['count'] }
    $tipo = ''; $rt = $it['realtyType']; if (EhDic $rt) { $tipo = MapearTipo $rt['name'] }
    $url = Txt $it['url']; $link = if ($url -match '^https?://') { $url } elseif ($url) { $siteBase + $url } else { '' }
    $resumo = if ($descricao.Length -gt 300) { $descricao.Substring(0, 300) } else { $descricao }
    if ($titulo.Length -gt 200) { $titulo = $titulo.Substring(0, 200) }

    $linha = [ordered]@{}
    $linha.chave = "CHAVESNAMAO_$id"
    $linha.fonte = 'CHAVESNAMAO'
    $linha.codigo = $id
    $linha.link = $link
    $linha.link_alt = ''
    $linha.tipo = $tipo
    $linha.titulo = $titulo
    $linha.rua = $rua
    $linha.numero = $numero
    $linha.cep = $cep
    $linha.bairro_site = if (EhDic $nb) { Limpar $nb['name'] } else { '' }
    $linha.lat = $lat
    $linha.lon = $lon
    $linha.precisao_coord = $prec
    $linha.preco = Inteiro $preco
    $linha.area_util = FmtNum $areaUtil
    $linha.area_total = FmtNum $areaTotal
    $linha.condominio_mes = Inteiro $cond
    $linha.iptu_mes = $iptu.mes
    $linha.iptu_informado = $iptu.informado
    $linha.quartos = Cont 'bedrooms'
    $linha.banheiros = Cont 'bathrooms'
    $linha.suites = Cont 'suites'
    $linha.vagas = Cont 'garages'
    $linha.andar = ExtrairAndar ($titulo + ' ' + $descricao)
    $linha.anunciante = $anunciante
    $linha.tipo_anunciante = $tipoAnunciante
    $linha.publicado_em = DataIso $it['createdAt']
    $linha.atualizado_em = DataIso $it['updatedAt']
    $linha.capturado_em = $capturado
    $linha.fotos = $fotos
    $linha.destaques = Destaques $it $textoBusca
    $linha.descricao_resumo = $resumo
    $linha.status_site = $statusSite
    $linha.bruto_json = $caminhoJson
    return [pscustomobject]$linha
}

# ------------------------------------------------------------------ 2) filtro local (preço, área, tipo, venda)
Log '--- 2) Filtro local dos critérios ---'
$aceitos = New-Object System.Collections.Generic.List[string]
$excluidos = @{ 'fora de preço' = 0; 'fora de área' = 0; 'tipo não residencial' = 0; 'não é venda' = 0; 'sem preço/área' = 0 }
foreach ($id in @($itens.Keys)) {
    $it = $itens[$id]
    $precos = $it['prices']; $area = $it['area']
    $preco = $null; if ((EhDic $precos) -and $precos.ContainsKey('rawPrice') -and $null -ne $precos['rawPrice']) { $preco = [int]$precos['rawPrice'] }
    $au = $null; if (EhDic $area) { if ($area.ContainsKey('useful')) { $au = NumArea $area['useful'] }; if ($null -eq $au -and $area.ContainsKey('total')) { $au = NumArea $area['total'] } }
    $tipo = 'Outro'; $rt = $it['realtyType']; if (EhDic $rt) { $tipo = MapearTipo $rt['name'] }
    $cat = (Txt $it['category']).ToLowerInvariant()
    $tr = (Txt $it['transaction']).ToUpperInvariant()
    if ($null -eq $preco -or $null -eq $au) { $excluidos['sem preço/área']++; continue }
    if ($tr -and $tr -ne 'SELL') { $excluidos['não é venda']++; continue }
    if ($tipo -eq 'Outro' -or $cat -eq 'commercial') { $excluidos['tipo não residencial']++; continue }
    if ($preco -lt $pmin -or $preco -gt $pmax) { $excluidos['fora de preço']++; continue }
    if ($au -lt $amin -or $au -gt $amax) { $excluidos['fora de área']++; continue }
    $aceitos.Add($id)
}
Log ("Aceitos: {0} | excluídos: {1}" -f $aceitos.Count, (($excluidos.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Value }) -join ', '))

# ------------------------------------------------------------------ 3) detalhes por anúncio
$chavesTrim = @('id', 'title', 'reference', 'active', 'status', 'acceptTrade', 'petFriendly', 'url', 'category', 'transaction', 'realtyType',
    'prices', 'area', 'bedrooms', 'bathrooms', 'suites', 'garages', 'location', 'publisher', 'privativeItems', 'commonItems', 'media',
    'createdAt', 'updatedAt', 'description', 'descriptionRaw', 'locationPeriod')
function Trim($it) {
    $t = [ordered]@{}
    foreach ($k in $chavesTrim) { if ($it.ContainsKey($k)) { $t[$k] = $it[$k] } }
    if ($it.ContainsKey('pictures') -and (EhDic $it['pictures'])) { $p = $it['pictures']; $t['pictures'] = [ordered]@{ count = $p['count']; featured = $p['featured'] } }
    if ((EhDic $t['publisher'])) { $pb = $t['publisher']; $t['publisher'] = [ordered]@{ id = $pb['id']; name = $pb['name']; type = $pb['type']; creci = $pb['creci']; url = $pb['url'] } }
    return $t
}
$detOk = 0; $detVazio = 0; $detFalha = 0; $detInativo = 0
$capturadoEm = Get-Date -Format 'yyyy-MM-dd HH:mm'
$statusPorId = @{}
$tDet = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $SemDetalhes) {
    Log ("--- 3) Detalhes por anúncio ({0}) ---" -f $aceitos.Count)
    $k = 0
    foreach ($id in $aceitos) {
        $k++
        $arqTmp = Join-Path $pastaLotes "detalhe-$id.json"
        $code = Baixar "${apiDetalhes}?id=$id" $arqTmp
        $fonte = 'busca'
        if ($code -ne '200') { $detFalha++; $script:falhas++; Log "  [FALHA] detalhe $id http=$code" }
        else {
            $o = LerJson $arqTmp
            if ((EhDic $o) -and $o.ContainsKey('active')) {
                $detOk++; $fonte = 'details'
                $itens[$id] = $o
                if ($o['active'] -eq $false) { $detInativo++; $statusPorId[$id] = 'INATIVO'; Log "  detalhe ${id}: active=false (veio da busca, mas o site marca inativo)" }
            }
            else { $detVazio++; Log "  detalhe ${id}: resposta vazia ({}), mantendo os dados da busca" }
        }
        Remove-Item $arqTmp -ErrorAction SilentlyContinue
        $t = Trim $itens[$id]
        $t['_capturado_em'] = $capturadoEm; $t['_origem_busca'] = @($origem[$id]); $t['_detalhe_fonte'] = $fonte
        [System.IO.File]::WriteAllText((Join-Path $pastaJson "$id.json"), (ConvertTo-Json $t -Depth 12), $utf8sem)
        if ($k % 50 -eq 0) { Log ("  {0}/{1} detalhes ({2:n0} s)" -f $k, $aceitos.Count, $tDet.Elapsed.TotalSeconds) }
        Start-Sleep -Milliseconds 500
    }
}
else {
    Log '--- 3) Detalhes: pulado (-SemDetalhes); gravando o item da busca ---'
    foreach ($id in $aceitos) {
        $t = Trim $itens[$id]
        $t['_capturado_em'] = $capturadoEm; $t['_origem_busca'] = @($origem[$id]); $t['_detalhe_fonte'] = 'busca'
        [System.IO.File]::WriteAllText((Join-Path $pastaJson "$id.json"), (ConvertTo-Json $t -Depth 12), $utf8sem)
    }
}
$tDet.Stop()
Log ("Detalhes: ok=$detOk vazio=$detVazio falha=$detFalha inativos=$detInativo em {0:n0} s" -f $tDet.Elapsed.TotalSeconds)

# ------------------------------------------------------------------ 4) conferência de páginas HTML (amostra)
if ($ConferirPaginas -gt 0 -and $aceitos.Count -gt 0) {
    Log "--- 4) Conferência de $ConferirPaginas página(s) HTML de anúncio ---"
    $amostra = @($aceitos | Select-Object -First $ConferirPaginas)
    foreach ($id in $amostra) {
        $it = $itens[$id]
        $url = Txt $it['url']; if (-not $url) { continue }
        $arqHtml = Join-Path $pastaLotes "pagina-$id.html"
        $code = Baixar ($siteBase + $url) $arqHtml -SeguirRedirect
        if ($code -ne '200') { Log "  página $id http=$code"; continue }
        $h = [System.IO.File]::ReadAllText($arqHtml) -replace '\\"', '"'
        # "Ops! Esta página não existe" aparece em TODA página (componente not-found pré-renderizado no shell do Next.js);
        # só o digest NEXT_HTTP_ERROR_FALLBACK;404 marca 404 de verdade. O título de anúncio válido termina com "ID: <id> | Chaves na Mão".
        $r = [ordered]@{ id = $id; url = ($siteBase + $url); http = $code; tamanho = $h.Length; titulo = ''; pagina_nao_existe = $h.Contains('NEXT_HTTP_ERROR_FALLBACK;404'); titulo_com_id = $false;
            datePublished = ''; dateModified = ''; rotulo_condominio = ''; rotulo_iptu = ''; active_true = ([regex]::Matches($h, '"active":true')).Count; active_false = ([regex]::Matches($h, '"active":false')).Count;
            api_updatedAt = (Txt $it['updatedAt']); api_createdAt = (Txt $it['createdAt']); api_condominiumFee = ''; api_iptuValue = '' }
        if ((EhDic $it['prices'])) { $r.api_condominiumFee = Txt $it['prices']['condominiumFee']; $r.api_iptuValue = Txt $it['prices']['iptuValue'] }
        if ($h -match '<title>(.*?)</title>') { $r.titulo = $matches[1]; $r.titulo_com_id = ($r.titulo -match ('ID: ' + $id + '\b')) }
        if ($h -match '"datePublished":"([^"]+)"') { $r.datePublished = $matches[1] }
        if ($h -match '"dateModified":"([^"]+)"') { $r.dateModified = $matches[1] }
        if ($h -match '>Condom[ií]nio</p><p[^>]*>([^<]+)</p>') { $r.rotulo_condominio = $matches[1] }
        if ($h -match '>IPTU</p><p[^>]*>([^<]+)</p>') { $r.rotulo_iptu = $matches[1] }
        [System.IO.File]::WriteAllText((Join-Path $pastaJson "pagina-$id.json"), (ConvertTo-Json $r -Depth 4), $utf8sem)
        Remove-Item $arqHtml -ErrorAction SilentlyContinue
        Log ("  página {0}: dateModified={1} (API updatedAt={2}) | Condomínio='{3}' (API '{4}') | IPTU='{5}' (API '{6}') | active true={7} false={8} | 404={9} | título com o id={10}" -f $id, $r.dateModified, $r.api_updatedAt, $r.rotulo_condominio, $r.api_condominiumFee, $r.rotulo_iptu, $r.api_iptuValue, $r.active_true, $r.active_false, $r.pagina_nao_existe, $r.titulo_com_id)
        Start-Sleep -Milliseconds 500
    }
}

# ------------------------------------------------------------------ 5) CSV
Log '--- 5) CSV ---'
$coordTrocadas = 0
$linhas = New-Object System.Collections.Generic.List[object]
foreach ($id in ($aceitos | Sort-Object { [long]$_ })) {
    $status = if ($statusPorId.ContainsKey($id)) { $statusPorId[$id] } else { 'ATIVO' }
    $linhas.Add((MontarLinha $itens[$id] $capturadoEm $status "json/chavesnamao/$id.json"))
}
if ($linhas.Count -gt 0) {
    $linhas | Select-Object -Property $colunas | Export-Csv -Path $arqCsv -Delimiter ';' -NoTypeInformation -Encoding UTF8
}
else {
    [System.IO.File]::WriteAllText($arqCsv, ('"' + ($colunas -join '";"') + '"' + "`r`n"), $utf8bom)
}
$bytes = [System.IO.File]::ReadAllBytes($arqCsv)
if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
    $txt = [System.IO.File]::ReadAllText($arqCsv, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($arqCsv, $txt, $utf8bom)
    Log '  BOM UTF-8 acrescentado ao CSV'
}

# ------------------------------------------------------------------ 6) resumo
$comNumero = @($linhas | Where-Object { $_.numero }).Count
$comCoord = @($linhas | Where-Object { $_.lat }).Count
$prec = ($linhas | Group-Object precisao_coord | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ', '
$iptuBases = ($linhas | ForEach-Object { if ($_.iptu_informado -match '/(ano|mês) \(([^)]+)\)') { $matches[1] + ' (' + $matches[2] + ')' } else { 'sem IPTU' } } | Group-Object | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Count }) -join ', '
$tipos = ($linhas | Group-Object tipo | Sort-Object Count -Descending | ForEach-Object { $_.Name + '=' + $_.Count }) -join ', '
$bairros = ($linhas | Group-Object bairro_site | Sort-Object Count -Descending | ForEach-Object { $_.Name + '=' + $_.Count }) -join ', '
Log '--- Resumo ---'
foreach ($m in $resumoEscopos) { Log ("  " + $m) }
Log ("  Únicos na busca: {0} | aceitos (critérios): {1} | linhas no CSV: {2}" -f $itens.Count, $aceitos.Count, $linhas.Count)
Log ("  Tipos: $tipos")
Log ("  Bairros (site): $bairros")
Log ("  Com número: $comNumero | com coordenada: $comCoord | precisão: $prec | lat/lon trocados corrigidos: $coordTrocadas")
Log ("  IPTU: $iptuBases (limite mensal = R$ $iptuLimiteMensal)")
Log ("  Falhas de rede após 3 tentativas: $falhas | escopos com cobertura truncada: $incompletos")
Log ("  Tempo total: {0:n0} s (busca {1:n0} s, detalhes {2:n0} s)" -f $relogio.Elapsed.TotalSeconds, $tBusca.Elapsed.TotalSeconds, $tDet.Elapsed.TotalSeconds)
Log ("  CSV: $arqCsv")
if ($falhas -gt 0 -or $incompletos -gt 0) { Log "RESULTADO: INCOMPLETO (exit 2) — falhas de rede=$falhas, cobertura truncada=$incompletos"; exit 2 }
Log 'RESULTADO: COMPLETO (exit 0)'
exit 0
