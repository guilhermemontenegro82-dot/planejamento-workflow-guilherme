# Gera os dois sons de sino do mod "sino-avisos" (WAV 16 bits, mono, 22050 Hz).
#   decisao.wav : dois toques iguais e agudos ("ding-ding"), pede atenção
#   fim.wav     : três notas subindo (dó-mi-sol), sino mais grave, "concluído"
param([Parameter(Mandatory)][string]$Destino)

$rate = 22050

function Sino([double]$freq, [double]$dur, [double]$vol) {
    # Sino = fundamental + parciais inarmônicas com decaimento exponencial
    $n = [int]($rate * $dur)
    $s = New-Object double[] $n
    $parciais = @(@(1.0, 1.0, 3.0), @(2.0, 0.5, 4.5), @(2.76, 0.35, 6.0), @(5.4, 0.2, 9.0))
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $rate
        $v = 0.0
        foreach ($p in $parciais) {
            $v += $p[1] * [math]::Exp(-$p[2] * $t) * [math]::Sin(2 * [math]::PI * $freq * $p[0] * $t)
        }
        $ataque = [math]::Min(1.0, $t / 0.004)
        $s[$i] = $v * $vol * $ataque / 2.05
    }
    return ,$s
}

function Mistura([int]$total, $notas) {
    # $notas: lista de @(inicioSegundos, amostras)
    $m = New-Object double[] $total
    foreach ($nt in $notas) {
        $ini = [int]($nt[0] * $rate)
        $a = $nt[1]
        for ($i = 0; $i -lt $a.Length -and ($ini + $i) -lt $total; $i++) { $m[$ini + $i] += $a[$i] }
    }
    return ,$m
}

function SalvaWav([string]$caminho, [double[]]$amostras) {
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter($ms)
    $dados = $amostras.Length * 2
    $w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $dados))
    $w.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $w.Write([int]16)
    $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2))
    $w.Write([int16]2); $w.Write([int16]16)
    $w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$dados)
    foreach ($x in $amostras) {
        $c = [math]::Max(-1.0, [math]::Min(1.0, $x))
        $w.Write([int16]([math]::Round($c * 30000)))
    }
    $w.Flush()
    [IO.File]::WriteAllBytes($caminho, $ms.ToArray())
}

New-Item -ItemType Directory -Force $Destino | Out-Null

# Decisão / aprovação: "ding-ding" agudo (Lá5 = 880 Hz), dois toques iguais
$ding = Sino 880 0.9 0.9
SalvaWav (Join-Path $Destino 'decisao.wav') (Mistura ([int]($rate * 1.25)) @(@(0.0, $ding), @(0.28, $ding)))

# Fim de tarefa: dó-mi-sol (C5-E5-G5), mais grave e longo
$c = Sino 523.25 1.6 0.7; $e = Sino 659.25 1.6 0.7; $g = Sino 783.99 1.8 0.75
SalvaWav (Join-Path $Destino 'fim.wav') (Mistura ([int]($rate * 2.4)) @(@(0.0, $c), @(0.18, $e), @(0.36, $g)))

Get-ChildItem $Destino -Filter *.wav | Select-Object Name, Length
