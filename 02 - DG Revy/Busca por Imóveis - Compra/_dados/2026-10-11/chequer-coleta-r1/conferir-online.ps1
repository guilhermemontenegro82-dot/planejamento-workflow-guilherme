# conferir-online.ps1 - itens 2 e 4: consultas ao vivo com curl.exe (ASCII only no corpo).
$ErrorActionPreference = 'Continue'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$dados = Split-Path -Parent $aqui
$raiz = Split-Path -Parent (Split-Path -Parent $dados)
$http = Join-Path $aqui 'http'; if (-not (Test-Path $http)) { New-Item -ItemType Directory -Path $http | Out-Null }
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$js.MaxJsonLength = [int]::MaxValue; $js.RecursionLimit = 500
function Ler($arq) { return $js.DeserializeObject([System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)) }
function Campo($o, [string]$k) { if ($null -eq $o) { return $null }; if (($o -is [System.Collections.IDictionary]) -and $o.ContainsKey($k)) { return $o[$k] }; return $null }
function Ser($o) { if ($null -eq $o) { return '(null)' }; return $js.Serialize($o) }
function Get-Curl([string]$url, [string]$arq, [string[]]$headers = @(), [switch]$L) {
    $args = @('-s', '-m', '40', '-A', $UA, '--compressed', '-o', $arq, '-w', '%{http_code}|%{url_effective}')
    if ($L) { $args += '-L' }
    foreach ($h in $headers) { $args += @('-H', $h) }
    $args += $url
    $out = & $curl @args
    return "$out"
}
function Post-Curl([string]$url, [string]$arqCorpo, [string]$arq, [string[]]$headers) {
    $args = @('-s', '-m', '40', '-A', $UA, '-o', $arq, '-w', '%{http_code}', '-X', 'POST', '--data-binary', ('@' + $arqCorpo))
    foreach ($h in $headers) { $args += @('-H', $h) }
    $args += $url
    $out = & $curl @args
    return "$out"
}
$agora = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output "consultas ao vivo em $agora"

# ================= ITEM 2: totais =================
Write-Output ''
Write-Output '===== ITEM 2 - VivaReal totalCount (Ipanema, Leblon, Copacabana 500000-575000) ====='
$qb = 'addressState=Rio%20de%20Janeiro&addressCity=Rio%20de%20Janeiro&addressZone=Zona%20Sul&addressType=neighborhood&business=SALE&listingType=USED&usableAreasMin=35&usableAreasMax=70&unitTypes=APARTMENT,KITNET&unitTypesV3=APARTMENT,KITNET&unitSubTypes=UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX&usageTypes=RESIDENTIAL&sort=createdAt%20ASC'
$hdrVR = @('x-domain: www.vivareal.com.br', 'Accept: application/json')
foreach ($q in @(@('Ipanema', 500000, 1100000, 476), @('Leblon', 500000, 1100000, 182), @('Copacabana', 500000, 575000, 305), @('Copacabana', 950001, 1100000, 505))) {
    $url = 'https://glue-api.vivareal.com/v2/listings?' + $qb + ('&addressNeighborhood={0}&priceMin={1}&priceMax={2}&from=0&size=1&includeFields=search(result(listings(listing(id))),totalCount)' -f $q[0], $q[1], $q[2])
    $arq = Join-Path $http ('vr-total-{0}-{1}-{2}.json' -f $q[0], $q[1], $q[2])
    $code = Get-Curl $url $arq $hdrVR
    $tc = $null; if ((Test-Path $arq)) { try { $o = Ler $arq; $tc = Campo (Campo $o 'search') 'totalCount' } catch { } }
    $pct = if ($tc) { [Math]::Round(100.0 * ([double]$tc - $q[3]) / $q[3], 2) } else { 'n/a' }
    Write-Output ("  {0} R$ {1}-{2}: HTTP={3} | totalCount agora={4} | log={5} | desvio={6} %" -f $q[0], $q[1], $q[2], $code.Split('|')[0], $tc, $q[3], $pct)
}

