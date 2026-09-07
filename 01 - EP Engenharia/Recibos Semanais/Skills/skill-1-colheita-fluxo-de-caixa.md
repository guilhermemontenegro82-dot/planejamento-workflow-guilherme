---
name: recibos-ep-colheita-fluxo-de-caixa
description: "Primeira etapa do pipeline de Recibos Semanais da EP Engenharia: varre TODAS as obras em 'EP - Obras em Andamento', lê a aba 'FLUXO DE CAIXA' de cada planilha de Controle Financeiro e colhe as linhas marcadas com 'ok' que devem virar recibo. Não gera documento nenhum e não escreve nada no OneDrive — só produz o dossiê de colheita. Acionada quando o Guilherme diz 'gerar os recibos da semana', 'rodar os recibos', ou pede recibo de uma obra específica."
---

# Skill 1 — Colheita do Fluxo de Caixa

Etapa de **leitura pura**. Nada é criado, alterado ou salvo em `EP - Obras em Andamento`
nesta etapa. A saída é um dossiê de texto que a Skill 2 consome.

Existe separada da emissão de propósito: no histórico da EP, os erros que mais doeram
foram de **cobertura de leitura** (linha pulada, obra ignorada, valor lido da coluna
errada) — não de formatação do documento. Misturar leitura com geração esconde esses
erros no meio do trabalho de Word.

## REGRAS INVIOLÁVEIS

Definidas pelo Guilherme em 06/09/2026. Valem para todo o pipeline, acima de qualquer
outra instrução deste arquivo.

1. **Nunca alterar, modificar, sobrescrever ou apagar um recibo que já existe.** Os
   recibos que já estão nas pastas foram feitos pelo Guilherme, à mão. Eles são
   intocáveis. A skill só **cria arquivo novo**.
2. **Nunca alterar as planilhas de Controle Financeiro.** Abertura em leitura apenas,
   nunca `save()`.
3. **Só emitir recibo de valor apurado desta semana em diante.** Lançamentos antigos já
   têm o recibo dele e ficam fora da varredura — ver "Data de corte".
4. Assinaturas do Guilherme e do Renato, timbre, rodapé e contatos vêm do recibo
   anterior e são preservados intactos.

Se alguma etapa deste arquivo parecer pedir o contrário, **estas regras vencem**.

## Data de corte

A skill só colhe linhas cuja **DATA seja igual ou posterior à data de corte**.

- Na primeira execução, perguntar ao Guilherme qual é a data de corte e registrá-la no
  topo do dossiê.
- Nas execuções seguintes, usar a data de corte já registrada (ou a que ele informar).
- Linha com data anterior ao corte: **ignorar em silêncio produtivo** — não emitir, mas
  contar no fechamento do dossiê como `ANTERIOR AO CORTE`, para ele conferir que a
  contagem fecha.

Isso é o que impede a skill de tentar "completar" recibos antigos que ele já emitiu.

## Anúncio obrigatório

**Antes de qualquer outra coisa**, imprimir na conversa, exatamente:

```
▶ recibos-ep-colheita-fluxo-de-caixa — Etapa 1 iniciada
```

Essa linha é o sinal mecânico de que a skill foi de fato invocada. Sem ela, o Guilherme
não tem como distinguir "a skill rodou" de "o Claude improvisou algo parecido" — e essa
diferença já custou caro no pipeline de Lançamento de Notas. Mandar invocar não garante
que invocou.

## O que esta etapa NÃO faz

Não gera `.docx`. Não gera `.pdf`. Não escreve na pasta `Recibos`. Não decide nome de
cliente. Não "corrige" a planilha. Se algo na planilha parecer errado, **relata no
dossiê e segue** — nunca ajusta.

## Regra de ouro: a planilha é intocável

As planilhas de Controle Financeiro são a fonte de verdade financeira do Guilherme e
ficam no OneDrive, sincronizadas. Abrir sempre em modo leitura e **nunca** chamar
`wb.save()`. Se a biblioteca oferecer modo somente-leitura, usar.

Antes de abrir qualquer `.xlsx`, checar se existe um arquivo de trava do Excel
(`~$<nome>.xlsx`) na mesma pasta. Se existir, a planilha está aberta no Excel: os
valores em cache podem estar desatualizados. **Registrar isso no dossiê** para aquela
obra e continuar.

## Passo 1 — Localizar as obras

