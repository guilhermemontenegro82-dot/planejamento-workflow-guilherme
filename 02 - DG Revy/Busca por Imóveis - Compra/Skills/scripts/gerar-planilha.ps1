<#
gerar-planilha.ps1 — Gera a planilha "Apartamentos Pesquisados" (xlsx) a partir de base.csv, via Excel COM.

Uso:
  powershell -ExecutionPolicy Bypass -File gerar-planilha.ps1 -Base <base.csv> -Saida <xlsx> -Rodada yyyy-MM-dd
      [-Modelo <xlsx modelo>] [-ResumoRodada <json>] [-Criterios <criterios.json>] [-Ruas <ruas.csv>]
      [-Png <pasta>] [-Log <arquivo.log>]

O que faz:
  1. Lê base.csv (formato do CONTRATO-DADOS, seção "Base"); descarta dentro_area = NAO.
  2. Se o xlsx de saída já existir, lê da aba IMÓVEIS as colunas manuais do Guilherme (AVALIAÇÃO (SÓCIOS) e
     OBSERVAÇÕES) casando pela CHAVE, grava um backup manuais-backup-<rodada>.csv ao lado e preserva os valores.
     Também lê as linhas anteriores da aba HISTÓRICO.
  3. Lê a planilha modelo do Guilherme SÓ PARA LEITURA (confere nomes de coluna e o rótulo "Data atualização:").
  4. Gera as abas IMÓVEIS, RESUMO, HISTÓRICO e CRITÉRIOS escrevendo cada bloco por array 2D (nunca célula a célula).
  5. Salva como xlsx (FileFormat 51). Com -Png, exporta imagens de conferência das abas.

Saída: exit 0 se completou; exit 1 em erro. Log em -Log (padrão: <pasta do xlsx>\gerar-planilha.log).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Base,
  [Parameter(Mandatory = $true)][string]$Saida,
  [Parameter(Mandatory = $true)][string]$Rodada,
  [string]$Modelo,
  [string]$ResumoRodada,
  [string]$Criterios,
  [string]$Ruas,
  [string]$Png,
  [string]$Log
)

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$relogio = [System.Diagnostics.Stopwatch]::StartNew()

# ---------------------------------------------------------------- caminhos padrão
$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent     # scripts -> Skills -> raiz do projeto
if (-not $Modelo)    { $Modelo = Join-Path $raiz 'Planilha de Apartamentos Pesquisados\Planilha modelo para preenchimento.xlsx' }
if (-not $Criterios) { $Criterios = Join-Path $raiz 'Sites e critérios para Busca\criterios.json' }
if (-not $Ruas)      { $Ruas = Join-Path $raiz 'Listagem das ruas\ruas.csv' }
$pastaSaida = Split-Path -Parent ([System.IO.Path]::GetFullPath($Saida))
if (-not (Test-Path $pastaSaida)) { New-Item -ItemType Directory -Force $pastaSaida | Out-Null }
if (-not $Log) { $Log = Join-Path $pastaSaida 'gerar-planilha.log' }
$Saida = [System.IO.Path]::GetFullPath($Saida)

# ---------------------------------------------------------------- utilitários
$script:LogLinhas = New-Object System.Collections.Generic.List[string]
function Escrever-Log([string]$msg) {
  $linha = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
  $script:LogLinhas.Add($linha); Write-Host $linha
}
function Salvar-Log { [System.IO.File]::WriteAllLines($Log, $script:LogLinhas, (New-Object System.Text.UTF8Encoding($true))) }

function ColLetra([int]$n) { $s = ''; while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [int](($n - $m - 1) / 26) }; return $s }
function Cor([int]$r, [int]$g, [int]$b) { return $r + $g * 256 + $b * 65536 }
function SetV($rng, $v) {   # Value2 via InvokeMember (o setter cacheado como String quebra números) — aceita escalar ou array 2D
  $arg = New-Object object[] 1; $arg[0] = $v
  try {
    $rng.GetType().InvokeMember('Value2', 'SetProperty', $null, $rng, $arg) | Out-Null
  } catch {
    # diagnóstico: endereço e tipos dos valores (COM rejeita PSObject, Int64 em alguns casos, etc.)
    $tipos = ''
    if ($v -is [System.Array] -and $v.Rank -eq 2) {
      $vistos = @{}
      for ($i = $v.GetLowerBound(0); $i -le $v.GetUpperBound(0); $i++) { for ($j = $v.GetLowerBound(1); $j -le $v.GetUpperBound(1); $j++) { $e = $v[$i, $j]; $tn = if ($null -eq $e) { 'null' } else { $e.GetType().Name }; $vistos[$tn] = 1 } }
      $tipos = "array $($v.GetLength(0))x$($v.GetLength(1)) com tipos: $($vistos.Keys -join ', ')"
    } elseif ($null -ne $v) { $tipos = "escalar $($v.GetType().FullName)" } else { $tipos = 'null' }
    throw "SetV falhou em $($rng.Address($false, $false)) — $tipos — $($_.Exception.InnerException.Message)"
  }
}
function SetF($rng, $v) {   # idem para Formula
  $arg = New-Object object[] 1; $arg[0] = $v
  $rng.GetType().InvokeMember('Formula', 'SetProperty', $null, $rng, $arg) | Out-Null
}
function ToNum($s) {        # número vindo do CSV (ponto decimal, cultura invariante); vazio -> $null
  if ($null -eq $s) { return $null }; $t = "$s".Trim(); if ($t -eq '') { return $null }
  $d = 0.0
  if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return $d }
  return $null
}
function ToData($s) {       # data ISO (yyyy-MM-dd ou yyyy-MM-dd HH:mm) -> [datetime]; vazio -> $null
  if ($null -eq $s) { return $null }; $t = "$s".Trim(); if ($t.Length -lt 10) { return $null }
  $d = [datetime]::MinValue
  if ([datetime]::TryParseExact($t.Substring(0, 10), 'yyyy-MM-dd', $inv, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
  return $null
}
function OA($dt) { if ($null -eq $dt) { return $null }; return ([datetime]$dt).ToOADate() }
function Vazio($s) { return ($null -eq $s -or "$s".Trim() -eq '') }
function Mediana($valores) {
  $v = @($valores | Where-Object { $null -ne $_ } | Sort-Object); $n = $v.Count
  if ($n -eq 0) { return $null }
  if ($n % 2 -eq 1) { return [double]$v[[int](($n - 1) / 2)] }
  return ([double]$v[[int]($n / 2) - 1] + [double]$v[[int]($n / 2)]) / 2
}
function Hyper([string]$url, [string]$texto) {   # fórmula =HYPERLINK (nome em inglês: .Formula é sempre en-US)
  if (Vazio $url) { return '' }
  $u = $url -replace '"', '""'; $t = $texto -replace '"', '""'
  return "=HYPERLINK(""$u"",""$t"")"
}
function TextoLink([string]$url, [string]$codigo) {   # texto curto e clicável: host › código
  if (Vazio $url) { return '' }
  try { $h = ([uri]$url).Host -replace '^www\.', '' } catch { $h = 'link' }
  if (Vazio $codigo) { return $h }
  return "$h › $codigo"
}
# ATENÇÃO: função que devolve array 2D precisa de "return ,$arr" — sem a vírgula o PowerShell desenrola o array
# na saída e o chamador recebe uma lista plana (os índices [i, j] passam a selecionar 2 elementos e tudo sai vazio).
function Novo2D([int]$linhas, [int]$colunas) { $a = [System.Array]::CreateInstance([object], $linhas, $colunas); return ,$a }
# Valor vindo de pipeline (Sort-Object, Select-Object, Where-Object) chega embrulhado em PSObject; o COM não serializa
# isso e falha com 0x800A03EC sem dizer por quê. Desembrulhar tudo que entra num array 2D.
function Bruto($e) {
  if ($null -eq $e) { return $null }
  if ($e -is [System.Management.Automation.PSObject]) { $e = $e.PSObject.BaseObject }
  if ($e -is [System.Management.Automation.PSObject]) { $e = $e.BaseObject }
  return $e
}

# Lê um Range.Value2 e devolve sempre um array 2D com base 1 (COM) — cuida do caso de 1 célula
function Ler2D($rng) {
  $v = $rng.Value2
  if ($v -is [System.Array]) { return ,$v }
  $a = [System.Array]::CreateInstance([object], @(1, 1), @(1, 1)); $a[1, 1] = $v; return ,$a
}

# Escreve um bloco (título + cabeçalho + dados) numa aba a partir da linha $linha, coluna 1. Devolve a próxima linha livre.
# $fmt: por coluna: '@' texto, 'int', 'R$', 'R$2', 'data', 'link' (valor = URL; vira =HYPERLINK), 'num'
function Escrever-Bloco($ws, [int]$linha, [string]$titulo, [string[]]$cab, $dados, [string[]]$fmt, [string]$nota = '') {
  $dados = @($dados); $nc = $cab.Count; $nd = $dados.Count
  $ultCol = ColLetra $nc
  $t = $ws.Range("A${linha}"); SetV $t $titulo; $t.Font.Bold = $true; $t.Font.Size = 12; $t.Font.Color = (Cor 31 56 100)
  if ($nota) { $n = $ws.Range("B${linha}"); SetV $n $nota; $n.Font.Italic = $true; $n.Font.Color = (Cor 110 110 110); $n.Font.Size = 9 }
  $lc = $linha + 1
  $hdr = Novo2D 1 $nc; for ($j = 0; $j -lt $nc; $j++) { $hdr[0, $j] = (Bruto $cab[$j]) }
  $h = $ws.Range("A${lc}:${ultCol}${lc}"); SetV $h $hdr
  $h.Font.Bold = $true; $h.Font.Color = 16777215; $h.Interior.Color = (Cor 31 56 100); $h.HorizontalAlignment = -4108; $h.VerticalAlignment = -4108; $h.WrapText = $true
  $ws.Rows.Item($lc).RowHeight = 30
  if ($nd -gt 0) {
    $l1 = $lc + 1; $l2 = $lc + $nd
    # formatos por coluna ANTES de escrever
    for ($j = 0; $j -lt $nc; $j++) {
      $cl = ColLetra ($j + 1); $r = $ws.Range("${cl}${l1}:${cl}${l2}")
      switch ($fmt[$j]) {
        '@'    { $r.NumberFormatLocal = '@'; $r.HorizontalAlignment = -4131 }
        'int'  { $r.NumberFormatLocal = '0'; $r.HorizontalAlignment = -4108 }
        'num'  { $r.NumberFormatLocal = '#.##0,0'; $r.HorizontalAlignment = -4152 }
        'R$'   { $r.NumberFormatLocal = '"R$" #.##0'; $r.HorizontalAlignment = -4152 }
        'R$2'  { $r.NumberFormatLocal = '"R$" #.##0,00'; $r.HorizontalAlignment = -4152 }
        'data' { $r.NumberFormatLocal = 'dd/mm/aaaa'; $r.HorizontalAlignment = -4108 }
        'link' { $r.Font.Color = (Cor 5 99 193); $r.Font.Underline = 2; $r.HorizontalAlignment = -4131 }
        'g'    { $r.NumberFormatLocal = 'Geral'; $r.HorizontalAlignment = -4131 }   # número fica número, texto fica texto
      }
    }
    $arr = Novo2D $nd $nc
    for ($i = 0; $i -lt $nd; $i++) { $lin = $dados[$i]; for ($j = 0; $j -lt $nc; $j++) { if ($fmt[$j] -eq 'link') { $arr[$i, $j] = '' } else { $arr[$i, $j] = (Bruto $lin[$j]) } } }
    $rd = $ws.Range("A${l1}:${ultCol}${l2}"); SetV $rd $arr
    for ($j = 0; $j -lt $nc; $j++) {
      if ($fmt[$j] -eq 'link') {
        $cl = ColLetra ($j + 1); $fa = Novo2D $nd 1
        for ($i = 0; $i -lt $nd; $i++) { $u = "$($dados[$i][$j])"; $fa[$i, 0] = (Hyper $u (TextoLink $u '')) }
        SetF $ws.Range("${cl}${l1}:${cl}${l2}") $fa
      }
    }
    $tudo = $ws.Range("A${lc}:${ultCol}${l2}")
    $tudo.Borders.LineStyle = 1; $tudo.Borders.Weight = 2; $tudo.Borders.Color = (Cor 191 191 191)
    $rd.VerticalAlignment = -4108
    return $l2 + 2
  } else {
    $v = $ws.Range("A$($lc + 1)"); SetV $v '(nenhum)'; $v.Font.Italic = $true; $v.Font.Color = (Cor 128 128 128)
    return $lc + 3
  }
}

function Liberar($obj) { if ($null -ne $obj) { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) } catch {} } }

