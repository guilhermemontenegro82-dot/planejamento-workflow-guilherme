---
name: orcamento-ep-formatacao-da-planilha
description: "Quarta etapa do pipeline de orçamento EP Engenharia: aplica a formatação visual da planilha — cores e fontes por tipo de linha, altura recalculada, rodapé replicado célula a célula do modelo (incluindo a borda diferente do último SUB TOTAL), quadro de m² sem resíduo, print_area em duas faixas. A outra etapa com histórico de erro frequente, ao lado de quantitativo — a maioria dos bugs documentados vem de recriar estilo 'de cabeça' em vez de capturar do modelo real. Não recalcula fórmulas nem gera prova em PDF — isso é do Chequer Técnico, de propósito. Acionada pelo Agente Orquestrador — Orçamentos EP depois que Quantitativo é aprovado."
---

# Skill 4 — Formatação da Planilha

## Quando invocar

Depois que a Skill 3 — Quantitativo for aprovada pelo Chequer de Conteúdo. A planilha
já tem estrutura, texto e números certos — falta só o visual bater com o padrão EP.

## O que esta etapa NÃO faz

Não recalcula fórmulas nem gera a prova em PDF de conferência — isso é
propositalmente do Chequer Técnico, numa passada separada, para não ser a mesma
execução que aplicou a formatação também dizendo que ela está certa. Não escreve
descrição, não mede quantidade, não precifica.

## Regra central: capturar estilo do modelo, nunca redigitar de cabeça

Mesmo princípio da Skill 2 (preservar fórmula), aplicado a formatação: sempre capturar
o estilo real do arquivo de referência célula a célula (fonte, fill, borda,
alinhamento, número) antes de escrever — nunca redigitar cor ou borda de memória. É
aqui que mora a maioria dos erros já documentados desta etapa.

## Inputs esperados

- Planilha já com quantidades preenchidas (saída da Skill 3).
- A planilha modelo original, para captura de estilo célula a célula — usar
  **exatamente o arquivo que a Skill 2 registrou como usado** (nome/data de
  modificação na saída dela). Não reabrir a pasta "Orçamento" e resolver de novo:
  se por algum motivo houver um arquivo diferente lá agora, isso é uma inconsistência
  para sinalizar, não para silenciosamente adotar como novo modelo no meio do
  pipeline.

## Passo a passo

### 1. Título de grupo (X.0)
Fundo cinza `FFA9ABAE`, negrito, caixa alta. Se o nome do grupo for longo, forçar
`wrap_text=True` (o estilo copiado do modelo às vezes vem com `wrap_text=False`
porque os grupos originais eram curtos) e calcular a altura da linha a partir do
número de caracteres — do contrário o texto fica cortado nas duas pontas, porque o
Excel/LibreOffice recorta texto centralizado dentro da altura padrão sem quebrar.

### 2. Linhas de subitem
Sem fill (`PatternFill(fill_type=None)`), sem negrito, Calibri 11 preto
(`FF000000`). **Altura de linha**: nunca herdar de outra linha do template — sempre
recalcular a partir do texto real: `linhas = ceil(len(texto) / largura_coluna_em_caracteres)`,
`altura = linhas * 14.4`, usando a largura da coluna C (ou C:D combinada quando
mesclada, como no rodapé).

### 3. Linhas de SUB TOTAL

**Corrigido em 04/08/2026 depois de ler o modelo célula a célula (`XX - Planilha - Obra
XXXXX - Bairro - R00.xlsx`) — a descrição antiga deste item estava errada e nunca tinha
sido conferida contra o arquivo real.** O que o modelo realmente tem, confirmado em
todas as 15 linhas de SUB TOTAL do modelo:

- **Sem fill em nenhuma célula da linha** (nem em C, nem em nenhuma outra) — a versão
  antiga desta regra dizia "fundo bege `FFF8F7F3`", isso não existe no modelo.
- Coluna C ("SUB TOTAL"): **negrito, tamanho 10** (menor que o padrão 11 do resto da
  planilha) — **não é itálico** (a versão antiga dizia itálico sem negrito, invertido).
- Colunas H e I: negrito **e fonte vermelha** (`FF0000`) — detalhe que não estava
  documentado antes.
- Coluna J (o valor do subtotal): fill de tema (`theme3`, tint `0.6` — não é uma cor RGB
  fixa, é relativa ao tema do workbook), negrito.
- Colunas B, D, E, F, G: sem negrito, sem cor especial (nas linhas do meio — ver item 4
  para a última linha, que é diferente também nisso).