Write-Output ''
Write-Output '===== ITEM 2 - QuintoAndar hits.total.value ====='
$corpo = Join-Path $dados 'corpo-busca-quintoandar.json'
$arq = Join-Path $http 'qa-busca.json'
$hdrQA = @('Accept: application/json', 'Content-Type: application/json', 'Origin: https://www.quintoandar.com.br', 'Referer: https://www.quintoandar.com.br/comprar/imovel/ipanema-rio-de-janeiro-rj-brasil/apartamento')
$code = Post-Curl 'https://apigw.prod.quintoandar.com.br/house-listing-search/v2/search/list' $corpo $arq $hdrQA
$tot = $null; $nh = $null
if (Test-Path $arq) { try { $o = Ler $arq; $hits = Campo $o 'hits'; $tot = Campo (Campo $hits 'total') 'value'; $nh = @(Campo $hits 'hits').Count } catch { Write-Output "  erro ao ler: $($_.Exception.Message)" } }
Write-Output ("  HTTP={0} | hits.total.value agora={1} | hits devolvidos={2} | log=101 | desvio={3} %" -f $code, $tot, $nh, $(if ($tot) { [Math]::Round(100.0 * ([double]$tot - 101) / 101, 2) } else { 'n/a' }))
# ids da busca ao vivo x bruto
if ($nh) {
    $idsVivo = @(); foreach ($h in @(Campo $hits 'hits')) { $src = Campo $h '_source'; $idsVivo += [string](Campo $src 'id') }
    $bq = @(Import-Csv -Path (Join-Path $dados 'bruto-quintoandar.csv') -Delimiter ';' -Encoding UTF8 | Select-Object -ExpandProperty codigo)
    $soVivo = @($idsVivo | Where-Object { $bq -notcontains $_ }); $soBruto = @($bq | Where-Object { $idsVivo -notcontains $_ })
    Write-Output ("  ids so na busca ao vivo (novos desde 19:17): {0} | ids so no bruto (sairam): {1}" -f $soVivo.Count, $soBruto.Count)
}

Write-Output ''
Write-Output '===== ITEM 2 - Chaves na Mao totalResults (search-map-items) e totalListing (level3) ====='
$filtro = [Uri]::EscapeDataString('pmin:500000,pmax:1100000,amin:35,amax:70')
foreach ($cx in @(@('Ipanema_Arpoador', -22.97439, -22.99782, -43.186, -43.22307, 603), @('Leblon', -22.9745, -22.9925, -43.2125, -43.239, 132))) {
    $inv = [cultureinfo]::InvariantCulture
    $url = 'https://www.chavesnamao.com.br/api/realestate/search-map-items/?level1=imoveis-a-venda&level2=rj-rio-de-janeiro&mapNorth={0}&mapSouth={1}&mapEast={2}&mapWest={3}&locationScope=area&filtro={4}' -f $cx[1].ToString($inv), $cx[2].ToString($inv), $cx[3].ToString($inv), $cx[4].ToString($inv), $filtro
    $arq = Join-Path $http ('cnm-mapa-{0}.json' -f $cx[0])
    $code = Get-Curl $url $arq
    $tr = $null; $ni = $null
    if (Test-Path $arq) { try { $o = Ler $arq; $tr = Campo $o 'totalResults'; $ni = @(Campo $o 'items').Count } catch { } }
    Write-Output ("  caixa {0}: HTTP={1} | totalResults agora={2} | itens no 1o lote={3} | log={4} | desvio={5} %" -f $cx[0], $code.Split('|')[0], $tr, $ni, $cx[5], $(if ($tr) { [Math]::Round(100.0 * ([double]$tr - $cx[5]) / $cx[5], 2) } else { 'n/a' }))
}
foreach ($b in @(@('ipanema', 251), @('leblon', 76))) {
    $url = 'https://www.chavesnamao.com.br/api/realestate/listing/items/?level1=imoveis-a-venda&level2=rj-rio-de-janeiro&level3={0}&pg=1&filtro={1}' -f $b[0], $filtro
    $arq = Join-Path $http ('cnm-lista-{0}.json' -f $b[0])
    $code = Get-Curl $url $arq
    $tl = $null; $pb = $null
    if (Test-Path $arq) { try { $o = Ler $arq; $md = Campo $o 'metadata'; $tl = Campo $md 'totalListing'; $pb = Ser (Campo $md 'pageBreak') } catch { } }
    Write-Output ("  level3={0}: HTTP={1} | metadata.totalListing agora={2} | pageBreak={3} | log={4}" -f $b[0], $code.Split('|')[0], $tl, $pb, $b[1])
}