# Espera o arquivo ficar livre para escrita (Excel anterior ainda fechando, antivírus escaneando o xlsx recém-gravado,
# ou a planilha aberta pelo Guilherme). Devolve $true se liberou dentro do prazo.
function Esperar-Liberacao([string]$caminho, [int]$segundos = 20) {
  if (-not (Test-Path $caminho)) { return $true }
  $fim = (Get-Date).AddSeconds($segundos); $esperou = $false
  while ($true) {
    try { $fs = [System.IO.File]::Open($caminho, 'Open', 'ReadWrite', 'None'); $fs.Close(); if ($esperou) { Escrever-Log "Arquivo liberado: $caminho" }; return $true }
    catch { if ((Get-Date) -gt $fim) { return $false }; $esperou = $true; Start-Sleep -Milliseconds 500 }
  }
}

# ---------------------------------------------------------------- início
Escrever-Log "gerar-planilha.ps1 — rodada $Rodada"
Escrever-Log "Base: $Base"
Escrever-Log "Saída: $Saida"
$dataRodada = ToData $Rodada
if ($null -eq $dataRodada) { Escrever-Log "ERRO: -Rodada precisa estar em yyyy-MM-dd (recebi '$Rodada')."; Salvar-Log; exit 1 }
if (-not (Test-Path $Base)) { Escrever-Log "ERRO: base não encontrada: $Base"; Salvar-Log; exit 1 }

# ---------------------------------------------------------------- 1. ler a base
$baseLinhas = @(Import-Csv -Path $Base -Delimiter ';' -Encoding UTF8)
Escrever-Log ("Base lida: {0} linhas, {1} colunas" -f $baseLinhas.Count, @($baseLinhas[0].PSObject.Properties).Count)
$obrigatorias = @('chave','fonte','codigo','link','link_alt','tipo','titulo','rua','numero','cep','bairro_site','preco','area_util',
  'condominio_mes','iptu_mes','quartos','banheiros','vagas','andar','anunciante','tipo_anunciante','publicado_em','atualizado_em',
  'destaques','descricao_resumo','dentro_area','poligono','duplicata_grupo','status','primeira_captura','ultima_verificacao',
  'removido_em','preco_anterior','preco_alterado_em','avaliacao_socios','observacoes')
$presentes = @($baseLinhas[0].PSObject.Properties | ForEach-Object { $_.Name })
$faltam = @($obrigatorias | Where-Object { $presentes -notcontains $_ })
if ($faltam.Count -gt 0) { Escrever-Log "ERRO: faltam colunas na base: $($faltam -join ', ')"; Salvar-Log; exit 1 }

$descartadasNao = @($baseLinhas | Where-Object { "$($_.dentro_area)".Trim().ToUpper() -eq 'NAO' }).Count
$baseLinhas = @($baseLinhas | Where-Object { "$($_.dentro_area)".Trim().ToUpper() -ne 'NAO' })
Escrever-Log "Descartadas por dentro_area = NAO: $descartadasNao. Vão para a planilha: $($baseLinhas.Count)"

