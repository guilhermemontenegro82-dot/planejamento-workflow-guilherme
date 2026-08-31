---
name: "dg-organizador-notas"
description: "Etapa 3 do pipeline \"Supervisor de lançamento DG\": move os arquivos baixados pelo dg-leitor-notas da pasta Downloads para a pasta Notas/Numeradas de cada obra, renomeando com o número do item (coluna B) que o dg-lancador-notas escreveu na planilha — incluindo o caso de um mesmo item ter mais de um arquivo (ex.: 94-orcamento.jpg, 94-pix.png, 94-nf.pdf quando há orçamento, comprovante de pix e nota fiscal separados para a mesma compra). Não escreve nem pinta a planilha. Só deve ser chamada pela skill supervisor-lancamento-dg, depois do dg-lancador-notas ter terminado de escrever."
---

## Papel nesta pipeline

Etapa 3 do fluxo `supervisor-lancamento-dg`. Recebe do `dg-lancador-notas` a lista de itens
escritos (número da linha/coluna B) e os arquivos associados a cada um (baixados pelo
`dg-leitor-notas`, ainda na pasta Downloads com nome temporário) e organiza tudo na pasta
definitiva da obra. Não escreve na planilha e não pinta nada.

## Passo a passo

### 1. Regra geral de nomenclatura

Cada arquivo lançado deve ficar na pasta **Notas** (ou `Notas/Numeradas`, confira a estrutura
da obra) nomeado com o número que ele recebeu na **coluna B** da linha correspondente.

### 2. Item com múltiplos arquivos (fluxo multi-comprovante)

Quando o `dg-lancador-notas` sinalizar que um item (ex.: item 94) tem mais de um arquivo
relacionado — orçamento, comprovante de pix, nota fiscal — **nomeie cada um com o número +
sufixo indicando o tipo**, nunca sobrescrevendo um arquivo pelo outro:

```
94-orcamento.jpg
94-pix.png
94-nf.pdf
```

Se a nota fiscal ainda não chegou, organize só os arquivos disponíveis (`94-orcamento.jpg`,
`94-pix.png`) e adicione o `94-nf.pdf` depois, quando o `dg-lancador-notas` aplicar o "Reparo
em item já lançado".

### 3. Comprovante de reembolso não vira arquivo próprio

Comprovante de reembolso a técnico (ver `dg-leitor-notas`/`dg-lancador-notas`) **não vira
arquivo numerado próprio** — só serve de evidência pra decidir a coluna I do item de compra
correspondente. Só o arquivo do item de compra em si entra na pasta Numeradas.

### 4. Mover arquivos de Downloads pra pasta da obra

Com a pasta Downloads conectada, mover é um comando de shell comum:

```bash
cp "/sessions/<sessão>/mnt/Downloads/rainha_92.jpg" \
   "/sessions/<sessão>/mnt/Lançamento de notas fiscais - DG/<Obra>/Notas/Numeradas/92.jpg"
```

Sem limite de caracteres nem risco de comando truncar — processe vários arquivos em sequência
num único script/loop. Depois de copiar todos, **confira lendo a pasta de destino** (listagem
de arquivos) comparando a contagem esperada — não confie só no fato de o comando não ter dado
erro.

### 5. Conferência final desta etapa

- A **quantidade** de arquivos na pasta de destino aumentou exatamente pelo número de itens
  novos (nem sumiu, nem duplicou) — contando os casos multi-comprovante como múltiplos
  arquivos por item.
- O **tamanho em bytes** de cada arquivo copiado bate com o original em Downloads.

### 6. Reparo em item já lançado (arquivo trocado quando NF chega depois)

Quando o `dg-lancador-notas` aplicar um número de NF a um item que já tinha "SN": troque o
arquivo antigo (ex.: `65.jpg`) pelo PDF novo, **mantendo o mesmo número** (`65.pdf`). Se o
arquivo antigo não puder ser apagado (pasta com proteção contra exclusão), use
`mcp__cowork__allow_cowork_file_delete` pedindo a permissão primeiro — não deixe os dois
arquivos duplicados no final.

### 7. Entregar para a próxima etapa

Informe ao Supervisor: lista final de arquivos organizados (número → nome(s) de arquivo),
para o `dg-conferidor-notas` validar a sequência.

## Troubleshooting

| Problema | Solução |
|---|---|
| Apagar um arquivo antigo dá "Operation not permitted" | Pasta com proteção contra exclusão — chamar `mcp__cowork__allow_cowork_file_delete` e repetir |
| Pasta Downloads do usuário ainda não conectada | Isso deveria ter sido feito na Etapa 1 (`dg-leitor-notas`) — se não foi, chame `mcp__cowork__request_cowork_directory(path="~/Downloads")` |
| Item com múltiplos arquivos e um deles falta | Organize os disponíveis e avise no relatório que falta um (ex.: NF ainda não chegou) — não bloqueie os demais |

