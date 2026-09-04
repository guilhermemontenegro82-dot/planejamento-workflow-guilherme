#!/usr/bin/perl
# ============================================================
# Verificador da corrente do pipeline de Lançamento de Notas EP
#
# Confere MECANICAMENTE (rodando contra os arquivos reais, não por leitura)
# que o encadeamento entre as skills está íntegro. Rodar sempre depois de
# alterar qualquer skill deste pipeline, ANTES de declarar pronto.
#
# Uso:  perl _verificar-corrente.pl
# ============================================================
use strict; use warnings;
use utf8;                              # o próprio script tem acento e ▶
binmode(STDOUT, ':encoding(UTF-8)');   # senão o relatório sai truncado

my $dir = ".";
my %f;   # nome curto => conteúdo
for my $file (glob("$dir/*.md")) {
    next if $file =~ /00-LEIA-ME/;
    open(my $fh, '<:encoding(UTF-8)', $file) or next;
    local $/; my $txt = <$fh>; close $fh;
    my ($short) = $file =~ m{([^/\\]+)\.md$};
    $f{$short} = $txt;
}

my (@ok, @fail, @warn);
sub ok   { push @ok,   $_[0] }
sub fail { push @fail, $_[0] }
sub warn_{ push @warn, $_[0] }

# ---------- 1. Anúncio: cada skill/agente se anuncia, uma vez ----------
my %esperado_anuncio = (
    'skill-ep-leitor-notas'          => 'ep-leitor-notas — Etapa 1 iniciada',
    'agente-chequer-leitura'         => 'Agente Chequer de Leitura — Etapa 1.5 iniciada',
    'agente-chequer-classificacao'   => 'Agente Chequer de Classificação — Etapa 1.6 iniciada',
    'skill-ep-lancador-notas'        => 'ep-lancador-notas — Etapa 2 iniciada',
    'skill-ep-pintor-notas'          => 'ep-pintor-notas — Etapa 3 iniciada',
);
for my $arq (sort keys %esperado_anuncio) {
    my $linha = $esperado_anuncio{$arq};
    if (!exists $f{$arq})              { fail("[anúncio] arquivo ausente: $arq.md"); next }
    if ($f{$arq} =~ /\Q▶ $linha\E/)    { ok("[anúncio] $arq") }
    else                               { fail("[anúncio] $arq NÃO contém: ▶ $linha") }
}