- Sem numeração na coluna B (isso já estava certo).

### 4. O último SUB TOTAL é diferente — não usar o mesmo estilo dos do meio
Todo SUB TOTAL do meio da planilha usa borda inferior "aberta" (`None`), porque o
cabeçalho cinza do grupo seguinte já fecha a separação visualmente. **O último SUB
TOTAL (o que encosta direto no Obs1) tem borda inferior "medium" em todas as colunas
B–J**, fechando a caixa por completo antes do rodapé começar. Aplicar o estilo do
meio nessa linha deixa o encontro com o Obs1 com aparência desalinhada — capturar o
estilo da última linha de SUB TOTAL do próprio modelo, separadamente, e usar só ali.

**Diferença adicional confirmada em 04/08/2026**: nas linhas do meio, só H e I ficam em
vermelho negrito (item 3). Na **última** linha de SUB TOTAL, **B, D, E, F, G também
ficam vermelho negrito** — não é só a borda que muda, a cor de fonte se espalha para
mais colunas. Capturar o estilo da última linha do modelo inteiro, célula a célula,
em vez de reaproveitar o estilo de uma linha do meio e só trocar a borda.

### 5. Rodapé — replicar célula a célula, não recriar do zero
Estrutura fixa de 3 linhas (Obs1/Total, Obs2/Total, Obs3/Total), sem linha em branco
entre o último SUB TOTAL e o Obs1 — se sobrar uma linha vazia ali, o bloco fica com um
"buraco" visual no meio.

**Caixa de rótulo + valor: célula mesclada, não duas células separadas.** No modelo,
cada bloco ("TOTAL DE CUSTO (Mat e Mdo) OBRA CIVIL", "Impostos (emissão de NF –
X%)", "TOTAL") é uma única célula mesclada (ex.: `E:G`, `E:H` ou `E:I` da própria
linha, junto com o `C:D` do rótulo Obs ao lado), rótulo e valor `R$` dentro da mesma
caixa, valor alinhado à direita. Capturar o range de mesclagem do modelo
(`ws.merged_cells.ranges`) e replicar exatamente — se essas células forem escritas
como célula de rótulo + célula de valor separadas, a caixa perde a aparência de
barra contínua e sai visualmente partida ao meio. **Bug confirmado em teste real
(04/08/2026)**: no arquivo gerado, as 6 mesclagens desse bloco (as 3 linhas × rótulo
+ total) simplesmente não existiam — o `mergeCells` do arquivo não tinha nenhuma
delas.

**Fill não é igual nas três caixas — não presumir que as três repetem o mesmo
estilo.** No modelo: "TOTAL DE CUSTO" = fill sólido cinza `FFA9ABAE`; "Impostos" =
fill sólido de tema, branco com tint `-0.05` (o "Branco, Fundo 1, Mais Escuro 5%" do
seletor de cor do Excel — não é literalmente sem fill, mas é bem mais claro que o
cinza do TOTAL DE CUSTO e não pode usar a mesma cor); "TOTAL" = fill sólido azul
`FF307ABD`. A caixa do meio é só informativa, não é um total calculado (ver Skill 2:
"sem linha de impostos como cálculo"), e é fácil assumir por engano que ela repete o
estilo de uma das outras duas. **Bug confirmado em teste real (04/08/2026)**: a
caixa de Impostos saiu com o mesmo `fillId` (cinza `FFA9ABAE`) da caixa de TOTAL DE
CUSTO — capturar a cor de cada uma das 3 caixas separadamente do modelo, nunca
reaproveitar a cor já capturada de uma vizinha.

**Tamanho de fonte maior nos valores finais — confirmado 04/08/2026**: o valor de
"TOTAL DE CUSTO" (célula J da linha) e **toda a linha de "TOTAL"** (não só o valor,
o rótulo também) usam fonte tamanho **14, negrito** — maior que o padrão 11 do resto
da planilha. "Impostos" fica no tamanho padrão (11). Capturar o `sz` real de cada
célula do modelo em vez de aplicar um tamanho de fonte uniforme no bloco inteiro.

### 6. Robustez de borda contra o recálculo
O recálculo de fórmulas (LibreOffice, feito pelo Chequer Técnico depois) reabre e
resalva o arquivo, e esse processo pode perder a cor explícita de bordas que estavam
com cor automática/indexada no XML original — a borda continua existindo, mas sem
cor associada (costuma renderizar como preto automático de qualquer jeito, mas para
eliminar ambiguidade): ao capturar estilo de borda para linhas críticas (SUB TOTAL,
rodapé), forçar cor RGB explícita (`FF000000`) em vez de confiar na cor herdada.

