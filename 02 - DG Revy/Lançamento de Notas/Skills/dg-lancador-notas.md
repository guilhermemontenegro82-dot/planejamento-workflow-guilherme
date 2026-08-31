---
name: "dg-lancador-notas"
description: "Etapa 2 do pipeline \"Supervisor de lançamento DG\": recebe a lista de arquivos baixados e confirmados pelo dg-leitor-notas e lança cada item na aba LANÇAMENTO da planilha de controle financeiro da obra DG, resolvendo o fluxo multi-comprovante (orçamento → pix → nota fiscal chegando depois), marcando compras do Mercado Livre como \"Pendente\" e tratando aportes/espécie no caixa do Mestre. Não pinta linha (isso é dg-pintor-notas) nem organiza/numera os arquivos físicos (isso é dg-organizador-notas). Só deve ser chamada pela skill supervisor-lancamento-dg, com a lista já confirmada pelo usuário."
---

## Papel nesta pipeline

Etapa 2 do fluxo `supervisor-lancamento-dg`. Recebe a lista de arquivos já baixados e
identificados pelo `dg-leitor-notas` **e já confirmada pelo usuário** e escreve cada item na
aba LANÇAMENTO. Não pinta linha (isso é `dg-pintor-notas`) e não move/numera os arquivos na
pasta definitiva (isso é `dg-organizador-notas`) — mas decide o número de item (coluna B) que
o Organizador vai usar para nomear os arquivos.

## Regra de ouro — de onde vêm os dados

**Só escreva a partir de uma lista gerada pelo `dg-leitor-notas` nesta mesma execução do
Supervisor.** Lista vinda de conversa antiga/resumida → pare e peça pro Supervisor rodar o
`dg-leitor-notas` de novo.

## Regras de ouro (invioláveis)

1. **Nunca altere dados já lançados anteriormente** — nem valores, textos, datas ou cores de
   linhas antigas. Escreva só nas linhas novas.
2. **Nunca mexa em outras abas** (QUADRO FECHAMENTOS, FLUXO DE CAIXA etc.).
3. **Não altere a formatação existente**: as planilhas dessa família já vêm com linhas
   seguintes pré-formatadas bem além da última linha com dado — normalmente só escreva o valor,
   sem copiar estilo manualmente (confirme lendo o `number_format` de algumas linhas abaixo da
   última preenchida antes de começar). **Nunca rode recálculo via LibreOffice.**
4. **Nunca escreva a versão final da planilha direto no arquivo montado do computador do
   usuário sem passar por uma cópia local primeiro.** Copie o original pra uma pasta de
   trabalho local, edite essa cópia — o commit final por cima do arquivo original é feito pelo
   `dg-pintor-notas`, na última etapa.
5. **Antes de editar, confira se existe um `~$nome.xlsx`** na mesma pasta — indica planilha
   aberta no Excel do usuário. Se existir, avise que ele precisa fechar antes.

## Passo a passo

### 1. Localizar e preparar os arquivos

- Planilha na pasta conectada de controle financeiro da obra (raiz
  `Lançamento de notas fiscais - DG`).
- Copie a planilha pra uma pasta de trabalho local antes de editar. Edite essa cópia, nunca o
  arquivo original.
- Ordene os itens pela ordem cronológica das mensagens do WhatsApp (ou mtime, se vieram de uma
  pasta local).

### 2. Entender a aba LANÇAMENTO

- Cabeçalho na linha 7: B=ITEM, C=DESCRIÇÃO E RESUMO MATERIAL, D=FORNECEDOR, E=NOTA/RECIBO,
  F=DATA, G=VALOR NOTA, **H=MAT ou MDO** (deixe em branco), I=QUEM GASTOU.
- A coluna B já vem numerada (mesmo em linhas vazias) — **não renumere**. Ache a última linha
  com dado em C e continue na seguinte. Se algum item "desaparecer" da sequência (ex.: um
  comprovante de reembolso que só confirma quem pagou outro item, sem ser compra nova em si),
  **renumere para não deixar buraco** — documente que aquele número foi absorvido/mesclado com
  o item vizinho, em vez de deixar um número fantasma sem linha.
- M3/M4/M5 trazem a grafia exata dos nomes que ativam as fórmulas SUMIF: "Mestre", "Espécie",
  "$Mestre" — use sempre essa grafia na coluna I. "Espécie" e "$Mestre" são os casos raros de
  dinheiro em espécie — na dúvida de qual usar, pergunte ao usuário.
- **K8** traz a legenda "Caixa Mestre PIX" — a cor de preenchimento dessa célula já é a cor
  oficial da linha do Mestre (o `dg-pintor-notas` usa essa referência depois, você não precisa
  pintar nada agora).
- **K9** traz o valor fixo do caixa do Mestre daquela obra — releia sempre, varia de obra pra
  obra.

### 3. Escrever cada item

- **C — Descrição**: resumo do material, até 3 itens principais. Se o nome do arquivo indicar
  frete (comum em comprovantes de pagamento do Mercado Livre), inclua no final: "- Frete
  grátis" ou "- Frete R$ 12,99", etc.
- **D — Fornecedor**: nome da nota, com substituições fixas: "Bottino"/"Botino" → **Amoedo**;
  "BMB"/"BNB" (Material de Construção) → **Obramax**; "Eletrica Pontevedra" → **Pontevedra**.
  Recibo/pix/ted → nome de quem **recebeu**. Cuidado com nomes parecidos e parcialmente
  cortados na foto (ex.: "Lojas do Leme" vs "Tres Torres do Leme") — confira pelo CNPJ/endereço
  impressos no cupom. Não identificou? Pergunte.
