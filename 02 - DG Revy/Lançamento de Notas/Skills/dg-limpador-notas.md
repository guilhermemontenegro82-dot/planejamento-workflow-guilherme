---
name: "dg-limpador-notas"
description: "Etapa fixa do pipeline \"Supervisor de lançamento DG\": roda logo depois que o dg-pintor-notas confirma que a planilha foi salva com sucesso, fechando o ciclo comum de lançamento — antes da etapa condicional notas-fiscais-ml (que só roda a cada 2-3 ciclos, mediante aprovação do usuário num checkpoint). Move para a subpasta \"Deletar\" dentro de Downloads os arquivos temporários baixados pelo dg-leitor-notas nesta mesma rodada — só os que já têm cópia confirmada (mesmo tamanho em bytes) na pasta Notas Fiscais/Numeradas ou Recibos adm da obra. Se o usuário aprovar e a notas-fiscais-ml rodar na sequência, o Supervisor chama esta skill uma segunda vez ao final, pra varrer também os PDFs que ela baixou. Nunca apaga nada permanentemente (Claude não tem permissão para excluir arquivos, mesmo via skill) — só organiza, deixando pronto para o usuário apagar quando quiser. Não mexe em outros arquivos da Downloads. Só deve ser chamada pela skill supervisor-lancamento-dg."
---

## Papel nesta pipeline

Etapa fixa do pipeline `supervisor-lancamento-dg`, com **duas chamadas possíveis** na mesma
rodada:

1. **Primeira chamada (sempre acontece)** — logo depois que o `dg-pintor-notas` confirma que a
   planilha foi salva com sucesso. Fecha o "ciclo comum" de lançamento (planilha salva +
   Downloads organizada), **antes** da etapa condicional `notas-fiscais-ml` — não depois. Varre
   os arquivos temporários que o `dg-leitor-notas` baixou nesta rodada.
2. **Segunda chamada (só se o usuário aprovou rodar a `notas-fiscais-ml` num checkpoint e ela
   rodou)** — pra varrer os PDFs que a `notas-fiscais-ml` baixou pra Downloads. Roda a skill de
   novo, do zero — ela é segura pra isso: só move o que ainda não foi movido e já tem cópia
   confirmada na pasta definitiva.

**Por que essa ordem existe**: rodar a `notas-fiscais-ml` em todo ciclo de lançamento não
compensa — muitas notas fiscais do Mercado Livre só ficam disponíveis um tempo depois da
entrega do material. O usuário normalmente prefere rodá-la a cada 2-3 ciclos comuns de
lançamento, não em todo lançamento. Por isso o ciclo comum (lançamento + organização + pintura
+ limpeza) precisa poder se fechar sozinho, sem depender da decisão sobre o Mercado Livre — essa
decisão vira um checkpoint separado, depois da limpeza, controlado pelo Supervisor.

Não escreve na planilha, não organiza nada na pasta definitiva, não decide dado de negócio —
só arruma o que já está seguro em outro lugar.

## Regra de ouro — nunca excluir de verdade

**Claude nunca apaga arquivos permanentemente — nem com skill dedicada, nem com autorização
explícita do usuário.** Essa é uma regra de segurança do próprio Claude, não uma preferência do
Guilherme. Por isso esta etapa **move** os arquivos confirmados para `Downloads/Deletar` (cria
a subpasta se não existir) em vez de excluí-los. Quem decide apagar de fato o conteúdo dessa
subpasta é sempre o usuário, no computador dele.

## Regra de ouro — quando pode rodar

**Só entra em ação se as duas condições abaixo forem verdadeiras:**

1. O `dg-pintor-notas` confirmou que a planilha foi salva com sucesso no arquivo original do
   usuário (commit sem erro). Deu "Permission denied" ou qualquer rejeição não resolvida? Não
   mova nada — a Downloads é a última rede de segurança até a planilha estar de fato salva.
2. Existe, pra cada arquivo a mover, uma cópia já confirmada na pasta Notas Fiscais/Numeradas
   ou Recibos adm da obra — **mesmo tamanho em bytes**, não só mesmo nome.

**Até duas chamadas por rodada, nunca mais que isso.** A primeira acontece sempre, logo após o
`dg-pintor-notas` confirmar o commit — isso fecha o ciclo comum e independe do que acontecer
com a etapa do Mercado Livre. A segunda só acontece se o Supervisor invocar de novo, depois da
`notas-fiscais-ml` ter rodado (etapa condicional, aprovada pelo usuário) — nesse caso, trate
como uma varredura nova e independente da Downloads, sem se preocupar com o que já foi movido
na primeira chamada.

## Regras de ouro (invioláveis)

1. **Nunca mova um arquivo da Downloads sem antes confirmar que a cópia dele existe e bate em
   tamanho na pasta Numeradas (ou Recibos adm, no caso de recibos administrativos).** Bateu
   diferente ou não achou a cópia? Pule esse arquivo específico e avise no relatório final —
   não trave a organização dos demais por causa de um.
