---
name: "ep-pintor-notas"
description: "Etapa 3 (final) do pipeline supervisor-lancamento-ep: recebe do ep-lancador-notas o arquivo local já com as linhas escritas + a lista original de itens, pinta cada linha na cor do técnico, confere tudo e devolve a planilha ao computador do usuário. Só deve ser chamada pelo supervisor-lancamento-ep."
---

## Papel nesta pipeline

Etapa 3 (final) do fluxo `supervisor-lancamento-ep`. Recebe do `ep-lancador-notas` o arquivo
local já com as linhas escritas + a lista original de itens (com valores). Pinta cada linha na
cor do técnico, confere tudo e devolve a planilha ao computador do usuário.

## 🔒 Antes de qualquer coisa — comprovante de escrita

Comece a resposta com esta linha, literal:

```
▶ ep-pintor-notas — Etapa 3 iniciada
```

Confirme que recebeu o **Comprovante de Escrita** emitido pelo `ep-lancador-notas` — o
bloco literal abaixo, com os campos preenchidos:

```
=== COMPROVANTE DE ESCRITA — ETAPA 2 ===
Obra / Arquivo local editado / Linhas escritas / Itens
Soma dos valores escritos (coluna G)
Certificado de Verificação recebido: SIM
=== FIM DO COMPROVANTE ===
```

**Sem o comprovante, pare** — não pinte, não confira, não devolva a planilha. Responda:

> Não recebi o Comprovante de Escrita do `ep-lancador-notas`. Não sei em qual arquivo
> nem em quais linhas devo trabalhar. Parando aqui.

**Esta skill não pode ser substituída por execução manual.** Em **27/08/2026**, num
lançamento real, a pintura e a conferência foram feitas "por script, replicando o que a
skill pede, mas sem carregar as instruções dela" — resultado: as regras desta skill
foram aplicadas de memória, sem garantia nenhuma. Fazer o trabalho à mão em vez de
invocar esta skill **conta como etapa não executada** e tem que ser reportado como
falha ao Guilherme, nunca apresentado como se a etapa tivesse rodado.

## Passo a passo

### 1. Pintar as linhas

- Pinte da coluna **B até a I** (a coluna A não).
- Copie o **fill** (preenchimento) de uma linha recente do mesmo técnico — não crie a cor do
  zero, garante o tom exato em uso (ex.: "$ Jonathan" usa um tint levemente diferente da
  legenda da coluna K).
- Guilherme não tem cor (sem preenchimento).
- Técnico novo sem linha anterior → use a cor da legenda da coluna K e confirme com o usuário.
- **"$Nome" vs "Nome" (sem $)**: "Jonathan" sem "$" (compra no cartão da empresa) é pintado de
  **azul** — copie o fill de uma linha "Jonathan" (sem $) já colorida de azul existente, não do
  "$ Jonathan".
- A coluna K contém as tabelas de caixa de cada técnico — releia essa legenda a cada execução
  (técnicos e cores podem mudar).

### 2. Conferir

1. **Não recalcule via LibreOffice** — o Excel recalcula ao abrir.
2. Releia as linhas novas e confira **valor a valor contra a lista do ep-leitor-notas** (que
   por sua vez veio da nota original).
3. **Somatório**: soma dos valores em G lançados == soma dos valores da lista de itens. Não
   bateu? Avise e revise item por item antes de fechar.
4. **Formatação**: compare o `number_format` do arquivo editado contra o original, célula a
   célula, em todas as abas — o resultado deve ser **zero diferenças**. Diferença encontrada =
   corrija a célula nova para bater com o padrão da coluna (pegue de uma célula vazia abaixo
   dos dados) — nunca altere o original.

### 3. Devolver a planilha

- Envie a planilha e grave de volta no computador do usuário usando o `expectedMtimeMs` do
  stage original.
- Rejeições comuns:
  - "is open in another application" → a planilha está aberta no Excel do usuário; peça pra
    fechar (sem salvar) e tente de novo.
  - mtime drift de milissegundos com mesmo tamanho de arquivo → arredondamento do relógio;
    reenvie com o mtime atual informado na rejeição.
  - mtime muito diferente → o usuário editou o arquivo; peça pro Supervisor re-executar a
    partir do `ep-lancador-notas` em cima da versão nova.

### 4. Relatório final

Reporte em tabela: item, descrição, fornecedor, nota, data, valor, quem gastou — mais os saldos
de caixa atualizados. Toda vez que "Quem gastou" tiver sido definido por suposição (regra do
remetente ou qualquer outro default, marcado pelo `ep-leitor-notas`) em vez de citação
explícita, **marque isso claramente no resumo** para o usuário conferir.

Se houve aportes de caixa identificados na Etapa 1 (lista separada do `ep-leitor-notas`),
reporte-os **separado** da tabela de lançamentos, pois não entram na planilha:

| Data | Funcionário | Valor |
|---|---|---|
| 11/07 | Jonathan | R$ 100,00 |
| 11/07 | Cabelinho | R$ 120,00 |

Itens com Nota = "ML" (compras do Mercado Livre) não precisam de nenhuma ação seguinte —
**resolvido 05/08/2026**: o fluxo EP não usa o número oficial da NF do Mercado Livre, só data e
valor. "ML" já é o valor final do campo Nota, não uma pendência. Não sugerir `notas-fiscais-ml`
— essa skill é exclusiva do fluxo DG Revy.

## Troubleshooting

| Problema | Solução |
|---|---|
| Download bloqueado pelo Chrome | Navegar diretamente para a URL em vez de clicar no botão de download |
| Arquivo `~$*.xlsx` na pasta no momento de gravar | Planilha aberta no Excel — pedir para fechar (sem salvar) antes de continuar |
| Escrita direta no arquivo montado do usuário corrompeu o .xlsx | Nunca escreva direto no arquivo do usuário — sempre a partir da cópia local do `ep-lancador-notas`. Se corromper, recupere a partir da última cópia local íntegra |
| Releitura logo após a gravação mostra conteúdo antigo | Cache pode ficar defasado por alguns segundos — confie no tamanho/mtime reportado pela própria escrita, não numa releitura imediata |
