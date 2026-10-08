# render-arte.ps1 — gera os PNGs da arte final (1080x1350 slides, 1080x1920 story) a partir de um arte.json
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File render-arte.ps1 -Json "<pasta do post>\05-arte-final\arte.json" -OutDir "<pasta do post>\05-arte-final"
# Depende só do Edge (headless) e dos arquivos de 00-Marca/ (templates, fontes, logo). Sem Python, sem Node.
param(
  [Parameter(Mandatory=$true)][string]$Json,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [switch]$SoHtml
)
$ErrorActionPreference = 'Stop'
$tpl   = $PSScriptRoot                                  # 00-Marca\templates
$marca = Split-Path $tpl -Parent                        # 00-Marca
$edge  = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { throw "Edge nao encontrado em $edge" }

$data = Get-Content -LiteralPath $Json -Raw -Encoding UTF8 | ConvertFrom-Json
$jsonDir = Split-Path (Resolve-Path -LiteralPath $Json) -Parent
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir '_html') | Out-Null
$baseUri = (New-Object System.Uri ($marca.TrimEnd('\') + '\')).AbsoluteUri

function Uri([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return '' }
  if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $jsonDir $p }
  if (-not (Test-Path -LiteralPath $p)) { Write-Warning "imagem nao encontrada: $p" }
  return (New-Object System.Uri ((Resolve-Path -LiteralPath $p).Path)).AbsoluteUri
}
function Esc([string]$s) { if ($null -eq $s) { return '' }; return [System.Net.WebUtility]::HtmlEncode($s) }
# **trecho** vira <em> (titulos: destaque ciano) ou <b> (corpo: negrito)
function Rich([string]$s, [string]$tag) {
  $s = Esc $s
  $s = [regex]::Replace($s, '\*\*(.+?)\*\*', ('<' + $tag + '>$1</' + $tag + '>'))
  return $s.Replace("`n", '<br>')
}
# tamanho do titulo pelo comprimento (sem markup)
function Px([string]$s, [int[]]$escala) {
  $n = ([regex]::Replace($s, '\*\*', '')).Length
  if ($n -le 28) { return $escala[0] } elseif ($n -le 44) { return $escala[1] } elseif ($n -le 62) { return $escala[2] } else { return $escala[3] }
}
function Fill([string]$html, [hashtable]$vars) {
  foreach ($k in $vars.Keys) { $html = $html.Replace('{{' + $k + '}}', [string]$vars[$k]) }
  return [regex]::Replace($html, '\{\{[a-z_]+\}\}', '')   # placeholders nao usados somem
}
$resultados = New-Object System.Collections.Generic.List[string]
function Render([string]$tipo, [hashtable]$vars, [string]$nome, [int]$w, [int]$h) {
  $html = Get-Content -LiteralPath (Join-Path $tpl "$tipo.html") -Raw -Encoding UTF8
  $vars['base'] = $baseUri
  $html = Fill $html $vars
  $hp = Join-Path (Join-Path $OutDir '_html') "$nome.html"
  [System.IO.File]::WriteAllText($hp, $html, (New-Object System.Text.UTF8Encoding $false))
  if ($SoHtml) { $resultados.Add("$nome  html"); return }
  $png = Join-Path $OutDir "$nome.png"
  if (Test-Path -LiteralPath $png) { [System.IO.File]::Delete($png) }
  $uri = (New-Object System.Uri $hp).AbsoluteUri
  $errLog = Join-Path (Join-Path $OutDir '_html') 'edge-stderr.log'
  $edgeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', '--force-device-scale-factor=1', "--window-size=$w,$h", '--virtual-time-budget=5000', "--screenshot=`"$png`"", $uri)
  Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -NoNewWindow -RedirectStandardError $errLog
  $t = 0; while (-not (Test-Path -LiteralPath $png) -and $t -lt 40) { Start-Sleep -Milliseconds 500; $t++ }
  $resultados.Add(("{0,-12} {1}" -f $nome, $(if (Test-Path -LiteralPath $png) { "ok  ${w}x${h}" } else { 'FALHOU' })))
}

$handle = if ($data.handle) { $data.handle } else { '@ENGENHARIA.EP' }
$rotulo = if ($data.rotulo) { $data.rotulo } else { 'Sinal' }
$secao  = if ($data.secao)  { $data.secao }  else { 'ATENÇÃO' }
$i = 0
foreach ($s in $data.slides) {
  $i++; $nome = 'slide-{0:00}' -f $i
  switch ($s.tipo) {
    'capa' {
      $px = Px $s.titulo @(118, 104, 92, 80)
      Render 'capa' @{ tag = (Esc $s.tag); titulo = (Rich $s.titulo 'em'); titulo_px = $px; titulo_top = $(if ($px -ge 104) { 590 } else { 600 }); apoio = (Esc $s.apoio); fundo = (Uri $s.fundo); handle = (Esc $handle) } $nome 1080 1350
    }
    'interno-claro' {
      $foto = Uri $s.foto
      Render 'interno-claro' @{ n = $s.n; total = $s.total; rotulo = (Esc $rotulo); secao = (Esc $secao); titulo = (Rich $s.titulo 'em'); titulo_px = (Px $s.titulo @(84, 78, 68, 60)); corpo = (Rich $s.corpo 'b'); foto = $foto; foto_display = $(if ($foto) { 'block' } else { 'none' }); legenda_foto = (Esc $s.legenda_foto); pct = [math]::Round(100 * $s.n / $s.total) } $nome 1080 1350
    }
    'interno-foto' {
      Render 'interno-foto' @{ n = $s.n; total = $s.total; rotulo = (Esc $rotulo); titulo = (Rich $s.titulo 'em'); titulo_px = (Px $s.titulo @(84, 78, 68, 60)); corpo = (Rich $s.corpo 'b'); fundo = (Uri $s.fundo); legenda_foto = (Esc $s.legenda_foto); handle = (Esc $handle) } $nome 1080 1350
    }
    'cta' {
      $px = Px $s.titulo @(96, 84, 74, 66)
      Render 'cta' @{ titulo = (Rich $s.titulo 'em'); titulo_px = $px; titulo_top = 430; corpo = (Rich $s.corpo 'b'); contato = (Rich $s.contato 'b'); botao = (Esc $s.botao); fundo = (Uri $s.fundo) } $nome 1080 1350
    }
    default { $resultados.Add("$nome  tipo desconhecido: $($s.tipo)") }
  }
}
if ($data.story) {
  $st = $data.story
  $px = Px $st.titulo @(104, 96, 86, 76)
  $linhas = [math]::Ceiling(([regex]::Replace($st.titulo, '\*\*', '')).Length / 22)
  $apoioTop = 760 + [int]($linhas * $px * 1.08) + 50
  Render 'story' @{ tag = (Esc $st.tag); titulo = (Rich $st.titulo 'em'); titulo_px = $px; titulo_top = 760; apoio = (Esc $st.apoio); apoio_top = $apoioTop; ponte = (Rich $st.ponte 'em'); fundo = (Uri $st.fundo) } 'story-01' 1080 1920
}
"=== render-arte: $($data.post) ==="
$resultados | ForEach-Object { $_ }
"saida: $OutDir"