### 7. Quadro "Estudo de valor por m²"
Neutralizar fill residual herdado do template (`PatternFill(fill_type=None)`) — essa
área costuma carregar cores cinza/azul de linhas antigas do modelo sem relação com o
conteúdo novo. Aplicar apenas borda fina (`thin`) nas células com rótulo/valor.

**Conferir também as células sem rótulo/valor ao redor do quadro, não só as que têm
conteúdo — esse quadro não deve ter nenhuma célula preenchida (fill), só borda
fina.** **Causa raiz confirmada em teste real (04/08/2026)**: no arquivo gerado, as
linhas do quadro de m² saíram fisicamente próximas/coladas às linhas do bloco
Obs/Total (sem as linhas em branco de respiro que o modelo tem entre os dois
blocos), e a coluna E dessas linhas ficou com o **mesmo fill cinza/branco-tint/azul
das 3 caixas do bloco Obs/Total (mesmos `fillId` 5/7/6)**, mesmo estando vazia —
sinal de que essas linhas foram construídas reaproveitando o estilo das linhas do
bloco Obs/Total em vez de partir de uma linha sem fill nenhum. Se aparecer
cinza/branco-tint/azul em qualquer célula sem rótulo/valor nesse quadro, é esse bug:
limpar o fill (`PatternFill(fill_type=None)`) de toda a região do quadro antes de
aplicar borda fina só nas células de rótulo/valor — não presumir que só as células
"correntes" precisam de limpeza.

### 8. `print_area` — recalcular sempre, nunca herdar do modelo

**Bug grave confirmado em teste real (04/08/2026, obra "Escola IPE", 3 planilhas geradas —
Bloco 1, Bloco 2, Guarita)**: as 3 saíram com `print_area = $B$3:$J$124`, o valor **idêntico**
do modelo, mesmo o conteúdo real de cada uma terminando muito antes (quadro de m² na linha 52
do Bloco 1, por exemplo) — ou seja, o `print_area` não estava sendo recalculado, só copiado
do modelo sem alteração. Resultado: a exportação para PDF sai com **dezenas de páginas em
branco** depois do conteúdo real (linha 53 até 124), porque as linhas entre o fim do
conteúdo e a linha 124 existem na planilha (herdadas do modelo, só não têm mais dado) mas o
`print_area` continua incluindo todas elas.

**Regra corrigida**: `ws.print_area` **sempre** recalculado a partir da última linha real do
quadro "Estudo de valor por m²" desta planilha específica — nunca copiado do modelo, nem
quando o orçamento tem menos itens que ele (o caso que gerou o bug acima), nem quando tem
mais. "Recalcular só quando crescer além do modelo" (regra antiga) estava incompleto — o
orçamento **encolher** em relação ao modelo é tão comum quanto crescer, e precisa da mesma
correção.

**Resolvido 04/08/2026 — uma faixa só, e o quadro de m² fica fora de propósito.** Lendo o
modelo célula a célula: o `print_area` dele (`$B$3:$J$124`) termina **exatamente** na
última linha do bloco TOTAL (linha 124) — a linha logo antes do espaço em branco que
separa o rodapé do quadro "Estudo de valor por m²" (linhas 128-131). Isso não é acidente
nem regressão: o quadro de m² é uma ferramenta de análise interna do Guilherme, não faz
parte do orçamento entregue ao cliente, e por isso fica de propósito fora da área de
impressão. **Regra final**: `print_area = "B3:J<última linha do bloco TOTAL desta
planilha>"` — uma faixa só, terminando no fim do rodapé (Obs3/TOTAL), nunca incluindo o
quadro de m². Achar essa última linha lendo onde está o rótulo "TOTAL" (a última linha do
bloco Obs/Total) nesta planilha específica, não presumir um número fixo.

### 9. Varrer resíduo de formatação indevida
Conferir se algum subitem ficou com fill cinza ou azul indevido, herdado do template
por não ter sido limpo corretamente — corrigir com `PatternFill(fill_type=None)`.

## Saída esperada (o que entrega para a Skill 5)

Planilha com toda a formatação aplicada conforme o padrão EP, pronta para receber
preço — nenhuma verificação de recálculo ainda (isso é do Chequer Técnico, na
sequência).

## Checklist antes de passar para a Skill 5