- **E — Nota/Recibo**: critério:
  - Comprovante de **PIX/transferência bancária** sem venda associada → **NA**.
  - Cupom de **venda interna sem nota fiscal** ("Sequencial: SEM SEQDAV" + número de "Controle"
    no rodapé, sem QR code) → **SN** — o "Controle" NÃO é número de nota.
  - Cupom informal "Sem valor fiscal" mas com número de "Emissão" no cabeçalho → **use esse
    número** (sem zeros à esquerda), seguindo o padrão já usado pra essa mesma loja nos itens
    anteriores da planilha.
  - Cupom que É nota fiscal de verdade (QR code de consulta na Fazenda, ou "Nota Fiscal"/"NFC-e"
    em algum lugar) → **use o número impresso**, mesmo sem rótulo "NFC-e nº" — dê zoom no
    cabeçalho inteiro antes de decidir que não tem número.
  - Antes de decidir, **olhe como o mesmo fornecedor foi lançado nas linhas anteriores da mesma
    planilha** — critério mais confiável pra manter consistência.
  - Compra de **Mercado Livre** (PIX Marketplace / Mercado Pago IP LTDA) → D="Mercado Livre",
    E="Pendente", pinte D e E de amarelo sólido (FFFF00) — sinaliza que falta rodar a skill
    `notas-fiscais-ml` depois (Etapa 6 do Supervisor).
- **F — Data**: data real da compra/transferência (datetime, não texto).
- **G — Valor**: valor realmente pago (atenção a descontos sobre o total). Número puro.
- **H**: deixe em branco.
- **I — Quem gastou**: grafia exata da coluna M ("Guilherme" ou "Mestre" na maioria dos casos).
  **Reembolso a técnico não é o técnico na coluna I** — vai pra quem reembolsou (normalmente
  Guilherme).
- **Comprovante pix de pagador**: o nome do titular no comprovante nem sempre é quem realmente
  gastou (ex.: comprovantes em nome de "Diogo Garcia Lopes" já representaram o Guilherme,
  confirmado pelo contexto da mensagem). Se não for óbvio, pergunte.
- **Coluna A — REEMB**: se indicar reembolso (compra que o cliente vai reembolsar), escreva
  "REEMB" com fundo amarelo, copiando o estilo de uma linha REEMB existente. Confirme com o
  usuário se for a primeira vez numa obra.

### 4. Fluxo multi-comprovante (orçamento → pix → nota fiscal depois)

Quando o `dg-leitor-notas` sinalizar que um item tem mais de um arquivo relacionado (orçamento,
comprovante de pagamento, nota fiscal chegando depois — típico do fornecedor que manda
orçamento e depois oferece desconto no pix, com a NF só dias depois):

- Escreva **uma única linha** para a compra, não uma linha por arquivo.
- Use o **valor realmente pago** (do comprovante de pagamento/pix, que pode ter desconto em
  relação ao orçamento) na coluna G.
- Campo E segue a árvore de decisão acima — se ainda não tem NF nem é ML, geralmente fica como
  o número/controle do comprovante disponível no momento, ou "SN" se nenhum documento tiver
  número.
- **Avise ao Supervisor/entrega para o `dg-organizador-notas`** que esse item (número da coluna
  B) tem **múltiplos arquivos** a organizar — ex.: arquivo de orçamento, arquivo de pix, e
  (quando chegar) arquivo de nota fiscal. O Organizador vai nomeá-los com sufixo (ex.:
  `94-orcamento.jpg`, `94-pix.png`, `94-nf.pdf`), não sobrescrever um pelo outro.

### 5. Reparo em item já lançado (número de nota chegou depois)

Às vezes uma NF formal (PDF) chega no grupo dias depois de um item já lançado com "SN" (ex.:
"já lançado — lançar só numeração"):

1. Confira o **conteúdo** do PDF contra a descrição/fornecedor do item já lançado — não só a
   legenda da mensagem. Valor e data podem não bater 100% (a nota pode ser emitida dias depois
   da compra) — normal, mas **confirme com o usuário antes de aplicar** se a diferença for
   grande ou houver mais de um item candidato parecido.
2. Aplique o número na coluna E do item correto (sem mexer em mais nada da linha).
3. Avise ao `dg-organizador-notas` que o arquivo antigo (ex.: `65.jpg`) precisa ser substituído
   pelo novo PDF mantendo o mesmo número (`65.pdf`).

### 6. Aportes e dinheiro em espécie (caso raro)

Se aparecer um comprovante de aporte de caixa ou pagamento em espécie ao Mestre, **não lance
como compra normal** — confirme com o usuário se é "Espécie" ou "$Mestre" (colunas M4/M5) e
como registrar, documentando o padrão confirmado para a próxima vez.

### 7. Entregar para a próxima etapa

Ao terminar, informe ao Supervisor: caminho do arquivo local editado, lista de itens escritos
(número da linha/coluna B + arquivos associados a cada um, incluindo os casos multi-
comprovante), e quais itens ficaram "Pendente" (ML).

## Troubleshooting

| Problema | Solução |
|---|---|
| Arquivo `~$*.xlsx` na pasta | Planilha aberta no Excel — pedir para fechar antes de continuar |
| Apareceu um gasto em espécie | Caso raro — perguntar ao usuário e documentar o padrão confirmado |
| Apareceu um comprovante de reembolso a um técnico | O item de compra vai pra quem reembolsou (normalmente Guilherme) na coluna I — o comprovante em si não vira linha nova |

