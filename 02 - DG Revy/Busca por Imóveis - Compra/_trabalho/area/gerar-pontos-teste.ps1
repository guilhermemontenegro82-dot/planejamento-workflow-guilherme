# gerar-pontos-teste.ps1 — geocodifica os endereços de teste pelo próprio módulo (Get-Geocode: Nominatim + números de porta do OSM,
# cache em _dados\geocache.csv) e grava Áreas de interesse\poligonos\pontos-teste.csv (rua;numero;bairro;lat;lon;esperado;observacao).
$ErrorActionPreference = 'Stop'
$raiz = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra"
. "$raiz\Skills\scripts\area.ps1"
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$lista = @(
    # dentro
    @('Rua Visconde de Pirajá', '540', 'Ipanema', 'SIM'),
    @("Rua Garcia d'Ávila", '60', 'Ipanema', 'SIM'),
    @('Rua Francisco Otaviano', '61', 'Copacabana', 'SIM'),
    @('Avenida Rainha Elizabeth', '200', 'Copacabana', 'SIM'),
    @('Avenida Ataulfo de Paiva', '900', 'Leblon', 'SIM'),
    @('Rua Dias Ferreira', '100', 'Leblon', 'SIM'),
    @('Rua Prudente de Morais', '450', 'Ipanema', 'SIM'),
    @('Rua Cupertino Durão', '50', 'Leblon', 'SIM'),
    @('Rua Bulhões de Carvalho', '100', 'Copacabana', 'SIM'),
    # fora
    @('Rua Nascimento Silva', '200', 'Ipanema', 'NAO'),
    @('Rua Alberto de Campos', '25', 'Ipanema', 'NAO'),
    @('Rua Barão de Jaguaripe', '100', 'Ipanema', 'NAO'),
    @('Avenida Epitácio Pessoa', '1000', 'Ipanema', 'NAO'),
    @('Rua Redentor', '100', 'Ipanema', 'NAO'),
    @('Avenida Visconde de Albuquerque', '300', 'Leblon', 'NAO'),
    @('Rua Gilberto Cardoso', '50', 'Leblon', 'NAO'),
    @('Rua Timóteo da Costa', '100', 'Leblon', 'NAO'),
    @('Avenida Nossa Senhora de Copacabana', '900', 'Copacabana', 'NAO'),
    @('Rua Barata Ribeiro', '630', 'Copacabana', 'NAO'),
    @('Rua Almirante Saddock de Sá', '216', 'Ipanema', 'NAO'),
    # borda
    @('Rua Barão da Torre', '300', 'Ipanema', 'SIM|LIMITE'),
    @('Rua Humberto de Campos', '100', 'Leblon', 'SIM|LIMITE'),
    @('Rua Francisco Sá', '30', 'Copacabana', 'LIMITE')
)
$linhas = New-Object System.Collections.Generic.List[string]
$linhas.Add('rua;numero;bairro;lat;lon;esperado;observacao')
foreach ($e in $lista) {
    $g = Get-Geocode -Rua $e[0] -Numero $e[1] -Bairro $e[2]
    $obs = "geocode $($g.precisao) [$($g.origem)]: $($g.detalhe)" -replace '[;\r\n]', ','
    '{0,-38} {1,-5} -> {2,-11} {3} {4}  {5}' -f $e[0], $e[1], $g.precisao, (AreaFmt $g.lat 6), (AreaFmt $g.lon 6), $g.detalhe
    $linhas.Add(($e[0], $e[1], $e[2], (AreaFmt $g.lat 7), (AreaFmt $g.lon 7), $e[3], $obs) -join ';')
}
$saida = "$raiz\Áreas de interesse\poligonos\pontos-teste.csv"
[System.IO.File]::WriteAllText($saida, (($linhas -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
"gravado: $saida ($($lista.Count) pontos)"