# ---------- 2. Tokens: quem emite × quem exige ----------
# token => [regex, arquivo que EMITE, arquivos que precisam CITAR]
my @tokens = (
  [ 'Veredito [1.5]',  qr/\[1\.5\] CHEQUER DE LEITURA \.{5,} APROVADO/,
    'agente-chequer-leitura',
    ['skill-supervisor-lancamento-ep','skill-ep-lancador-notas'] ],

  [ 'Veredito [1.6]',  qr/\[1\.6\] CHEQUER DE CLASSIFICAÇÃO \.{3,} APROVADO/,
    'agente-chequer-classificacao',
    ['skill-supervisor-lancamento-ep','skill-ep-lancador-notas'] ],

  [ 'Certificado',     qr/CERTIFICADO DE VERIFICAÇÃO/,
    'skill-supervisor-lancamento-ep',
    ['skill-ep-lancador-notas'] ],

  [ 'Comprovante',     qr/COMPROVANTE DE ESCRITA/,
    'skill-ep-lancador-notas',
    ['skill-ep-pintor-notas'] ],
);
for my $t (@tokens) {
    my ($nome, $re, $emissor, $consumidores) = @$t;
    if (($f{$emissor}//'') =~ $re) { ok("[token] $nome emitido por $emissor") }
    else { fail("[token] $nome NÃO é emitido por $emissor — quem consome vai travar") }
    for my $c (@$consumidores) {
        if (($f{$c}//'') =~ $re) { ok("[token] $nome reconhecido em $c") }
        else { fail("[token] $nome ausente em $c — elo quebrado (o consumidor não sabe o que esperar)") }
    }
}

# ---------- 3. Supervisor repassa os tokens nos passos de invocação ----------
my $sup = $f{'skill-supervisor-lancamento-ep'} // '';
my ($p6) = $sup =~ /### 6\. Etapa 2(.*?)### 7\./s;
my ($p7) = $sup =~ /### 7\. Etapa 3(.*?)### 7\.1/s;
if (($p6//'') =~ /Certificado de Verificação/i) { ok("[repasse] passo 6 manda passar o Certificado ao Lançador") }
else { fail("[repasse] passo 6 NÃO manda passar o Certificado — o Lançador vai recusar escrever") }
if (($p7//'') =~ /Comprovante de Escrita/i) { ok("[repasse] passo 7 manda passar o Comprovante ao Pintor") }
else { fail("[repasse] passo 7 NÃO manda passar o Comprovante — o Pintor vai parar") }

# ---------- 4. Recusa: quem exige token tem instrução explícita de parar ----------
my %recusa = (
  'skill-ep-lancador-notas' => qr/PARE|Não vou escrever na planilha/,
  'skill-ep-pintor-notas'   => qr/pare\b|Parando aqui/i,
);
for my $arq (sort keys %recusa) {
    if (($f{$arq}//'') =~ $recusa{$arq}) { ok("[recusa] $arq tem instrução de parar sem o token") }
    else { fail("[recusa] $arq exige token mas NÃO diz o que fazer se faltar") }
}

# ---------- 5. Skills citadas por nome existem como arquivo ----------
my %existe = map { $_ => 1 } keys %f;
my %alias = (
  'ep-leitor-notas'=>'skill-ep-leitor-notas', 'ep-lancador-notas'=>'skill-ep-lancador-notas',
  'ep-pintor-notas'=>'skill-ep-pintor-notas', 'supervisor-lancamento-ep'=>'skill-supervisor-lancamento-ep',
);
for my $arq (sort keys %f) {
    # O changelog cita nomes antigos de propósito (histórico) — não conta como referência viva.
    my $corpo = $f{$arq}; $corpo =~ s/^## Log de mudanças.*//sm;
    my %vistos;
    while ($corpo =~ /`(ep-[a-z-]+|supervisor-lancamento-ep)`/g) { $vistos{$1}=1 }
    for my $ref (sort keys %vistos) {
        my $alvo = $alias{$ref} // '';
        next if $alvo && $existe{$alvo};
        fail("[referência] $arq cita `$ref`, que não existe como arquivo nesta pasta");
    }
}

# ---------- 6. Frontmatter mínimo ----------
for my $arq (sort keys %f) {
    if ($f{$arq} =~ /^---\s*\nname:/s) { ok("[frontmatter] $arq") }
    else { fail("[frontmatter] $arq sem bloco name/description no topo") }
}

# ---------- 7. Skill antiga ainda citada? (aviso, não erro) ----------
for my $arq (sort keys %f) {
    warn_("[legado] $arq ainda cita `lancamento-notas-obra-ep` — conferir se a skill antiga segue ativa")
      if $f{$arq} =~ /lancamento-notas-obra-ep/;
}

# ---------- Relatório ----------
printf "\n=== VERIFICAÇÃO DA CORRENTE — Lançamento de Notas EP ===\n\n";
printf "  OK .......... %d\n", scalar @ok;
printf "  FALHAS ...... %d\n", scalar @fail;
printf "  AVISOS ...... %d\n\n", scalar @warn;
print "  ✗ $_\n" for @fail;
print "\n" if @fail;
print "  ! $_\n" for @warn;
print "\n" if @warn;
if (!@fail) { print "  ✓ Corrente íntegra: todo token emitido tem consumidor, todo token\n";
              print "    exigido tem emissor, e o Supervisor repassa os dois.\n\n";
              print "  Lembrete: isto verifica a MONTAGEM, não a EXECUÇÃO. Se o Cowork\n";
              print "  pular uma etapa em tempo real, só a prestação de contas denuncia.\n\n"; }
else { print "  Corrija as falhas acima antes de instalar no Cowork.\n\n" }
exit(@fail ? 1 : 0);