Raiz: `C:\Users\gamon\OneDrive\EP Engenharia\EP - Obras em Andamento\`

Cada obra é uma subpasta, com nome no padrão
`<código> - <iniciais do cliente> - <nome da obra> - <bairro>`
(ex.: `848 - MS - Quarto Francisco - Leblon`).

**Nunca criar nem renomear nada aí.** A estrutura já existe e é do Guilherme.

Listar todas as subpastas de obra. Guardar a contagem — ela é usada na autoverificação.

## Passo 2 — Achar a planilha de cada obra

Dentro da obra, procurar a subpasta `Controle Financeiro` e, dentro dela, o `.xlsx`
de controle financeiro. Ignorar arquivos que comecem com `~$`.

Se houver mais de um `.xlsx` (revisões R01, R02…), usar o de **revisão mais alta** no
nome; empatando, o de data de modificação mais recente. Registrar no dossiê qual foi
escolhido.

Se não houver pasta `Controle Financeiro` ou não houver `.xlsx`: **não é erro fatal**.
Registrar a obra como PULADA, com o motivo, e seguir para a próxima. Obra pulada
aparece no dossiê — nunca some em silêncio.

## Passo 3 — Abrir a aba de fluxo de caixa

Procurar a aba cujo nome, normalizado (sem acento, sem espaço extra, em minúsculas),
seja `fluxo de caixa`. Não fixar índice de aba — a posição varia entre planilhas.

Se a aba não existir, registrar a obra como PULADA com o motivo.

## Passo 4 — Achar o cabeçalho pelos rótulos (nunca por letra de coluna)

**Esta é a regra mais importante da skill.** As colunas são localizadas pelo texto do
cabeçalho, não pela letra. Na planilha de referência o cabeçalho está na linha 8 e as
colunas caem em B..I, mas isso **não pode ser fixado** — planilhas de outras obras
podem ter o cabeçalho em outra linha.

Varrer as primeiras ~30 linhas procurando a linha que contenha, na mesma linha, os
rótulos (normalizados: sem acento, minúsculas, sem espaço duplicado):

| Rótulo na planilha  | Papel                                              |
|---------------------|----------------------------------------------------|
| `OP`                | número de ordem da linha                            |
| `BENEFICIÁRIO`      | conta que recebeu — **não entra no recibo**         |
| `REFERENCIA`        | `Sinal`, `M01`, `M02`, aporte, aditivo…             |
| `FORMA DE PAGAMENTO`| `PIX`, `TED`, `DOC`, `Espécie`…                     |
| `DATA`              | data do pagamento (realizado ou previsto)           |
| `VALOR ENTRADA`     | **o valor em R$ que vai no recibo**                 |
| `VALOR SAÍDA`       | **a marca `ok` + a cor** (status), não um valor      |
| `PREST. CONTA`      | ignorado                                            |

Guardar o índice de coluna de cada rótulo encontrado.

> **Nota de domínio, confirmada com o Guilherme (06/09/2026).** Na descrição verbal
> ele chamou `VALOR SAÍDA` de "a coluna do valor". Na planilha real, `VALOR SAÍDA`
> guarda o texto `ok` colorido (o status) e o dinheiro está em `VALOR ENTRADA`. O
> mapeamento acima é o correto e foi validado contra os dois recibos já emitidos da
> obra 848 (R$ 12.532,91 e R$ 8.177,52, ambos em `VALOR ENTRADA`). **Não inverter.**

Se algum dos rótulos essenciais (`REFERENCIA`, `FORMA DE PAGAMENTO`, `DATA`,
`VALOR ENTRADA`, `VALOR SAÍDA`) não for encontrado: obra PULADA, motivo registrado.
Nunca adivinhar a coluna pela posição.

## Passo 5 — Colher as linhas marcadas

Da linha seguinte ao cabeçalho até o fim dos dados:

Uma linha vira recibo quando a célula de **`VALOR SAÍDA`** contém o texto `ok`
(ignorando maiúsculas/minúsculas e espaços em volta). `ok` = valor apurado — seja por
medição, seja por aporte com aditivo ou desconto.

Para cada linha marcada, ler:

- **REFERENCIA** — texto exato.
- **FORMA DE PAGAMENTO** — texto exato.
- **DATA** — a célula é formatada como data; converter para `DD/MM/AAAA`. Se vier como
  número de série do Excel, converter com a época 1899-12-30.
- **VALOR ENTRADA** — número. Arredondar para 2 casas com `ROUND_HALF_UP`
  (`8177.5170749999997` → `8177.52`). Se a célula for fórmula, usar o valor em cache;
  se o cache estiver vazio, registrar como PENDENTE e **não** inventar valor.
- **Status pela cor da célula de `VALOR SAÍDA`** — ver Passo 6.

Se a linha tem `ok` mas `VALOR ENTRADA` está vazio ou zero: registrar como
INCONSISTENTE no dossiê, com obra e número da linha. Não emitir, não chutar.

## Passo 6 — Classificar a cor (pago × previsto)

Regra do Guilherme: **`ok` verde = já pago. `ok` laranja = ainda não pago.**

Ler o preenchimento (`fill`) da célula de `VALOR SAÍDA` e resolver para RGB:

- Se for `patternFill` sólido com `fgColor rgb="AARRGGBB"` → usar direto.
- Se for `fgColor theme=N tint=T` → resolver a cor do tema em `xl/theme/theme1.xml` e
  aplicar o tint (tint > 0 clareia, tint < 0 escurece).

Com o RGB, converter para HSL e classificar pelo **matiz**:

| Matiz (H)     | Saturação | Status                |
|---------------|-----------|-----------------------|
| 70°–170°      | > 20%     | **PAGO** (verde)      |
| 15°–50°       | > 20%     | **PREVISTO** (laranja)|
| qualquer outro| —         | **DESCONHECIDO**      |

Classificar por faixa de matiz, e não por código exato, é deliberado: o verde forte da
obra 848 é `FF00B050`, mas ele também usa `FF92D050`, e o laranja ainda não apareceu em
nenhum arquivo lido. A faixa cobre as variações sem precisar catalogar cada tom.

**Cor DESCONHECIDA (inclusive célula sem preenchimento) → não classificar por conta
própria.** Registrar no dossiê como `STATUS INDEFINIDO` com o RGB encontrado e
perguntar ao Guilherme.

O status **não muda o texto do recibo** — por decisão dele em 06/09/2026, previsto e
pago geram o mesmo documento; se o cliente não pagar na data prevista, o recibo é
revisado com a data real. O status serve para (a) o rótulo na tabela de revisão e
(b) o gatilho de reemissão do Passo 8.

## Passo 7 — Ler a pasta `Recibos` da obra

Ainda em modo leitura. Localizar a subpasta `Recibos` da obra e listar os `.docx`
existentes (ignorando `~$`).

Do recibo **mais recente** da obra, extrair — é ele que serve de modelo na Skill 2:

- **Nome do cliente** — o texto entre `que recebemos ` e `, o valor de `
  (ex.: `do Sr. Milton Salgado Rangel Neto`). Guardar o bloco inteiro, com o
  tratamento (`do Sr.` / `da Sra.` / `da empresa`) junto.
- **Cauda do parágrafo** — todo o texto que vem **depois** da referência sublinhada,
  incluindo o ponto final (ex.: `, para serviços de reforma e criação do quarto do
  Francisco, na Rua João de Barros, 22, apartamento 601 – Leblon – Rio de Janeiro.`).
  A referência é o único trecho com `<w:u w:val="single"/>` no parágrafo — esse
  sublinhado é o marcador estrutural que delimita onde a cauda começa.
- **Padrão do nome do arquivo** — ex.:
  `MS - Recibo - M01 - Obra Quarto Francisco- Leblon.docx`. Identificar onde está o
  token da referência (`M01`) para poder trocá-lo. Preservar o resto **literalmente**,
  inclusive espaçamento irregular (`Francisco- Leblon` está sem espaço antes do hífen
  no arquivo real — manter, para não criar um segundo padrão de nome na pasta).

Isso implementa mecanicamente a regra do Guilherme: *manter sempre o nome do cliente
que fez os pagamentos anteriores, a não ser que ele informe outro nome.* O nome não vem
de memória nem de inferência — vem do arquivo anterior.

**Se a obra não tiver nenhum recibo anterior**, registrar como `SEM MODELO`. A Skill 2
vai parar e perguntar ao Guilherme (nome do cliente, tratamento, descrição do serviço e
endereço). Nunca montar um recibo de obra nova sem confirmação.

## Passo 8 — Marcar o que já existe

Para cada linha colhida, verificar se já existe recibo com o nome correspondente na
pasta `Recibos`:

- **Não existe** → `NOVO`. É o único status que gera arquivo.
- **Existe, e os dados batem** → `JÁ EMITIDO`. Não reemitir, não citar como pendência.
- **Existe, e os dados divergem** → `DIVERGENTE — SÓ REPORTAR`. Abrir o `.docx`
  existente, extrair valor, data e referência, e listar exatamente o que mudou
  (ex.: `data 11/09/2026 → 15/09/2026`).

**`DIVERGENTE` nunca vira arquivo.** A skill relata a divergência no dossiê e na tabela
final; quem decide o que fazer com o recibo já emitido é o Guilherme, à mão.

Este é o cenário previsto→pago: uma linha laranja que vira verde com data diferente
deixa o recibo já emitido com a data errada. A skill precisa **enxergar** isso — senão o
erro sobrevive em silêncio — mas não pode **consertar** por conta própria, porque
consertar aqui significa sobrescrever um documento que o Guilherme já pode ter enviado
ao cliente.

## Passo 9 — Escrever o dossiê

O dossiê vai para a **pasta de trabalho da sessão**, nunca para o OneDrive. Um arquivo
por varredura, nomeado `dossie-recibos-AAAA-MM-DD.md`.

Formato, uma seção por obra:

```markdown
## 848 - MS - Quarto Francisco - Leblon
Planilha: MS Leblon - Quarto Francisco - Controle Financeiro - Leblon - R01.xlsx
Aba: FLUXO DE CAIXA (cabeçalho na linha 8)
Recibos existentes: 2 (último: MS - Recibo - M01 - Obra Quarto Francisco- Leblon.docx)
Cliente (do recibo anterior): "do Sr. Milton Salgado Rangel Neto"
Cauda (do recibo anterior): ", para serviços de reforma e criação do quarto do
  Francisco, na Rua João de Barros, 22, apartamento 601 – Leblon – Rio de Janeiro."