# ================= ITEM 4: fidelidade =================
$col = @(Import-Csv -Path (Join-Path $dados 'coleta.csv') -Delimiter ';' -Encoding UTF8)
$idx = @{}; foreach ($r in $col) { $idx[$r.chave] = $r }
$am = @(Import-Csv -Path (Join-Path $aqui 'amostras.csv') -Delimiter ';' -Encoding UTF8 | Where-Object { $_.item -eq '4' })
function LinhaCsv($r) { return ("CSV: preco={0} area_util={1} area_total={2} rua='{3}' n='{4}' cep={5} bairro_site={6} cond={7} iptu_mes={8} iptu_inf='{9}' q={10} b={11} s={12} v={13} andar={14} lat={15} lon={16} anunciante='{17}' publicado={18} atualizado={19} tipo={20} link={21}" -f $r.preco, $r.area_util, $r.area_total, $r.rua, $r.numero, $r.cep, $r.bairro_site, $r.condominio_mes, $r.iptu_mes, $r.iptu_informado, $r.quartos, $r.banheiros, $r.suites, $r.vagas, $r.andar, $r.lat, $r.lon, $r.anunciante, $r.publicado_em, $r.atualizado_em, $r.tipo, $r.link) }

Write-Output ''
Write-Output '===== ITEM 4 - VivaReal (listings?id=) ====='
$idsVR = @($am | Where-Object { $_.chave -like 'VIVAREAL_*' } | ForEach-Object { $_.chave -replace '^VIVAREAL_', '' })
$url = 'https://glue-api.vivareal.com/v2/listings?id=' + ($idsVR -join ',') + '&size=' + $idsVR.Count + '&includeFields=search(result(listings(listing(id,status,title,pricingInfos,usableAreas,totalAreas,address,updatedAt,createdAt,bedrooms,bathrooms,suites,parkingSpaces,unitFloor,unitTypes,unitSubTypes),account(name))),totalCount)'
$arq = Join-Path $http 'vr-ids.json'
$code = Get-Curl $url $arq $hdrVR
Write-Output ("  HTTP={0}" -f $code.Split('|')[0])
if (Test-Path $arq) {
    $o = Ler $arq
    $lst = @(Campo (Campo (Campo $o 'search') 'result') 'listings')
    Write-Output ("  totalCount={0} | devolvidos={1}" -f (Campo (Campo $o 'search') 'totalCount'), $lst.Count)
    foreach ($it in $lst) {
        $L = Campo $it 'listing'; $ad = Campo $L 'address'; $pi = @(Campo $L 'pricingInfos')
        $sale = $pi | Where-Object { (Campo $_ 'businessType') -eq 'SALE' } | Select-Object -First 1
        $pt = Campo $ad 'point'
        $id = [string](Campo $L 'id')
        Write-Output ("  -- id {0}" -f $id)
        Write-Output ("  SITE: status={0} preco={1} cond={2} yearlyIptu={3} iptuPeriod={4} usableAreas={5} totalAreas={6} rua='{7}' n='{8}' cep={9} bairro={10} q={11} b={12} s={13} v={14} andar={15} lat={16} lon={17} aprox=({18},{19}) precision={20} conta='{21}' createdAt={22} updatedAt={23} unitTypes={24} subTypes={25}" -f (Campo $L 'status'), (Campo $sale 'price'), (Campo $sale 'monthlyCondoFee'), (Campo $sale 'yearlyIptu'), (Campo $sale 'iptuPeriod'), (Ser (Campo $L 'usableAreas')), (Ser (Campo $L 'totalAreas')), (Campo $ad 'street'), (Campo $ad 'streetNumber'), (Campo $ad 'zipCode'), (Campo $ad 'neighborhood'), (Ser (Campo $L 'bedrooms')), (Ser (Campo $L 'bathrooms')), (Ser (Campo $L 'suites')), (Ser (Campo $L 'parkingSpaces')), (Campo $L 'unitFloor'), (Campo $pt 'lat'), (Campo $pt 'lon'), (Campo $pt 'approximateLat'), (Campo $pt 'approximateLon'), (Campo $ad 'precision'), (Campo (Campo $it 'account') 'name'), (Campo $L 'createdAt'), (Campo $L 'updatedAt'), (Ser (Campo $L 'unitTypes')), (Ser (Campo $L 'unitSubTypes')))
        Write-Output ('  ' + (LinhaCsv $idx["VIVAREAL_$id"]))
    }
}
# links VivaReal das 2 linhas: HTTP
foreach ($id in $idsVR) { $r = $idx["VIVAREAL_$id"]; $c = Get-Curl $r.link (Join-Path $http "vr-pag-$id.html"); Write-Output ("  link {0}: HTTP={1}" -f $id, $c.Split('|')[0]) }