- [ ] Título de grupo: cinza, negrito, caixa alta, `wrap_text` e altura corretos
- [ ] Subitem: sem fill, sem negrito, altura recalculada do texto real
- [ ] SUB TOTAL: bege, itálico, sem numeração
- [ ] Último SUB TOTAL com borda "medium" diferente dos do meio
- [ ] Rodapé replicado célula a célula, sem linha em branco antes do Obs1
- [ ] Caixas de rótulo+valor do rodapé (TOTAL DE CUSTO / Impostos / TOTAL) mescladas
      como no modelo, não partidas em célula de rótulo + célula de valor
- [ ] Caixa "Impostos" com fill branco-tint (não o cinza sólido da caixa de TOTAL DE
      CUSTO nem o azul da caixa de TOTAL — as 3 cores capturadas separadamente)
- [ ] Bordas críticas com cor RGB explícita, não herdada
- [ ] Quadro de m² sem fill/borda residual, incluindo células sem rótulo/valor ao
      redor dos rótulos
- [ ] SUB TOTAL sem fill em nenhuma célula (não bege); coluna C negrito tamanho 10;
      H/I vermelho negrito; J com fill de tema; última linha com B,D,E,F,G também em
      vermelho negrito, não só H/I
- [ ] TOTAL DE CUSTO (valor) e toda a linha de TOTAL em fonte tamanho 14 negrito
- [ ] `print_area` = uma faixa só, terminando na última linha do bloco TOTAL **desta**
      planilha (nunca no do modelo por herança, e nunca incluindo o quadro de m²)
- [ ] Nenhum subitem com fill indevido remanescente

## Log de mudanças

- **04/08/2026** — primeiro teste real do pipeline novo (planilha "865 - MC -
  Laranjeiras", comparada célula a célula via XML contra o modelo "XX - Planilha -
  Obra XXXXX - Bairro - R00") confirmou 3 bugs de formatação no rodapé/quadro de m²:
  (1) as 6 mesclagens de célula do bloco Obs/Total (rótulo+valor por linha)
  simplesmente não existiam no arquivo gerado — saía partido em vez de "barra"
  contínua; (2) a caixa "Impostos" saiu com o mesmo `fillId` cinza da caixa "TOTAL DE
  CUSTO" em vez do branco-tint próprio dela; (3) o quadro de m² saiu com fill
  cinza/branco-tint/azul residual (mesmos `fillId` do bloco Obs/Total) em células
  vazias, porque as linhas do quadro foram construídas coladas ao bloco Obs/Total e
  reaproveitando o estilo dele. Passos 5 e 7 atualizados com as regras explícitas,
  os valores de cor reais e a causa raiz, para não se repetir.
- **04/08/2026 (segunda rodada)** — teste real com obra "Escola IPE" (3 planilhas:
  Bloco 1, Bloco 2, Guarita) achou um bug mais grave: as 3 saíram com `print_area`
  idêntico ao do modelo (`$B$3:$J$124`), nunca recalculado — o conteúdo real termina
  bem antes (ex.: linha 52 no Bloco 1), então a exportação em PDF sai com dezenas de
  páginas em branco depois do orçamento. Passo 8 reescrito: a regra antiga só mandava
  recalcular quando o orçamento *crescia* além do modelo — não cobria o caso, muito
  mais comum, de encolher.
- **04/08/2026 (terceira rodada)** — a pedido do Guilherme, lido o modelo
  (`XX - Planilha - Obra XXXXX - Bairro - R00.xlsx`) célula a célula, direto do XML,
  em vez de confiar na descrição em prosa herdada da skill antiga. Achados: (1) a
  regra de SUB TOTAL estava errada desde sempre — não existe fill bege no modelo, a
  coluna C é negrito tamanho 10 (não itálico), H/I são vermelho negrito, e a última
  linha espalha o vermelho negrito para B/D/E/F/G também, não só H/I; (2) TOTAL DE
  CUSTO (valor) e a linha inteira de TOTAL usam fonte tamanho 14, nunca documentado
  antes; (3) resolvida a dúvida de uma faixa vs duas no `print_area` — o modelo exclui
  o quadro de m² do print de propósito (área de análise interna, não vai pro cliente),
  então a faixa correta é só `B3:J<última linha do TOTAL>`, nunca incluindo o quadro.
  Passos 3, 5 e 8 corrigidos. Nota: comparando contra a Skill 4 já em produção, os
  itens gerados (Bloco 1/2/Guarita) já tinham capturado corretamente o "sem fill" do
  SUB TOTAL da fonte real (a doc errada não contaminou a execução, só a documentação)
  — mas H/I saíram vermelho sem negrito (deveria ser vermelho **e** negrito), bug
  pequeno, real, também corrigido.
