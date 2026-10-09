$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$post = 'D:\12- Claude - works\01 - EP Engenharia\Instagram EP\01-Posts\P05_2026-10-15_antes-das-chuvas'

# --- Item 6: títulos e corpos do carrossel ---
$car = Get-Content -Raw -Encoding UTF8 (Join-Path $post '02-textos\carrossel.md')
$lines = $car -split "`r?`n"
$maxT = 0; $maxC = 0; $slide = ''
Write-Output "=== ITEM 6 ==="
for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^## Slide') { $slide = $l.Trim() }
    if ($l -match '^\s*-\s*(Título|Frase):\s*(.*)$') {
        $t = $Matches[2].Trim(); $n = $t.Length
        Write-Output ("titulo | {0} | linha {1} | {2} chars" -f $slide, ($i+1), $n)
        if ($n -gt $maxT) { $maxT = $n }
    }
    if ($l -match '^\s*-\s*Corpo:\s*(.*)$') {
        $t = $Matches[1].Trim(); $n = $t.Length
        Write-Output ("corpo  | {0} | linha {1} | {2} chars" -f $slide, ($i+1), $n)
        if ($n -gt $maxC) { $maxC = $n }
    }
}
Write-Output ("MAX titulo = {0} ; MAX corpo = {1}" -f $maxT, $maxC)
$sl7 = ($lines | Where-Object { $_ -match '^\s*-\s*Corpo:' })[6]
Write-Output ("Slide 7 corpo atual: " + $sl7)

# --- Item 15: palavras proibidas ---
Write-Output "=== ITEM 15 ==="
$termos = @('empreiteir','incrível','maravilhos','barato','obra nossa','nossa obra','nossa equipe fez','antes e depois da EP')
$files = Get-ChildItem -Path $post -Recurse -Include *.md,*.txt -File | Where-Object { $_.FullName -notlike '*03-prompts-imagem\fotos-escolhidas.md' }
$total = 0
foreach ($f in $files) {
    $txt = Get-Content -Raw -Encoding UTF8 $f.FullName
    $fl = $txt -split "`r?`n"
    foreach ($t in $termos) {
        $rx = [regex]::new([regex]::Escape($t), 'IgnoreCase')
        $c = $rx.Matches($txt).Count
        if ($c -gt 0) {
            $total += $c
            for ($k = 0; $k -lt $fl.Count; $k++) { if ($rx.IsMatch($fl[$k])) { Write-Output ("HIT | {0} | '{1}' | linha {2}: {3}" -f $f.FullName.Substring($post.Length+1), $t, ($k+1), $fl[$k].Trim()) } }
        }
    }
}
Write-Output ("Arquivos varridos: {0} ; TOTAL ocorrencias = {1}" -f $files.Count, $total)
$files | ForEach-Object { Write-Output ("  - " + $_.FullName.Substring($post.Length+1)) }
$brief = Get-Content -Encoding UTF8 (Join-Path $post '01-brief\brief.md')
Write-Output ("brief linha 13: " + $brief[12])

# --- Item 2: tamanhos ---
Write-Output "=== ITEM 2 ==="
foreach ($rel in @('01-brief\brief.md','02-textos\carrossel.md','02-textos\legenda.txt','02-textos\stories.txt','03-prompts-imagem\prompts.md')) {
    $p = Join-Path $post $rel
    $ex = Test-Path $p
    $len = if ($ex) { (Get-Content -Raw -Encoding UTF8 $p).Trim().Length } else { -1 }
    Write-Output ("{0} | existe={1} | {2} chars" -f $rel, $ex, $len)
}