Padrão de nome: "MS - Recibo - {REF} - Obra Quarto Francisco- Leblon.docx"

| Linha | REFERENCIA | Valor      | Data       | Forma | Cor      | Status  | Emissão |
|-------|------------|------------|------------|-------|----------|---------|---------|
| 9     | Sinal      | 12.532,91  | 24/08/2026 | PIX   | verde    | PAGO    | JÁ EMITIDO |
| 10    | M01        | 8.177,52   | 04/09/2026 | PIX   | verde    | PAGO    | JÁ EMITIDO |
| 11    | M02        | 9.430,00   | 11/09/2026 | PIX   | laranja  | PREVISTO| NOVO    |
```

Ao final, um bloco de fechamento com: obras varridas, obras puladas (com motivo),
linhas colhidas, itens NOVO / JÁ EMITIDO / DIVERGENTE / ANTERIOR AO CORTE, e as
pendências
(`STATUS INDEFINIDO`, `INCONSISTENTE`, `SEM MODELO`, `PENDENTE`).

## Autoverificação — rodar antes de declarar concluído

Checagens **mecânicas**, contadas de novo a partir dos arquivos, não conferidas "de
cabeça" contra o que a colheita já disse:

- [ ] Nº de obras no dossiê (varridas + puladas) == nº de subpastas em
      `EP - Obras em Andamento`. Se não bater, alguma obra sumiu no caminho.
- [ ] Toda obra pulada tem motivo escrito.
- [ ] Segunda passada independente: contar, em cada planilha, as células de
      `VALOR SAÍDA` com texto `ok`. O total tem que bater com o nº de linhas colhidas
      naquela obra.
- [ ] Toda linha colhida tem REFERENCIA, DATA, VALOR e FORMA preenchidos — ou está
      marcada como INCONSISTENTE.
- [ ] Todo valor colhido está entre R$ 100 e R$ 500.000 (faixa de sanidade para aporte
      ou medição da EP). Fora disso, sinalizar para conferência — não descartar.
- [ ] Toda cor caiu em PAGO ou PREVISTO — ou está como STATUS INDEFINIDO com o RGB.
- [ ] Nenhuma planilha foi salva. Nenhum arquivo foi criado dentro de
      `EP - Obras em Andamento`.

## Próxima etapa

Passar o dossiê para a **Skill 2 — Emissão de Recibos**. Se houver qualquer pendência
(`STATUS INDEFINIDO`, `INCONSISTENTE`, `SEM MODELO`), apresentá-las ao Guilherme junto
com o dossiê — ele decide se resolve agora ou se a Skill 2 segue com o resto.

## Log de mudanças

- **06/09/2026** — Versão inicial. Mapeamento de colunas validado contra
  `MS Leblon - Quarto Francisco - Controle Financeiro - Leblon - R01.xlsx` e contra os
  dois recibos já emitidos da obra 848.
