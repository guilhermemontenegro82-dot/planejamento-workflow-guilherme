$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$post = 'D:\12- Claude - works\01 - EP Engenharia\Instagram EP\01-Posts\P05_2026-10-15_antes-das-chuvas'
$car = Get-Content -Raw -Encoding UTF8 (Join-Path $post '02-textos\carrossel.md')
$leg = Get-Content -Raw -Encoding UTF8 (Join-Path $post '02-textos\legenda.txt')
$sto = Get-Content -Raw -Encoding UTF8 (Join-Path $post '02-textos\stories.txt')

Write-Output "=== ITEM 3 placeholders (carrossel, legenda, stories) ==="
$ph = @('Pnn','[tema]','AAAA-MM-DD','n slides','(em branco)')
$tot = 0
foreach ($pair in @(@('carrossel',$car),@('legenda',$leg),@('stories',$sto))) {
  foreach ($p in $ph) { $c = ([regex]::Matches($pair[1], [regex]::Escape($p))).Count; if ($c -gt 0) { Write-Output ("HIT {0} '{1}' x{2}" -f $pair[0],$p,$c) }; $tot += $c }
}
Write-Output ("placeholders total = {0}" -f $tot)

Write-Output "=== ITEM 5 ==="
Write-Output ("slides = {0}" -f ([regex]::Matches($car,'(?m)^## Slide')).Count)

Write-Output "=== ITEM 7 ==="
$lines = $car -split "`r?`n"
$s1 = ($lines | Select-Object -Skip 2 -First 6) -join "`n"
Write-Output ("capa Tag: {0} Titulo: {1} Apoio: {2}" -f ($s1 -match '(?m)^- Tag:'), ($s1 -match '(?m)^- T.tulo:'), ($s1 -match '(?m)^- Apoio:'))
$tit = ($lines | Where-Object { $_ -match '^- T.tulo:' })[0]
Write-Output ("titulo capa trechos ** = {0}" -f ([regex]::Matches($tit,'\*\*[^*]+\*\*')).Count)
$idx = [array]::LastIndexOf([object[]]($lines | ForEach-Object { if ($_ -match '^## Slide') {'X'} else {''} }),'X')
$last = ($lines[$idx..($lines.Count-1)]) -join "`n"
Write-Output ("ultimo slide = {0} | tel = {1} | site = {2}" -f $lines[$idx].Trim(), $last.Contains('(21) 98355-0728'), $last.Contains('epengenharia.eng.br'))

Write-Output "=== ITEM 8/9/10/11 legenda ==="
Write-Output ("blocos TEXTO PARA COLAR={0} HASHTAGS={1} COMO POSTAR={2}" -f $leg.Contains('TEXTO PARA COLAR'), $leg.Contains('HASHTAGS'), $leg.Contains('COMO POSTAR'))
Write-Output ("contato tel={0} site={1}" -f $leg.Contains('(21) 98355-0728'), $leg.Contains('epengenharia.eng.br'))
$sep = '=================================================='
$parts = $leg -split [regex]::Escape($sep)
# parts: 0 header, 1 'TEXTO PARA COLAR...', 2 texto, 3 'HASHTAGS', 4 hashtags, 5 'COMO POSTAR', 6 instrucoes
$texto = $parts[2].Trim(); $hash = $parts[4].Trim()
Write-Output ("texto = {0} chars ; hashtags = {1} chars ; soma = {2} ; soma+2 quebras = {3}" -f $texto.Length, $hash.Length, ($texto.Length+$hash.Length), ($texto.Length+$hash.Length+2))
$tags = $hash -split '\s+' | Where-Object { $_ -ne '' }
$inv = $tags | Where-Object { $_ -notmatch '^#[A-Za-z0-9_]+$' }
$dup = ($tags | ForEach-Object { $_.ToLower() } | Group-Object | Where-Object { $_.Count -gt 1 })
Write-Output ("hashtags = {0} ; invalidas = {1} [{2}] ; duplicadas = {3} [{4}]" -f $tags.Count, @($inv).Count, ($inv -join ','), @($dup).Count, (($dup | ForEach-Object Name) -join ','))

Write-Output "=== ITEM 12 stories ==="
$sl = $sto -split "`r?`n"
$iP = 0; for ($k=0;$k -lt $sl.Count;$k++){ if ($sl[$k] -match "^STORY PRINCIPAL") { $iP = $k } }
$iA = $sl.Count; for ($k=0;$k -lt $sl.Count;$k++){ if ($sl[$k] -match "^ALTERNATIVA") { $iA = $k } }
$bloco = $sl[($iP+1)..($iA-1)] | Where-Object { $_.Trim() -ne '' }
$semSticker = $bloco | Where-Object { $_ -notmatch '^Sticker:' }
$semTag = $semSticker | Where-Object { $_ -notmatch '^Tag:' }
Write-Output ("principal: linhas={0} ; sem Sticker = {1} chars ; sem Sticker e sem Tag = {2} chars ; com Sticker = {3} chars ; contem feed = {4}" -f $bloco.Count, (($semSticker -join "`n").Trim().Length), (($semTag -join "`n").Trim().Length), (($bloco -join "`n").Trim().Length), (($semSticker -join "`n") -match 'feed'))
$alt = $sl[($iA+1)..($sl.Count-1)] | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^Sticker:' }
Write-Output ("alternativa (sem Sticker) = {0} chars" -f (($alt -join "`n").Trim().Length))