2. **Nunca mexa na pasta Downloads além dos arquivos desta obra, desta rodada** —
   identificados pelo prefixo/nome que o `dg-leitor-notas` usou ao baixar (ex.:
   `prudente614_item20_...jpg`), pelo nome original de PDF/imagem que veio direto do WhatsApp
   (ex.: `WhatsApp Image 2026-07-27 at 08.09.25.jpeg`,
   `DIOGO - NF10130 - 29-07-26 - R$ 640,00.PDF`), ou pelos PDFs de NF que a `notas-fiscais-ml`
   baixou (só relevante na segunda chamada). Nunca mova arquivo de outra obra, de outro dia, ou
   que não tenha relação clara com a lista de itens desta rodada.
3. **Duplicados do navegador** (mesmo arquivo baixado mais de uma vez, ex.: `nome (1).pdf`) —
   se identificados como a mesma nota (mesmo conteúdo/tamanho do original), também podem ser
   movidos junto, mesma regra de conferência antes.
4. **Nunca exclua o conteúdo de `Downloads/Deletar`** — mesmo que o usuário peça para apagar
   diretamente. Explique a regra (Claude não apaga arquivos permanentemente, nem por skill
   dedicada) e que a subpasta `Deletar` já deixa tudo pronto pra ele excluir manualmente quando
   quiser, ou usar o comando "Esvaziar pasta" do próprio Explorer/Finder.

## Passo a passo

### 1. Montar a lista do que mover

Na primeira chamada, a partir do relatório do `dg-organizador-notas`: para cada item lançado
nesta rodada, qual(is) arquivo(s) temporário(s) ele tinha na Downloads, e qual arquivo final
correspondente ficou na pasta Numeradas (ou Recibos adm). Na segunda chamada (pós Mercado
Livre), a partir do relatório da `notas-fiscais-ml`: quais PDFs de NF ela baixou e onde
ficaram organizados.

### 2. Conferir tamanho em bytes antes de mover

Para cada par (arquivo Downloads → arquivo definitivo), compare o tamanho em bytes. Só bateu
igual? Pode mover o da Downloads para `Downloads/Deletar`. Não bateu, ou o arquivo não existe
mais na pasta definitiva por algum motivo? **Não mova** — registre como pulado no relatório
final.

### 3. Mover

Crie `Downloads/Deletar` se ainda não existir. Mova um por um (não em lote sem checagem) para
essa subpasta, mantendo o nome original do arquivo — não renomeie.

### 4. Conferir o resultado

Releia a pasta Downloads e a subpasta `Deletar` depois de mover — confirme que os
arquivos-alvo saíram da raiz da Downloads, estão presentes em `Deletar` com o mesmo tamanho em
bytes, e que nenhum outro arquivo foi afetado. **Releia de novo após alguns segundos** se a
pasta Downloads estiver sincronizada com um serviço de nuvem (ex.: OneDrive) — a primeira
leitura logo após mover pode ficar defasada.

### 5. Entregar o fechamento

Informe ao Supervisor quantos arquivos foram movidos para `Downloads/Deletar` nesta chamada, e
quais (se algum) foram pulados e por quê.

- **Se esta foi a primeira chamada** (logo após a pintura): o Supervisor segue para o
  checkpoint sobre a `notas-fiscais-ml` — não é o fechamento final do pipeline ainda.
- **Se esta foi a segunda chamada** (depois da `notas-fiscais-ml` ter rodado): aí sim isso
  fecha o pipeline inteiro do Supervisor — pode informar direto ao usuário como parte do
  relatório final.

## Troubleshooting

| Problema | Solução |
|---|---|
| Arquivo da Downloads não tem par na pasta Numeradas/Recibos adm | Pular esse arquivo, avisar no relatório — não travar a organização dos demais |
| Tamanho em bytes não bate exatamente | Tratar como não confirmado — pular e avisar, mesma regra acima |
| `dg-pintor-notas` não confirmou commit com sucesso | Não rodar esta etapa — esperar a planilha estar salva de verdade primeiro |
| Releitura logo após mover mostra pasta desatualizada (Downloads sincronizada com nuvem) | Esperar alguns segundos e reler — não reportar sucesso sem essa confirmação |
| Usuário pede para apagar o conteúdo de `Downloads/Deletar` direto | Não apagar — explicar a regra e que ele mesmo pode excluir manualmente |
| Sendo chamada pela segunda vez na mesma rodada (pós `notas-fiscais-ml`) | Normal — trate como uma varredura nova e independente da Downloads, sem duplicar o que já foi movido na primeira chamada |
| Supervisor tenta chamar esta skill antes do `dg-pintor-notas` confirmar o commit | Recusar — a primeira chamada só acontece depois do commit confirmado, nunca antes |