Write-Output ''
Write-Output '===== ITEM 4 - QuintoAndar (pagina do anuncio ao vivo + JSON salvo) ====='
$idsQA = @($am | Where-Object { $_.chave -like 'QUINTOANDAR_*' } | ForEach-Object { $_.chave -replace '^QUINTOANDAR_', '' })
foreach ($id in $idsQA) {
    $arq = Join-Path $http "qa-pag-$id.html"
    $ok = $false
    for ($t = 1; $t -le 3; $t++) {
        $code = Get-Curl ("https://www.quintoandar.com.br/imovel/{0}/comprar" -f $id) $arq @() -L
        $html = if (Test-Path $arq) { [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) } else { '' }
        $m = [regex]::Match($html, '<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', 'Singleline')
        if ($m.Success) {
            $nd = $js.DeserializeObject($m.Groups[1].Value)
            $hi = Campo (Campo (Campo (Campo (Campo $nd 'props') 'pageProps') 'initialState') 'house') 'houseInfo'
            if ((Campo $hi 'id')) { $ok = $true; break }
        }
        Start-Sleep -Seconds 3
    }
    Write-Output ("  -- id {0}: HTTP/url={1} | pagina com houseInfo={2} (tentativas {3})" -f $id, $code, $ok, $t)
    if ($ok) {
        $ad = Campo $hi 'address'; $cd = Campo $hi 'condominium'; $rf = Campo $hi 'rangeFloor'
        $lst = @(Campo $hi 'listings'); $sale = $lst | Where-Object { (Campo $_ 'businessContext') -eq 'SALE' } | Select-Object -First 1
        Write-Output ("  SITE: salePrice={0} area={1} rua='{2}' n='{3}' cep={4} bairro={5} condoPrice={6} iptu={7} q={8} b={9} s={10} vagas={11} rangeFloor={12} lat={13} lng={14} type={15} status={16} firstPub={17} lastPub={18}" -f (Campo $hi 'salePrice'), (Campo $hi 'area'), (Campo $ad 'street'), (Campo $cd 'number'), (Campo $ad 'zipCode'), (Campo $ad 'neighborhood'), (Campo $hi 'condoPrice'), (Campo $hi 'iptu'), (Campo $hi 'bedrooms'), (Campo $hi 'bathrooms'), (Campo $hi 'suites'), (Campo $hi 'parkingSpaces'), (Ser $rf), (Campo $ad 'lat'), (Campo $ad 'lng'), (Campo $hi 'type'), (Campo $sale 'status'), (Campo $sale 'firstPublicationDate'), (Campo $sale 'lastPublicationDate'))
    }
    # JSON salvo pelo coletor
    $salvo = Join-Path $dados "json\quintoandar\$id.json"
    if (Test-Path $salvo) {
        $nd2 = Ler $salvo
        $hi2 = Campo (Campo (Campo (Campo (Campo $nd2 'props') 'pageProps') 'initialState') 'house') 'houseInfo'
        $ad2 = Campo $hi2 'address'; $cd2 = Campo $hi2 'condominium'
        Write-Output ("  JSON SALVO (19:1x): salePrice={0} area={1} rua='{2}' n='{3}' cep={4} condoPrice={5} iptu={6} q={7} b={8} vagas={9} rangeFloor={10} lat={11} lng={12}" -f (Campo $hi2 'salePrice'), (Campo $hi2 'area'), (Campo $ad2 'street'), (Campo $cd2 'number'), (Campo $ad2 'zipCode'), (Campo $hi2 'condoPrice'), (Campo $hi2 'iptu'), (Campo $hi2 'bedrooms'), (Campo $hi2 'bathrooms'), (Campo $hi2 'parkingSpaces'), (Ser (Campo $hi2 'rangeFloor')), (Campo $ad2 'lat'), (Campo $ad2 'lng'))
    } else { Write-Output "  JSON salvo nao encontrado: $salvo" }
    Write-Output ('  ' + (LinhaCsv $idx["QUINTOANDAR_$id"]))
}