# ---------------------------------------------------------------- Excel
$app = $null; $wbAnt = $null; $wbMod = $null; $wb = $null
$manuais = @{}            # chave -> @{ Avaliacao; Observacoes }
$historicoAnterior = @()  # linhas da aba HISTÓRICO (hashtable por nome de coluna)
$rotuloData = 'Data atualização:'; $cabMod = @()
$codigoSaida = 0
try {
  $app = New-Object -ComObject Excel.Application
  $app.Visible = $false; $app.DisplayAlerts = $false; $app.ScreenUpdating = $false

  # -------------------------------------------------------------- 2. ler o xlsx existente (colunas manuais + histórico)
  if (Test-Path $Saida) {
    Escrever-Log "Planilha existente encontrada: lendo colunas manuais e HISTÓRICO."
    if (-not (Esperar-Liberacao $Saida 20)) { throw "A planilha está em uso por outro programa (aberta no Excel?). Feche-a e rode de novo: $Saida" }
    $wbAnt = $app.Workbooks.Open($Saida, 0, $true)
    $wsAnt = $null
    foreach ($s in $wbAnt.Worksheets) { if ($s.Name -eq 'IMÓVEIS') { $wsAnt = $s } }
    if ($null -ne $wsAnt) {
      $hdr = Ler2D $wsAnt.Range('A4:BZ4')
      $iChave = 0; $iAval = 0; $iObs = 0
      for ($j = 1; $j -le $hdr.GetUpperBound(1); $j++) {
        $nome = "$($hdr[1, $j])".Trim()
        if ($nome -eq 'CHAVE') { $iChave = $j }
        if ($nome -eq 'AVALIAÇÃO (SÓCIOS)') { $iAval = $j }
        if ($nome -eq 'OBSERVAÇÕES') { $iObs = $j }
      }
      if ($iChave -gt 0 -and ($iAval -gt 0 -or $iObs -gt 0)) {
        $ult = $wsAnt.Cells.Item($wsAnt.Rows.Count, $iChave).End(-4162).Row
        if ($ult -ge 5) {
          $maxCol = [math]::Max($iChave, [math]::Max($iAval, $iObs))
          $dadosAnt = Ler2D $wsAnt.Range("A5:$(ColLetra $maxCol)$ult")
          for ($i = 1; $i -le $dadosAnt.GetUpperBound(0); $i++) {
            $ch = "$($dadosAnt[$i, $iChave])".Trim()
            if ($ch -eq '') { continue }
            $av = if ($iAval -gt 0) { "$($dadosAnt[$i, $iAval])" } else { '' }
            $ob = if ($iObs -gt 0) { "$($dadosAnt[$i, $iObs])" } else { '' }
            $manuais[$ch] = @{ Avaliacao = $av; Observacoes = $ob }
          }
        }
        $comValor = @($manuais.Keys | Where-Object { -not (Vazio $manuais[$_].Avaliacao) -or -not (Vazio $manuais[$_].Observacoes) })
        Escrever-Log ("Colunas manuais lidas: {0} chaves, {1} com algum valor preenchido." -f $manuais.Count, $comValor.Count)
        $bk = Join-Path $pastaSaida "manuais-backup-$Rodada.csv"
        $bkLinhas = foreach ($k in ($comValor | Sort-Object)) { [pscustomobject]@{ chave = $k; avaliacao_socios = $manuais[$k].Avaliacao; observacoes = $manuais[$k].Observacoes } }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('chave;avaliacao_socios;observacoes')
        foreach ($l in @($bkLinhas)) { [void]$sb.AppendLine(('"{0}";"{1}";"{2}"' -f ($l.chave -replace '"','""'), ($l.avaliacao_socios -replace '"','""'), ($l.observacoes -replace '"','""'))) }
        [System.IO.File]::WriteAllText($bk, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
        Escrever-Log "Backup das colunas manuais: $bk ($(@($bkLinhas).Count) linhas)"
      } else {
        Escrever-Log "AVISO: aba IMÓVEIS existente sem coluna CHAVE/AVALIAÇÃO/OBSERVAÇÕES na linha 4 — nada preservado."
      }
    } else { Escrever-Log "AVISO: a planilha existente não tem aba IMÓVEIS." }
    $wsHist = $null
    foreach ($s in $wbAnt.Worksheets) { if ($s.Name -like 'HISTÓRICO*') { $wsHist = $s } }
    if ($null -ne $wsHist) {
      $hh = Ler2D $wsHist.Range('A4:Z4')
      $nomes = @{}
      for ($j = 1; $j -le $hh.GetUpperBound(1); $j++) { $nm = "$($hh[1, $j])".Trim(); if ($nm) { $nomes[$nm] = $j } }
      if ($nomes.ContainsKey('DATA DA RODADA')) {
        $ultH = $wsHist.Cells.Item($wsHist.Rows.Count, $nomes['DATA DA RODADA']).End(-4162).Row
        if ($ultH -ge 5) {
          $dh = Ler2D $wsHist.Range("A5:Z$ultH")
          for ($i = 1; $i -le $dh.GetUpperBound(0); $i++) {
            $reg = @{}
            foreach ($nm in $nomes.Keys) { $reg[$nm] = $dh[$i, $nomes[$nm]] }
            if ($null -ne $reg['DATA DA RODADA'] -and "$($reg['DATA DA RODADA'])" -ne '') { $historicoAnterior += ,$reg }
          }
        }
      }
      Escrever-Log "HISTÓRICO anterior: $($historicoAnterior.Count) rodadas."
    }
    $wbAnt.Close($false); Liberar $wbAnt; $wbAnt = $null
  } else {
    Escrever-Log "Planilha de saída ainda não existe: primeira geração."
  }

  # -------------------------------------------------------------- 3. modelo do Guilherme (só leitura)
  if (Test-Path $Modelo) {
    try {
      $wbMod = $app.Workbooks.Open($Modelo, 0, $true)
      $wsMod = $wbMod.Worksheets.Item(1)
      $m = Ler2D $wsMod.Range('A1:L5')
      $rot = ''
      for ($j = 1; $j -le 12; $j++) { if ("$($m[2, $j])" -match 'atualiza') { $rot = "$($m[2, $j])".Trim() } }
      if ($rot) { $rotuloData = $rot }
      $cabMod = @(); for ($j = 1; $j -le 12; $j++) { $v = "$($m[4, $j])".Trim(); if ($v) { $cabMod += $v } }
      Escrever-Log "Modelo lido (só leitura): rótulo '$rotuloData'; colunas do Guilherme: $($cabMod -join ' | ')"
      $wbMod.Close($false); Liberar $wbMod; $wbMod = $null
    } catch { Escrever-Log "AVISO: não consegui ler o modelo ($($_.Exception.Message)); sigo com o padrão." }
  } else { $cabMod = @(); Escrever-Log "AVISO: modelo não encontrado em $Modelo (sigo com o padrão)." }

  # -------------------------------------------------------------- 4. montar as linhas
  $mapaFonte = @{ 'VIVAREAL' = 'VivaReal/Zap'; 'QUINTOANDAR' = 'QuintoAndar'; 'CHAVESNAMAO' = 'Chaves na Mão' }
  $ordemStatus = @{ 'ATIVO' = 0; 'FORA DOS CRITÉRIOS' = 1; 'REMOVIDO' = 2 }
  function Bairro-Exibicao($r) {
    # Preferência: coluna "bairro" do consolidador (Ipanema | Ipanema/Arpoador | Leblon | bairro do site).
    $bc = ''; if ($r.PSObject.Properties['bairro']) { $bc = "$($r.bairro)".Trim() }
    if ($bc -match '(?i)^ipanema\s*/\s*arpoador') { return 'Arpoador (Copacabana)' }
    if ($bc -match '(?i)^ipanema') { return 'Ipanema' }
    if ($bc -match '(?i)^leblon') { return 'Leblon' }
    $b = $bc; if ($b -eq '') { $b = "$($r.bairro_site)".Trim() }; if ($b -eq '') { $b = "$($r.poligono)".Trim() }
    if ($b -match '(?i)copacabana|arpoador') { return 'Arpoador (Copacabana)' }
    if ($b -match '(?i)^ipanema') { return 'Ipanema' }
    if ($b -match '(?i)^leblon') { return 'Leblon' }
    if ($b -eq '') { return '(não informado)' }
    return $b
  }
  $ordemBairro = @{ 'Ipanema' = 0; 'Leblon' = 1; 'Arpoador (Copacabana)' = 2 }

  $itens = foreach ($r in $baseLinhas) {
    $chave = "$($r.chave)".Trim()
    $preco = ToNum $r.preco; $area = ToNum $r.area_util
    $m2 = if ($null -ne $preco -and $null -ne $area -and $area -gt 0) { $preco / $area } else { $null }
    $status = "$($r.status)".Trim().ToUpper(); if (-not $ordemStatus.ContainsKey($status)) { $status = 'ATIVO' }
    $primeira = ToData $r.primeira_captura
    $novo = ($status -eq 'ATIVO' -and $null -ne $primeira -and $primeira.Date -eq $dataRodada.Date)
    $rua = "$($r.rua)".Trim(); $num = "$($r.numero)".Trim()
    $end = if ($rua -eq '') { '(endereço não informado)' } elseif ($num -eq '') { "$rua, s/nº" } else { "$rua, $num" }
    $fonte = "$($r.fonte)".Trim().ToUpper()
    $local = if ($mapaFonte.ContainsKey($fonte)) { $mapaFonte[$fonte] } else { $fonte }
    $anun = "$($r.anunciante)".Trim(); $tipoAn = "$($r.tipo_anunciante)".Trim()
    if ($anun -eq '' -and $tipoAn -ne '') { $anun = $tipoAn } elseif ($anun -ne '' -and $tipoAn -eq 'Particular') { $anun = "$anun (particular)" }
    $dataAnuncio = ToData $r.atualizado_em; if ($null -eq $dataAnuncio) { $dataAnuncio = ToData $r.publicado_em }
    $precoAnt = ToNum $r.preco_anterior
    $mudanca = if ($null -ne $precoAnt -and $null -ne $preco) { if ($preco -lt $precoAnt) { 'caiu' } elseif ($preco -gt $precoAnt) { 'subiu' } else { '' } } else { '' }
    $aval = "$($r.avaliacao_socios)"; $obs = "$($r.observacoes)"
    if ($manuais.ContainsKey($chave)) {
      if (-not (Vazio $manuais[$chave].Avaliacao)) { $aval = $manuais[$chave].Avaliacao }
      if (-not (Vazio $manuais[$chave].Observacoes)) { $obs = $manuais[$chave].Observacoes }
    }
    $bairro = Bairro-Exibicao $r
    [pscustomobject]@{
      Chave = $chave; Fonte = $fonte; Codigo = "$($r.codigo)".Trim(); Status = $status; Novo = $novo
      StatusExib = $(if ($novo) { 'NOVO' } else { $status })
      Area = "$($r.dentro_area)".Trim().ToUpper(); Local = $local; Bairro = $bairro; Endereco = $end; Cep = "$($r.cep)".Trim()
      Tipo = "$($r.tipo)".Trim(); Preco = $preco; AreaUtil = $area; M2 = $m2
      Cond = ToNum $r.condominio_mes; Iptu = ToNum $r.iptu_mes
      Quartos = ToNum $r.quartos; Banheiros = ToNum $r.banheiros; Vagas = ToNum $r.vagas; Andar = "$($r.andar)".Trim()
      Destaques = ("$($r.destaques)".Trim() -replace '\s*\|\s*', ', '); Anunciante = $anun
      DataAnuncio = $dataAnuncio; Primeira = $primeira; Ultima = ToData $r.ultima_verificacao
      PrecoAnt = $precoAnt; PrecoAltEm = ToData $r.preco_alterado_em; RemovidoEm = ToData $r.removido_em; Mudanca = $mudanca
      DupGrupo = "$($r.duplicata_grupo)".Trim(); Avaliacao = $aval; Observacoes = $obs
      Link = "$($r.link)".Trim(); LinkZap = "$($r.link_alt)".Trim(); Descricao = ("$($r.descricao_resumo)" -replace '[\r\n]+', ' ').Trim()
      Titulo = "$($r.titulo)".Trim()
      OrdStatus = $ordemStatus[$status]
      OrdBairro = $(if ($ordemBairro.ContainsKey($bairro)) { $ordemBairro[$bairro] } else { 9 })
      OrdM2 = $(if ($null -ne $m2) { $m2 } else { [double]::MaxValue })
    }
  }
  $itens = @($itens | Sort-Object OrdStatus, OrdBairro, OrdM2, Chave)
  $n = $itens.Count
  for ($i = 0; $i -lt $n; $i++) { $itens[$i] | Add-Member -NotePropertyName Num -NotePropertyValue ($i + 1) -Force }
  # duplicatas: lista os Nº dos outros anúncios do mesmo grupo
  $grupos = @{}
  foreach ($it in $itens) { if ($it.DupGrupo) { if (-not $grupos.ContainsKey($it.DupGrupo)) { $grupos[$it.DupGrupo] = @() }; $grupos[$it.DupGrupo] += $it.Num } }
  foreach ($it in $itens) {
    $txt = ''
    if ($it.DupGrupo -and $grupos.ContainsKey($it.DupGrupo)) { $outros = @($grupos[$it.DupGrupo] | Where-Object { $_ -ne $it.Num }); if ($outros.Count -gt 0) { $txt = 'ver nº ' + (($outros | Sort-Object) -join ', ') } }
    $it | Add-Member -NotePropertyName DupTexto -NotePropertyValue $txt -Force
  }
  $cont = @{ Ativo = @($itens | Where-Object Status -eq 'ATIVO').Count; Fora = @($itens | Where-Object Status -eq 'FORA DOS CRITÉRIOS').Count; Removido = @($itens | Where-Object Status -eq 'REMOVIDO').Count; Novos = @($itens | Where-Object Novo).Count }
  Escrever-Log ("Linhas montadas: {0} (ATIVO {1}, dos quais NOVOS {2}; FORA DOS CRITÉRIOS {3}; REMOVIDO {4})" -f $n, $cont.Ativo, $cont.Novos, $cont.Fora, $cont.Removido)

  # -------------------------------------------------------------- 5. novo workbook
  $app.SheetsInNewWorkbook = 4
  $wb = $app.Workbooks.Add()
  $wsI = $wb.Worksheets.Item(1); $wsI.Name = 'IMÓVEIS'
  $wsR = $wb.Worksheets.Item(2); $wsR.Name = 'RESUMO'
  $wsH = $wb.Worksheets.Item(3); $wsH.Name = 'HISTÓRICO RODADAS'   # "Histórico" sozinho é nome reservado no Excel pt-BR
  $wsC = $wb.Worksheets.Item(4); $wsC.Name = 'CRITÉRIOS'

  # ============================================================== ABA IMÓVEIS
  # Definição das colunas: n = nome, w = largura, f = formato, a = alinhamento (l/c/r)
  $COLS = @(
    @{ n = 'Nº';                               w = 5;  f = 'int';  a = 'c' },
    @{ n = 'STATUS';                           w = 11; f = '@';    a = 'c' },
    @{ n = 'ÁREA DE INTERESSE';                w = 13; f = '@';    a = 'c' },
    @{ n = 'LOCAL PESQUISA';                   w = 14; f = '@';    a = 'l' },
    @{ n = 'BAIRRO';                           w = 20; f = '@';    a = 'l' },
    @{ n = 'ENDEREÇO DO IMÓVEL';               w = 34; f = '@';    a = 'l' },
    @{ n = 'CEP';                              w = 10; f = '@';    a = 'c' },
    @{ n = 'TIPO';                             w = 13; f = '@';    a = 'l' },
    @{ n = 'PREÇO';                            w = 13; f = 'R$';   a = 'r' },
    @{ n = 'ÁREA (m²)';                        w = 8;  f = 'int';  a = 'c' },
    @{ n = 'VALOR/M²';                         w = 12; f = 'R$';   a = 'r' },
    @{ n = 'CONDOMÍNIO (R$/mês)';              w = 13; f = 'R$';   a = 'r' },
    @{ n = 'IPTU (R$/mês)';                    w = 11; f = 'R$';   a = 'r' },
    @{ n = 'CUSTO MENSAL';                     w = 12; f = 'R$';   a = 'r' },
    @{ n = 'QUARTOS';                          w = 9;  f = 'int';  a = 'c' },
    @{ n = 'BANHEIROS';                        w = 11; f = 'int';  a = 'c' },
    @{ n = 'VAGAS';                            w = 7;  f = 'int';  a = 'c' },
    @{ n = 'ANDAR';                            w = 7;  f = '@';    a = 'c' },
    @{ n = 'DESTAQUES';                        w = 46; f = '@';    a = 'l' },
    @{ n = 'ANUNCIANTE';                       w = 32; f = '@';    a = 'l' },
    @{ n = 'DATA DO ANÚNCIO';                  w = 11; f = 'data'; a = 'c' },
    @{ n = '1ª CAPTURA';                       w = 11; f = 'data'; a = 'c' },
    @{ n = 'ÚLTIMA VERIFICAÇÃO';               w = 13; f = 'data'; a = 'c' },
    @{ n = 'PREÇO ANTERIOR';                   w = 13; f = 'R$';   a = 'r' },
    @{ n = 'MUDANÇA DE PREÇO EM';              w = 12; f = 'data'; a = 'c' },
    @{ n = 'REMOVIDO EM';                      w = 11; f = 'data'; a = 'c' },
    @{ n = 'POSSÍVEL DUPLICATA';               w = 14; f = '@';    a = 'c' },
    @{ n = 'AVALIAÇÃO (SÓCIOS)';               w = 26; f = '@';    a = 'l' },
    @{ n = 'OBSERVAÇÕES';                      w = 40; f = '@';    a = 'l' },
    @{ n = 'LINK DE ACESSO DIRETO AO IMÓVEL';  w = 30; f = 'link'; a = 'l' },
    @{ n = 'LINK ZAP';                         w = 28; f = 'link'; a = 'l' },
    @{ n = 'CHAVE';                            w = 26; f = '@';    a = 'l' },
    @{ n = 'DESCRIÇÃO (resumo)';               w = 70; f = '@';    a = 'l' }
  )
  $NC = $COLS.Count; $ultColI = ColLetra $NC
  $iPRECO = 9; $iAREA = 10; $iM2 = 11; $iCOND = 12; $iIPTU = 13; $iCUSTO = 14; $iLINK = 30; $iZAP = 31
  $cPRECO = ColLetra $iPRECO; $cAREA = ColLetra $iAREA; $cCOND = ColLetra $iCOND; $cIPTU = ColLetra $iIPTU
  # conferência com as colunas do modelo (nomes dele preservados como prefixo)
  if ($cabMod.Count -gt 0) {
    $nomesNossos = @($COLS | ForEach-Object { $_.n })
    $semPar = @($cabMod | Where-Object { $nm = $_; -not ($nomesNossos | Where-Object { $_.StartsWith($nm) }) })
    if ($semPar.Count -gt 0) { Escrever-Log "AVISO: colunas do modelo sem correspondente: $($semPar -join ', ')" } else { Escrever-Log "Todas as $($cabMod.Count) colunas do modelo do Guilherme estão presentes." }
  }

  $L1 = 5; $L2 = $L1 + $n - 1; if ($n -eq 0) { $L2 = $L1 }
  $wsI.Activate()
  # título, data e legenda (linhas 1-3), como no modelo: rótulo e data na linha 2, cabeçalho na linha 4
  $c = $wsI.Range('A1'); SetV $c 'APARTAMENTOS PESQUISADOS — IPANEMA E LEBLON'; $c.Font.Bold = $true; $c.Font.Size = 14; $c.Font.Color = (Cor 31 56 100)
  $c = $wsI.Range('A2'); SetV $c $rotuloData; $c.Font.Bold = $true
  $c = $wsI.Range('D2'); $c.NumberFormatLocal = 'dd/mm/aaaa'; SetV $c (OA $dataRodada); $c.HorizontalAlignment = -4131; $c.Font.Bold = $true
  $c = $wsI.Range('F2'); SetV $c ("{0} imóveis: {1} ativos ({2} novos nesta rodada), {3} fora dos critérios, {4} removidos" -f $n, $cont.Ativo, $cont.Novos, $cont.Fora, $cont.Removido); $c.Font.Italic = $true; $c.Font.Color = (Cor 89 89 89)
  $c = $wsI.Range('F3'); SetV $c 'Legenda:'; $c.Font.Bold = $true; $c.HorizontalAlignment = -4152
  $c = $wsI.Range('G3'); SetV $c 'NOVO'; $c.Interior.Color = (Cor 198 239 206); $c.Font.Color = (Cor 0 97 0); $c.Font.Bold = $true; $c.HorizontalAlignment = -4108
  $c = $wsI.Range('H3:I3'); $c.Merge(); SetV $c 'LIMITE / A CONFIRMAR'; $c.Interior.Color = (Cor 255 235 156); $c.Font.Color = (Cor 156 101 0); $c.HorizontalAlignment = -4108
  $c = $wsI.Range('J3:K3'); $c.Merge(); SetV $c 'REMOVIDO'; $c.Interior.Color = (Cor 230 230 230); $c.Font.Color = (Cor 128 128 128); $c.HorizontalAlignment = -4108
  $c = $wsI.Range('L3'); SetV $c 'preço caiu'; $c.Font.Color = (Cor 0 128 0); $c.Font.Bold = $true; $c.HorizontalAlignment = -4108
  $c = $wsI.Range('M3:N3'); $c.Merge(); SetV $c 'preço subiu'; $c.Font.Color = (Cor 192 0 0); $c.Font.Bold = $true; $c.HorizontalAlignment = -4108
  $c = $wsI.Range('O3:R3'); $c.Merge(); SetV $c 'FORA DOS CRITÉRIOS'; $c.Interior.Color = (Cor 252 228 214); $c.Font.Color = (Cor 132 60 12); $c.HorizontalAlignment = -4108
  $wsI.Rows.Item(1).RowHeight = 22

  # cabeçalho (linha 4)
  $hdr = Novo2D 1 $NC; for ($j = 0; $j -lt $NC; $j++) { $hdr[0, $j] = $COLS[$j].n }
  $h = $wsI.Range("A4:${ultColI}4"); SetV $h $hdr
  $h.Font.Bold = $true; $h.Font.Color = 16777215; $h.Interior.Color = (Cor 31 56 100); $h.WrapText = $true
  $h.HorizontalAlignment = -4108; $h.VerticalAlignment = -4108
  $wsI.Rows.Item(4).RowHeight = 42

  # larguras e formatos por coluna (ANTES de escrever: texto como texto, datas como datas)
  for ($j = 0; $j -lt $NC; $j++) {
    $cl = ColLetra ($j + 1); $def = $COLS[$j]
    $wsI.Columns.Item($j + 1).ColumnWidth = $def.w
    $r = $wsI.Range("${cl}${L1}:${cl}${L2}")
    switch ($def.f) {
      '@'    { $r.NumberFormatLocal = '@' }
      'int'  { $r.NumberFormatLocal = '0' }
      'R$'   { $r.NumberFormatLocal = '"R$" #.##0' }
      'data' { $r.NumberFormatLocal = 'dd/mm/aaaa' }
      'link' { $r.Font.Color = (Cor 5 99 193); $r.Font.Underline = 2 }
    }
    $r.HorizontalAlignment = $(switch ($def.a) { 'c' { -4108 } 'r' { -4152 } default { -4131 } })
  }

  if ($n -gt 0) {
    # array 2D com todos os dados (fórmulas e links ficam vazios aqui e entram depois)
    $dados = Novo2D $n $NC
    for ($i = 0; $i -lt $n; $i++) {
      $it = $itens[$i]
      $dados[$i, 0]  = [double]$it.Num
      $dados[$i, 1]  = $it.StatusExib
      $dados[$i, 2]  = $it.Area
      $dados[$i, 3]  = $it.Local
      $dados[$i, 4]  = $it.Bairro
      $dados[$i, 5]  = $it.Endereco
      $dados[$i, 6]  = $it.Cep
      $dados[$i, 7]  = $it.Tipo
      $dados[$i, 8]  = $it.Preco
      $dados[$i, 9]  = $it.AreaUtil
      $dados[$i, 11] = $it.Cond
      $dados[$i, 12] = $it.Iptu
      $dados[$i, 14] = $it.Quartos
      $dados[$i, 15] = $it.Banheiros
      $dados[$i, 16] = $it.Vagas
      $dados[$i, 17] = $it.Andar
      $dados[$i, 18] = $it.Destaques
      $dados[$i, 19] = $it.Anunciante
      $dados[$i, 20] = OA $it.DataAnuncio
      $dados[$i, 21] = OA $it.Primeira
      $dados[$i, 22] = OA $it.Ultima
      $dados[$i, 23] = $it.PrecoAnt
      $dados[$i, 24] = OA $it.PrecoAltEm
      $dados[$i, 25] = OA $it.RemovidoEm
      $dados[$i, 26] = $it.DupTexto
      $dados[$i, 27] = $it.Avaliacao
      $dados[$i, 28] = $it.Observacoes
      $dados[$i, 31] = $it.Chave
      $dados[$i, 32] = $it.Descricao
    }
    for ($i = 0; $i -lt $n; $i++) { for ($j = 0; $j -lt $NC; $j++) { $dados[$i, $j] = (Bruto $dados[$i, $j]) } }
    $rd = $wsI.Range("A${L1}:${ultColI}${L2}"); SetV $rd $dados

    # fórmulas: VALOR/M² e CUSTO MENSAL (uma só atribuição; as referências relativas se ajustam linha a linha)
    $cM2 = ColLetra $iM2; $cCUSTO = ColLetra $iCUSTO
    SetF $wsI.Range("${cM2}${L1}:${cM2}${L2}") "=IF(AND(ISNUMBER(${cPRECO}${L1}),ISNUMBER(${cAREA}${L1}),${cAREA}${L1}>0),${cPRECO}${L1}/${cAREA}${L1},"""")"
    SetF $wsI.Range("${cCUSTO}${L1}:${cCUSTO}${L2}") "=IF(COUNT(${cCOND}${L1}:${cIPTU}${L1})=0,"""",SUM(${cCOND}${L1}:${cIPTU}${L1}))"
    # links clicáveis (=HYPERLINK com texto curto "site › código")
    $fl = Novo2D $n 1; $fz = Novo2D $n 1
    for ($i = 0; $i -lt $n; $i++) {
      $it = $itens[$i]
      $fl[$i, 0] = Hyper $it.Link (TextoLink $it.Link $it.Codigo)
      $fz[$i, 0] = Hyper $it.LinkZap (TextoLink $it.LinkZap $it.Codigo)
    }
    $cLINK = ColLetra $iLINK; $cZAP = ColLetra $iZAP
    SetF $wsI.Range("${cLINK}${L1}:${cLINK}${L2}") $fl
    SetF $wsI.Range("${cZAP}${L1}:${cZAP}${L2}") $fz

    # bordas e alinhamento vertical
    $rd.Borders.LineStyle = 1; $rd.Borders.Weight = 2; $rd.Borders.Color = (Cor 191 191 191)
    $rd.VerticalAlignment = -4108; $rd.WrapText = $false
    $wsI.Range("${L1}:${L2}").RowHeight = 16

    # faixas contíguas: FORA DOS CRITÉRIOS e REMOVIDO (a ordenação garante que ficam juntas no fim)
    $idxFora = @(); $idxRem = @()
    for ($i = 0; $i -lt $n; $i++) { if ($itens[$i].Status -eq 'FORA DOS CRITÉRIOS') { $idxFora += ($L1 + $i) }; if ($itens[$i].Status -eq 'REMOVIDO') { $idxRem += ($L1 + $i) } }
    if ($idxFora.Count -gt 0) {
      $rf = $wsI.Range("A$($idxFora[0]):${ultColI}$($idxFora[-1])"); $rf.Font.Color = (Cor 89 89 89)
      $rs = $wsI.Range("B$($idxFora[0]):B$($idxFora[-1])"); $rs.Interior.Color = (Cor 252 228 214); $rs.Font.Color = (Cor 132 60 12)
    }
    if ($idxRem.Count -gt 0) {
      $rr = $wsI.Range("A$($idxRem[0]):${ultColI}$($idxRem[-1])"); $rr.Interior.Color = (Cor 230 230 230); $rr.Font.Color = (Cor 128 128 128)
    }
    # destaques célula a célula (poucas linhas: NOVO, LIMITE/A CONFIRMAR, preço que caiu/subiu)
    $nNovo = 0; $nLim = 0; $nCaiu = 0; $nSubiu = 0
    for ($i = 0; $i -lt $n; $i++) {
      $it = $itens[$i]; $lin = $L1 + $i
      if ($it.Novo) { $cc = $wsI.Range("B$lin"); $cc.Interior.Color = (Cor 198 239 206); $cc.Font.Color = (Cor 0 97 0); $cc.Font.Bold = $true; $nNovo++ }
      if ($it.Area -eq 'LIMITE' -or $it.Area -eq 'A CONFIRMAR') { $cc = $wsI.Range("C$lin"); $cc.Interior.Color = (Cor 255 235 156); $cc.Font.Color = (Cor 156 101 0); $nLim++ }
      if ($it.Mudanca -eq 'caiu')  { $cc = $wsI.Range("${cPRECO}$lin"); $cc.Font.Color = (Cor 0 128 0); $cc.Font.Bold = $true; $nCaiu++ }
      if ($it.Mudanca -eq 'subiu') { $cc = $wsI.Range("${cPRECO}$lin"); $cc.Font.Color = (Cor 192 0 0); $cc.Font.Bold = $true; $nSubiu++ }
    }
    Escrever-Log "Destaques aplicados: NOVO $nNovo; LIMITE/A CONFIRMAR $nLim; preço caiu $nCaiu; preço subiu $nSubiu; FORA $($idxFora.Count); REMOVIDO $($idxRem.Count)"
    # autofiltro
    [void]$wsI.Range("A4:${ultColI}${L2}").AutoFilter(1)
  }
  # painéis congelados abaixo do cabeçalho e à direita do ENDEREÇO; zoom 90; sem linhas de grade
  $win = $wb.Windows.Item(1)
  $wsI.Activate(); $win.FreezePanes = $false; $win.SplitRow = 4; $win.SplitColumn = 6; $win.FreezePanes = $true
  $win.DisplayGridlines = $false; $win.Zoom = 90
  Escrever-Log ("Aba IMÓVEIS escrita ({0} linhas) em {1:n1} s" -f $n, $relogio.Elapsed.TotalSeconds)

  # ============================================================== ABA RESUMO
  $wsR.Activate()
  $wsR.Columns.Item(1).ColumnWidth = 44; $wsR.Columns.Item(2).ColumnWidth = 22
  for ($j = 3; $j -le 10; $j++) { $wsR.Columns.Item($j).ColumnWidth = 15 }
  $c = $wsR.Range('A1'); SetV $c 'RESUMO DA PESQUISA'; $c.Font.Bold = $true; $c.Font.Size = 14; $c.Font.Color = (Cor 31 56 100)
  $c = $wsR.Range('A2'); SetV $c 'Rodada:'; $c.Font.Bold = $true
  $c = $wsR.Range('B2'); $c.NumberFormatLocal = 'dd/mm/aaaa'; SetV $c (OA $dataRodada); $c.HorizontalAlignment = -4131; $c.Font.Bold = $true
  $c = $wsR.Range('A3'); SetV $c ("Gerado em {0:dd/MM/yyyy HH:mm} a partir de {1} ({2} linhas na planilha)" -f (Get-Date), (Split-Path -Leaf $Base), $n); $c.Font.Italic = $true; $c.Font.Color = (Cor 110 110 110)
  $wsR.Rows.Item(1).RowHeight = 22
  $linha = 5

  $ativos = @($itens | Where-Object Status -eq 'ATIVO')
  $bairros = @($itens | Select-Object -ExpandProperty Bairro -Unique | Sort-Object { if ($ordemBairro.ContainsKey($_)) { $ordemBairro[$_] } else { 9 } }, { $_ })
  # 1) bairro x status
  $tab = @()
  foreach ($b in $bairros) {
    $g = @($itens | Where-Object Bairro -eq $b)
    $tab += ,@($b, @($g | Where-Object Status -eq 'ATIVO').Count, @($g | Where-Object Novo).Count, @($g | Where-Object Status -eq 'FORA DOS CRITÉRIOS').Count, @($g | Where-Object Status -eq 'REMOVIDO').Count, $g.Count)
  }
  $tab += ,@('TOTAL', $cont.Ativo, $cont.Novos, $cont.Fora, $cont.Removido, $n)
  $linha = Escrever-Bloco $wsR $linha 'IMÓVEIS POR BAIRRO E STATUS' @('BAIRRO', 'ATIVO', 'dos quais NOVOS', 'FORA DOS CRITÉRIOS', 'REMOVIDO', 'TOTAL') $tab @('@', 'int', 'int', 'int', 'int', 'int')
  $wsR.Range("A$($linha - 2):F$($linha - 2)").Font.Bold = $true

  # 2) por fonte
  $tab = @()
  foreach ($f in @('VIVAREAL', 'QUINTOANDAR', 'CHAVESNAMAO')) {
    $g = @($itens | Where-Object Fonte -eq $f)
    $tab += ,@($mapaFonte[$f], @($g | Where-Object Status -eq 'ATIVO').Count, @($g | Where-Object Novo).Count, @($g | Where-Object Status -eq 'FORA DOS CRITÉRIOS').Count, @($g | Where-Object Status -eq 'REMOVIDO').Count, $g.Count)
  }
  $outrasFontes = @($itens | Where-Object { @('VIVAREAL', 'QUINTOANDAR', 'CHAVESNAMAO') -notcontains $_.Fonte })
  if ($outrasFontes.Count -gt 0) { $tab += ,@('Outras', @($outrasFontes | Where-Object Status -eq 'ATIVO').Count, @($outrasFontes | Where-Object Novo).Count, @($outrasFontes | Where-Object Status -eq 'FORA DOS CRITÉRIOS').Count, @($outrasFontes | Where-Object Status -eq 'REMOVIDO').Count, $outrasFontes.Count) }
  $linha = Escrever-Bloco $wsR $linha 'IMÓVEIS POR FONTE' @('FONTE', 'ATIVO', 'dos quais NOVOS', 'FORA DOS CRITÉRIOS', 'REMOVIDO', 'TOTAL') $tab @('@', 'int', 'int', 'int', 'int', 'int')

  # 3) movimentos da rodada
  $remRodada = @($itens | Where-Object { $_.Status -eq 'REMOVIDO' -and $null -ne $_.RemovidoEm -and $_.RemovidoEm.Date -eq $dataRodada.Date })
  $altRodada = @($itens | Where-Object { $null -ne $_.PrecoAltEm -and $_.PrecoAltEm.Date -eq $dataRodada.Date -and $_.Mudanca -ne '' })
  $caiuRodada = @($altRodada | Where-Object Mudanca -eq 'caiu'); $subiuRodada = @($altRodada | Where-Object Mudanca -eq 'subiu')
  $tab = @(
    ,@('Novos nesta rodada (1ª captura = rodada)', $cont.Novos)
    ,@('Removidos nesta rodada', $remRodada.Count)
    ,@('Preço alterado nesta rodada', $altRodada.Count)
    ,@('   dos quais caiu', $caiuRodada.Count)
    ,@('   dos quais subiu', $subiuRodada.Count)
    ,@('Total ATIVO na planilha', $cont.Ativo)
    ,@('   ATIVO em área SIM', @($ativos | Where-Object Area -eq 'SIM').Count)
    ,@('   ATIVO em LIMITE', @($ativos | Where-Object Area -eq 'LIMITE').Count)
    ,@('   ATIVO em A CONFIRMAR', @($ativos | Where-Object Area -eq 'A CONFIRMAR').Count)
    ,@('Possíveis duplicatas (anúncios em grupo)', @($itens | Where-Object { $_.DupTexto -ne '' }).Count)
  )
  $linha = Escrever-Bloco $wsR $linha ("MOVIMENTOS DA RODADA {0:dd/MM/yyyy}" -f $dataRodada) @('INDICADOR', 'QUANTIDADE') $tab @('@', 'int')

  # 4) R$/m² por bairro (ATIVO e área SIM)
  $tab = @()
  foreach ($b in $bairros) {
    $g = @($ativos | Where-Object { $_.Bairro -eq $b -and $_.Area -eq 'SIM' -and $null -ne $_.M2 })
    if ($g.Count -eq 0) { $tab += ,@($b, 0, $null, $null, $null, $null, $null); continue }
    $m2s = @($g | ForEach-Object { $_.M2 })
    $tab += ,@($b, $g.Count, ($m2s | Measure-Object -Minimum).Minimum, (Mediana $m2s), ($m2s | Measure-Object -Maximum).Maximum, (Mediana @($g | ForEach-Object { $_.Preco })), (Mediana @($g | ForEach-Object { $_.AreaUtil })))
  }
  $gt = @($ativos | Where-Object { $_.Area -eq 'SIM' -and $null -ne $_.M2 })
  if ($gt.Count -gt 0) { $m2s = @($gt | ForEach-Object { $_.M2 }); $tab += ,@('TODOS', $gt.Count, ($m2s | Measure-Object -Minimum).Minimum, (Mediana $m2s), ($m2s | Measure-Object -Maximum).Maximum, (Mediana @($gt | ForEach-Object { $_.Preco })), (Mediana @($gt | ForEach-Object { $_.AreaUtil }))) }
  $linha = Escrever-Bloco $wsR $linha 'R$/M² POR BAIRRO (só ATIVO em área SIM)' @('BAIRRO', 'QTD', 'R$/M² MÍNIMO', 'R$/M² MEDIANO', 'R$/M² MÁXIMO', 'PREÇO MEDIANO', 'ÁREA MEDIANA (m²)') $tab @('@', 'int', 'R$', 'R$', 'R$', 'R$', 'int')
  if ($gt.Count -gt 0) { $wsR.Range("A$($linha - 2):G$($linha - 2)").Font.Bold = $true }

  # 5) 10 menores R$/m² (ATIVO, qualquer área de interesse)
  $top = @($ativos | Where-Object { $null -ne $_.M2 } | Sort-Object M2 | Select-Object -First 10)
  $tab = @(); foreach ($t in $top) { $tab += ,@($t.Endereco, $t.Bairro, $t.Area, $t.Preco, $t.AreaUtil, $t.M2, $t.Local, [double]$t.Num, $t.Link) }
  $linha = Escrever-Bloco $wsR $linha '10 MENORES R$/M² (ATIVO)' @('ENDEREÇO', 'BAIRRO', 'ÁREA DE INTERESSE', 'PREÇO', 'ÁREA (m²)', 'R$/M²', 'FONTE', 'Nº NA ABA IMÓVEIS', 'LINK') $tab @('@', '@', '@', 'R$', 'int', 'R$', '@', 'int', 'link')
  $ultLinhaResumo = $linha
  $wsR.Activate(); $win.DisplayGridlines = $false; $win.Zoom = 90
  Escrever-Log ("Aba RESUMO escrita em {0:n1} s" -f $relogio.Elapsed.TotalSeconds)

  # ============================================================== ABA HISTÓRICO
  $wsH.Activate()
  $c = $wsH.Range('A1'); SetV $c 'HISTÓRICO DAS RODADAS'; $c.Font.Bold = $true; $c.Font.Size = 14; $c.Font.Color = (Cor 31 56 100)
  $c = $wsH.Range('A2'); SetV $c 'Uma linha por rodada. "Coletados" = anúncios vistos na rodada (verificados na data), por fonte. Linhas anteriores preservadas da planilha anterior.'; $c.Font.Italic = $true; $c.Font.Color = (Cor 110 110 110)
  $wsH.Rows.Item(1).RowHeight = 22
  $cabH = @('DATA DA RODADA', 'VIVAREAL/ZAP', 'QUINTOANDAR', 'CHAVES NA MÃO', 'TOTAL COLETADO', 'NOVOS', 'REMOVIDOS', 'PREÇO ALTERADO', 'TOTAL ATIVO', 'OBSERVAÇÃO')
  # linha da rodada atual: do JSON -ResumoRodada (quando houver) ou calculada da base
  $vistos = @($itens | Where-Object { $_.Status -ne 'REMOVIDO' -and $null -ne $_.Ultima -and $_.Ultima.Date -eq $dataRodada.Date })
  $atual = @{
    'DATA DA RODADA' = OA $dataRodada
    'VIVAREAL/ZAP'   = @($vistos | Where-Object Fonte -eq 'VIVAREAL').Count
    'QUINTOANDAR'    = @($vistos | Where-Object Fonte -eq 'QUINTOANDAR').Count
    'CHAVES NA MÃO'  = @($vistos | Where-Object Fonte -eq 'CHAVESNAMAO').Count
    'NOVOS'          = $cont.Novos
    'REMOVIDOS'      = $remRodada.Count
    'PREÇO ALTERADO' = $altRodada.Count
    'TOTAL ATIVO'    = $cont.Ativo
    'OBSERVAÇÃO'     = 'calculado da base'
  }
  if ($ResumoRodada -and (Test-Path $ResumoRodada)) {
    try {
      $js = Get-Content $ResumoRodada -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($js.coletados) {
        if ($null -ne $js.coletados.VIVAREAL)    { $atual['VIVAREAL/ZAP']  = [int]$js.coletados.VIVAREAL }
        if ($null -ne $js.coletados.QUINTOANDAR) { $atual['QUINTOANDAR']   = [int]$js.coletados.QUINTOANDAR }
        if ($null -ne $js.coletados.CHAVESNAMAO) { $atual['CHAVES NA MÃO'] = [int]$js.coletados.CHAVESNAMAO }
      }
      if ($null -ne $js.novos)          { $atual['NOVOS'] = [int]$js.novos }
      if ($null -ne $js.removidos)      { $atual['REMOVIDOS'] = [int]$js.removidos }
      if ($null -ne $js.preco_alterado) { $atual['PREÇO ALTERADO'] = [int]$js.preco_alterado }
      if ($null -ne $js.total_ativo)    { $atual['TOTAL ATIVO'] = [int]$js.total_ativo }
      $atual['OBSERVAÇÃO'] = if ($js.observacao) { "$($js.observacao)" } else { 'resumo da rodada (JSON)' }
      Escrever-Log "HISTÓRICO: linha da rodada vinda de $ResumoRodada"
    } catch { Escrever-Log "AVISO: não li -ResumoRodada ($($_.Exception.Message)); linha calculada da base." }
  }
  $atual['TOTAL COLETADO'] = [int]$atual['VIVAREAL/ZAP'] + [int]$atual['QUINTOANDAR'] + [int]$atual['CHAVES NA MÃO']
  $linhasH = @()
  foreach ($reg in $historicoAnterior) {
    $dv = $reg['DATA DA RODADA']
    $dAnt = $null
    if ($dv -is [double]) { $dAnt = [datetime]::FromOADate($dv) } elseif ($dv -is [datetime]) { $dAnt = $dv } else { $dAnt = ToData "$dv" }
    if ($null -eq $dAnt) { continue }
    if ($dAnt.Date -eq $dataRodada.Date) { continue }   # a rodada atual é reescrita
    $reg['DATA DA RODADA'] = OA $dAnt
    $linhasH += ,$reg
  }
  $linhasH += ,$atual
  $linhasH = @($linhasH | Sort-Object { [double]$_['DATA DA RODADA'] })
  $tab = @(); foreach ($reg in $linhasH) { $lin = @(); foreach ($nm in $cabH) { $v = $reg[$nm]; if ($nm -ne 'OBSERVAÇÃO' -and $nm -ne 'DATA DA RODADA' -and $null -ne $v -and "$v" -ne '') { $v = [double]$v }; $lin += ,$v }; $tab += ,$lin }
  $wsH.Columns.Item(1).ColumnWidth = 16; for ($j = 2; $j -le 9; $j++) { $wsH.Columns.Item($j).ColumnWidth = 14 }; $wsH.Columns.Item(10).ColumnWidth = 50
  # cabeçalho na linha 4 (o leitor da próxima rodada procura 'DATA DA RODADA' na linha 4)
  [void](Escrever-Bloco $wsH 3 '' $cabH $tab @('data', 'int', 'int', 'int', 'int', 'int', 'int', 'int', 'int', '@'))
  [void]$wsH.Range('A3').ClearContents()
  $win.DisplayGridlines = $false; $win.Zoom = 90
  Escrever-Log "Aba HISTÓRICO escrita: $($linhasH.Count) rodada(s)."

  # ============================================================== ABA CRITÉRIOS
  $wsC.Activate()
  $c = $wsC.Range('A1'); SetV $c 'CRITÉRIOS DE BUSCA EM VIGOR'; $c.Font.Bold = $true; $c.Font.Size = 14; $c.Font.Color = (Cor 31 56 100)
  $c = $wsC.Range('A2'); SetV $c "Fonte: $Criterios (editar lá para mudar a busca; os scripts leem esse arquivo)"; $c.Font.Italic = $true; $c.Font.Color = (Cor 110 110 110)
  $wsC.Rows.Item(1).RowHeight = 22
  $wsC.Columns.Item(1).ColumnWidth = 38; $wsC.Columns.Item(2).ColumnWidth = 60; $wsC.Columns.Item(3).ColumnWidth = 60
  for ($j = 4; $j -le 8; $j++) { $wsC.Columns.Item($j).ColumnWidth = 16 }
  $linha = 4
  $tab = @()
  if (Test-Path $Criterios) {
    $cj = Get-Content $Criterios -Raw -Encoding UTF8 | ConvertFrom-Json
    function Achatar($obj, [string]$prefixo) {
      $saida = @()
      foreach ($p in $obj.PSObject.Properties) {
        $nome = if ($prefixo) { "$prefixo.$($p.Name)" } else { $p.Name }
        $v = $p.Value
        if ($v -is [System.Management.Automation.PSCustomObject]) { $saida += Achatar $v $nome; continue }
        $txt = ''
        if ($v -is [System.Array]) {
          $partes = foreach ($e in $v) { if ($e -is [System.Array]) { ($e | ForEach-Object { "$_" }) -join ' a ' } elseif ($e -is [System.Management.Automation.PSCustomObject]) { ($e.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ' } else { "$e" } }
          $txt = $partes -join ' | '
        } elseif ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) { $txt = [double]$v }   # número continua número na célula
        else { $txt = "$v" }
        $obsTxt = ''
        if ($nome -match '^(preco_min|preco_max)$') { $obsTxt = 'R$ (limites inclusivos)' }
        if ($nome -match '^(area_util_min|area_util_max)$') { $obsTxt = 'm² de área útil (limites inclusivos)' }
        if ($nome -match '^borda') { $obsTxt = 'metros (regra de LIMITE / A CONFIRMAR do consolidador)' }
        if ($p.Name.StartsWith('_')) { $obsTxt = 'nota do arquivo' }
        $saida += ,@($nome, $txt, $obsTxt)
      }
      return ,$saida
    }
    # sem @( ) em volta: a função já devolve o array de linhas como UM objeto; @( ) o embrulharia num elemento só
    $tab = Achatar $cj ''
    if ($null -eq $tab) { $tab = @() }
    Escrever-Log "CRITÉRIOS: $($tab.Count) parâmetros do criterios.json."
  } else { Escrever-Log "AVISO: criterios.json não encontrado em $Criterios" }
  $linha = Escrever-Bloco $wsC $linha 'PARÂMETROS (criterios.json)' @('PARÂMETRO', 'VALOR', 'OBSERVAÇÃO') $tab @('@', 'g', '@')
  if ($tab.Count -gt 0) { $wsC.Range("B$($linha - 1 - $tab.Count):B$($linha - 2)").WrapText = $true }
  # polígonos e fontes
  $tab = @()
  $pastaAreas = Join-Path $raiz 'Áreas de interesse'
  if ($cj -and $cj.poligonos) {
    foreach ($p in $cj.poligonos.PSObject.Properties) {
      $arq = Join-Path $raiz $p.Value
      $existe = if (Test-Path $arq) { 'sim' } else { 'ainda não gerado' }
      $mapa = @(Get-ChildItem -Path $pastaAreas -Filter "*$($p.Name)*.jpg" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Name)
      $tab += ,@($p.Name, $p.Value, $existe, $(if ($mapa.Count -gt 0) { $mapa[0] } else { '' }))
    }
  }
  $linha = Escrever-Bloco $wsC $linha 'POLÍGONOS DAS ÁREAS DE INTERESSE' @('ÁREA', 'ARQUIVO DO POLÍGONO (GeoJSON)', 'EXISTE?', 'MAPA DE ORIGEM (marcação do Guilherme)') $tab @('@', '@', '@', '@')
  $docs = @()
  foreach ($d in @('Sites e critérios para Busca\Locais e critérios para pesquisa dos imóveis.docx', 'Listagem das ruas\Listagem das ruas de interesse para compra - Ipanema e Leblon.docx', 'Planilha de Apartamentos Pesquisados\Planilha modelo para preenchimento.xlsx')) {
    $pth = Join-Path $raiz $d; $docs += ,@((Split-Path -Leaf $d), (Split-Path -Parent $d), $(if (Test-Path $pth) { 'sim' } else { 'não encontrado' }))
  }
  $linha = Escrever-Bloco $wsC $linha 'DOCUMENTOS DE ORIGEM' @('DOCUMENTO', 'PASTA (relativa à raiz do projeto)', 'EXISTE?') $docs @('@', '@', '@')
  # ruas
  $tab = @()
  if (Test-Path $Ruas) {
    $ruasCsv = @(Import-Csv -Path $Ruas -Delimiter ';' -Encoding UTF8)
    foreach ($ru in $ruasCsv) { $tab += ,@($ru.rua, $ru.poligono, $ru.bairro_cep, $ru.cep, $ru.faixa, $ru.lado, $ru.situacao, $ru.observacao) }
    Escrever-Log "CRITÉRIOS: $($tab.Count) trechos de rua de ruas.csv."
  }
  $linha = Escrever-Bloco $wsC $linha 'RUAS DA ÁREA DE INTERESSE (ruas.csv)' @('RUA', 'POLÍGONO', 'BAIRRO (CEP)', 'CEP', 'FAIXA DE NÚMEROS', 'LADO', 'SITUAÇÃO', 'OBSERVAÇÃO') $tab @('@', '@', '@', '@', '@', '@', '@', '@')
  $win.DisplayGridlines = $false; $win.Zoom = 90
  Escrever-Log ("Aba CRITÉRIOS escrita em {0:n1} s" -f $relogio.Elapsed.TotalSeconds)

  # -------------------------------------------------------------- 6. salvar
  $wsI.Activate()
  if (-not (Esperar-Liberacao $Saida 20)) { throw "Não consegui gravar: a planilha está em uso por outro programa (aberta no Excel?). Feche-a e rode de novo: $Saida" }
  $salvou = $false
  for ($tent = 1; $tent -le 3 -and -not $salvou; $tent++) {
    try { $wb.SaveAs($Saida, 51); $salvou = $true }
    catch { if ($tent -eq 3) { throw }; Escrever-Log "AVISO: SaveAs falhou na tentativa ${tent} ($($_.Exception.Message)); tento de novo em 2 s."; Start-Sleep -Seconds 2 }
  }
  Escrever-Log ("Planilha salva: {0} ({1:n1} s)" -f $Saida, $relogio.Elapsed.TotalSeconds)

  # -------------------------------------------------------------- 7. imagens de conferência (opcional)
  if ($Png) {
    if (-not (Test-Path $Png)) { New-Item -ItemType Directory -Force $Png | Out-Null }
    # CopyPicture só gera imagem com ScreenUpdating ligado (desligado, o PNG sai em branco com 2,7 KB e sem erro)
    $app.ScreenUpdating = $true
    function Exportar-Png($ws, [string]$endereco, [string]$arquivo) {
      # várias exportações seguidas às vezes saem em branco (clipboard ainda ocupado): pausa + até 3 tentativas
      $tam = 0
      for ($tent = 1; $tent -le 3; $tent++) {
        $ws.Activate(); Start-Sleep -Milliseconds 300
        $r = $ws.Range($endereco); [void]$r.CopyPicture(1, 2); Start-Sleep -Milliseconds 300
        $co = $ws.ChartObjects().Add(0, 0, $r.Width, $r.Height)
        [void]$co.Chart.Paste(); Start-Sleep -Milliseconds 300
        [void]$co.Chart.Export($arquivo, 'PNG'); [void]$co.Delete()
        $tam = (Get-Item $arquivo).Length
        if ($tam -gt 10KB) { break }
      }
      if ($tam -le 10KB) { Escrever-Log "AVISO: PNG saiu em branco após 3 tentativas: $arquivo ($endereco)" }
      else { Escrever-Log ("PNG: {0} ({1}, {2:n0} KB, tentativa {3})" -f $arquivo, $endereco, ($tam / 1KB), $tent) }
    }
    $fim = [math]::Min($L2, $L1 + 24)
    Exportar-Png $wsI "A1:P$fim" (Join-Path $Png 'imoveis-A-P.png')
    Exportar-Png $wsI "Q1:${ultColI}$fim" (Join-Path $Png 'imoveis-Q-AG.png')
    Exportar-Png $wsR "A1:J$([math]::Min($ultLinhaResumo, 60))" (Join-Path $Png 'resumo.png')
    Exportar-Png $wsH "A1:J$(4 + $linhasH.Count + 1)" (Join-Path $Png 'historico.png')
    Exportar-Png $wsC "A1:H40" (Join-Path $Png 'criterios.png')
  }
  $wb.Close($false); Liberar $wb; $wb = $null
  Escrever-Log ("Concluído em {0:n1} s" -f $relogio.Elapsed.TotalSeconds)
  $codigoSaida = 0
}
catch {
  Escrever-Log "ERRO: $($_.Exception.Message)"
  Escrever-Log "  em: $($_.InvocationInfo.PositionMessage)"
  $codigoSaida = 1
}
finally {
  try { if ($null -ne $wbAnt) { $wbAnt.Close($false) } } catch {}
  try { if ($null -ne $wbMod) { $wbMod.Close($false) } } catch {}
  try { if ($null -ne $wb) { $wb.Close($false) } } catch {}
  if ($null -ne $app) { try { $app.Quit() } catch {} }
  Liberar $wbAnt; Liberar $wbMod; Liberar $wb; Liberar $app
  [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  Salvar-Log
}
exit $codigoSaida
