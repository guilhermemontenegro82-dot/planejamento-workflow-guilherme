---
name: "dg-pintor-notas"
description: "Etapa 5 (final) do pipeline \"Supervisor de lançamento DG\": pinta as linhas da aba LANÇAMENTO na cor do técnico correspondente (Mestre, Guilherme sem cor, terceiro pagador eventual), faz a conferência financeira final (soma de valores, diff de number_format célula a célula, checagem de arquivo aberto no Excel) e devolve a planilha ao computador do usuário. Só deve ser chamada pela skill supervisor-lancamento-dg, como último passo, depois do dg-conferidor-notas ter validado a numeração."
---

## Papel nesta pipeline

Etapa 5 (final) do fluxo `supervisor-lancamento-dg`. Só roda depois que o `dg-conferidor-notas`
confirmou que a numeração dos arquivos está limpa. Pinta as linhas, faz a conferência
financeira final e devolve a planilha ao computador do usuário.

## Passo a passo

### 1. Pintar as linhas

- Pinte da coluna B até a I (não pinte a A).
- **Mestre**: copie o fill da célula **K8** (legenda "Caixa Mestre PIX") — não recrie a cor do
  zero. Confirmado idêntico (tema 9, tint ≈0.6) em todas as obras já lançadas.
- **Guilherme**: sem preenchimento.
- **Terceiro pagador eventual** (ex.: Diogo, Tiago): cor combinada com o usuário para aquela
  obra especificamente — documente qual foi usada, obra por obra, para reaproveitar da próxima
  vez.

### 2. Conferir

1. Compare o `number_format` célula a célula entre o arquivo editado e o original, em todas as
   abas — tem que dar **zero diferenças**. Deu diferença? Refaça a partir do original, não
   tente consertar em cima.
2. Some os valores lançados (coluna G) e confira contra a soma dos totais das notas
   processadas nesta rodada (vinda do `dg-leitor-notas`/`dg-lancador-notas`).
3. Confirme que não existe `~$*.xlsx` na pasta (planilha fechada) antes de gravar por cima do
   arquivo original. Se existir, peça pro usuário fechar e só então grave.

### 3. Devolver a planilha

- Copie a versão final pro caminho do arquivo original, usando o `expectedMtimeMs` do stage
  feito lá no `dg-lancador-notas`.
- Rejeições comuns:
  - "Permission denied" → quase sempre o arquivo está aberto no Excel do usuário — confirme o
    `~$*.xlsx` e peça pra fechar.
  - mtime drift de milissegundos → arredondamento do relógio, reenvie com o mtime atual.
  - mtime muito diferente → o usuário editou o arquivo nesse meio tempo — avise o Supervisor
    que é preciso re-stage e refazer as etapas anteriores em cima da versão nova.

### 4. Relatório final

Reporte em tabela: item, descrição, fornecedor, nota, data, valor, quem gastou — mais o saldo
de caixa do Mestre atualizado e as decisões/convenções aplicadas (ex.: cor de terceiro
pagador), pedindo correção se algo estiver errado.

Se houver itens com Nota = "Pendente" (compras do Mercado Livre), avise o usuário e sugira
rodar a skill `notas-fiscais-ml` em seguida (Etapa 6 do Supervisor) para buscar o número
oficial da NF e baixar o PDF.

## Troubleshooting

| Problema | Solução |
|---|---|
| Gravação da planilha falha com "Permission denied" | Quase sempre é o arquivo aberto no Excel do usuário — confirme o `~$*.xlsx` e peça pra fechar |
| Escrita direta no arquivo montado do usuário corrompeu o .xlsx | Nunca escreva direto no arquivo do usuário — sempre a partir da cópia local. Se corromper, recupere a partir da última cópia local íntegra |
| Reler arquivo logo após copiar/escrever mostra conteúdo antigo | Cache pode ficar defasado por alguns segundos — confirme pelo tamanho/mtime reportado pela própria escrita |