Write-Output ''
Write-Output '===== ITEM 4 - Chaves na Mao (/api/realestate/details/) ====='
$idsCNM = @($am | Where-Object { $_.chave -like 'CHAVESNAMAO_*' } | ForEach-Object { $_.chave -replace '^CHAVESNAMAO_', '' })
foreach ($id in $idsCNM) {
    $arq = Join-Path $http "cnm-det-$id.json"
    $code = Get-Curl ("https://www.chavesnamao.com.br/api/realestate/details/?id={0}" -f $id) $arq
    Write-Output ("  -- id {0}: HTTP={1}" -f $id, $code.Split('|')[0])
    if (Test-Path $arq) {
        $o = Ler $arq
        $pr = Campo $o 'prices'; $lo = Campo $o 'location'; $st = Campo $lo 'street'; $ar = Campo $o 'area'; $gp = Campo $lo 'geoposition'
        $desc = [string](Campo $o 'description'); $iptuDesc = [regex]::Match($desc, '(?i)iptu[^.;\n]{0,80}').Value
        Write-Output ("  SITE: active={0} rawPrice={1} main='{2}' condominiumFee='{3}' iptuValue='{4}' area.useful={5} area.total={6} rua='{7}' n='{8}' cep={9} bairro={10} geo={11} realtyType={12} category={13} q={14} b={15} suites={16} garages={17} publisher='{18}' createdAt={19} updatedAt={20} url={21}" -f (Campo $o 'active'), (Campo $pr 'rawPrice'), (Campo $pr 'main'), (Campo $pr 'condominiumFee'), (Campo $pr 'iptuValue'), (Campo $ar 'useful'), (Campo $ar 'total'), (Campo $st 'name'), (Campo $st 'addressNumber'), (Campo $lo 'zipCode'), (Campo (Campo $lo 'neighborhood') 'name'), (Ser $gp), (Campo (Campo $o 'realtyType') 'name'), (Campo $o 'category'), (Ser (Campo $o 'bedrooms')), (Ser (Campo $o 'bathrooms')), (Ser (Campo $o 'suites')), (Ser (Campo $o 'garages')), (Campo (Campo $o 'publisher') 'name'), (Campo $o 'createdAt'), (Campo $o 'updatedAt'), (Campo $o 'url'))
        Write-Output ("  SITE descricao (trecho IPTU): '{0}'" -f $iptuDesc)
    }
    Write-Output ('  ' + (LinhaCsv $idx["CHAVESNAMAO_$id"]))
}
Write-Output ''
Write-Output ("fim: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
