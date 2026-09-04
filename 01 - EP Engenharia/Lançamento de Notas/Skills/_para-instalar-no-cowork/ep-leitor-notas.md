---
name: "ep-leitor-notas"
description: "Etapa 1 do pipeline supervisor-lancamento-ep: lê notas fiscais, recibos, comprovantes e mensagens de texto do grupo WhatsApp \"EP - Notas fiscais\" (ou pasta local \"Notas\") e devolve uma lista estruturada de itens prontos para lançamento (obra, descrição, fornecedor, nota, data, valor, quem gastou, REEMB), mais lista de aportes de caixa e lista de dúvidas para o usuário confirmar antes de qualquer escrita. Baixa cada comprovante para a pasta Downloads como âncora de leitura (lê o dado do arquivo, não da tela) — mas não arquiva nem numera: os arquivos são temporários e vão para Downloads/Deletar no fim do ciclo. Não escreve na planilha. Só deve ser chamada pelo supervisor-lancamento-ep."
---

## Papel nesta pipeline

Esta skill é a **Etapa 1** do fluxo `supervisor-lancamento-ep`. Faz só a leitura e extração
de dados — não escreve na planilha (isso é o `ep-lancador-notas`) e não pinta linha nenhuma
(isso é o `ep-pintor-notas`).

## Objetivo

Ler as notas fiscais, recibos, comprovantes e mensagens de texto da fonte indicada (grupo do
WhatsApp "EP - Notas fiscais", ou pasta local "Notas" se as fotos já estiverem lá) e devolver
uma **lista estruturada** de itens prontos para lançamento — com todos os campos já decididos
(obra, descrição, fornecedor, número da nota, data, valor, quem gastou, flag REEMB) — mais uma
lista separada de aportes de caixa (que não vão para a planilha) e uma lista de dúvidas para
confirmar com o usuário antes de qualquer escrita.

**A EP não arquiva nota — mas baixa para ler.** Mudou em 30/08/2026, e o motivo importa:
até então esta skill lia tudo na tela (lightbox/zoom) e montava a lista de memória. Dois
erros reais apareceram assim — **nota que não foi lançada** e **"quem gastou" trocado entre
itens**. O fluxo do DG, que é mais complexo e erra muito menos, faz diferente: baixa o
arquivo, lê o dado **do arquivo**, e relê o arquivo antes de fechar cada linha. É essa
âncora que a EP não tinha.

Então, a partir de agora:

- **Baixe** cada nota/comprovante para a pasta Downloads do usuário (fase 2.A).
- **Extraia os dados lendo o arquivo salvo**, não a tela (fase 2.C).
- **Não arquive, não numere, não crie pasta "Notas"** — diferente do DG, a EP não precisa
  guardar o arquivo. Ele é temporário, só serve de âncora de leitura.
- No fim do ciclo, os arquivos usados vão para `Downloads/Deletar` (ver o passo de
  encerramento no `supervisor-lancamento-ep`). **Nunca apague nada de fato** — mover para
  `Deletar` é o máximo; a exclusão final é decisão do Guilherme, no computador dele.

O usuário está sempre disponível: **na dúvida sobre obra, fornecedor ou quem gastou, pare e
pergunte** — nunca chute e devolva o item como "confirmado" para a próxima etapa.

## Passo a passo

### 0. Anunciar-se

Comece a resposta com esta linha, literal:

```
▶ ep-leitor-notas — Etapa 1 iniciada
```

**A sua lista não vai direto para o `ep-lancador-notas`.** Ela passa obrigatoriamente
pelos dois Chequers (Etapas 1.5 e 1.6) e pelo checkpoint com o Guilherme. Quem autoriza
a escrita na planilha são os chequers, não você — entregue ao Supervisor e pare.

### 1. Identificar a fonte

- Pasta local "Notas" já com fotos → leia os arquivos direto (ordene por mtime).
- Grupo do WhatsApp "EP - Notas fiscais" → abra o WhatsApp Web, localize o grupo, procure a
  última mensagem "Atualizado até aqui" (só as notas depois dela são novas).

### 2. Colher primeiro, ler depois — nunca ao mesmo tempo

**Esta é a mudança que mais afeta tempo e erro (30/08/2026).** Até aqui a EP fazia tudo numa
passada só: navegar no lightbox → screenshot → zoom → screenshot → ler → decidir → próxima.
Isso é lento (cada screenshot custa segundos) e frágil (screenshot que dá timeout ou lightbox
que pula fazem o item **sumir sem avisar**). Lentidão e bloco pulado têm a mesma causa.

O fluxo DG não faz assim, e é por isso que é mais rápido apesar de ter mais etapas: **baixa
tudo primeiro, sem ler nada, e só depois lê os arquivos no disco.**

Separe em três fases. Não misture:

| Fase | O que faz | O que NÃO faz |
|---|---|---|
| **A. Colheita** | baixa todas as imagens | não lê, não classifica, não decide |
| **B. Inventário** | conta e confere cobertura | não classifica |
| **C. Leitura** | lê os arquivos no disco e classifica | não volta pro WhatsApp |

### 2.A. Colheita — baixar tudo, sem ler nada

Se ainda não estiver conectada nesta conta, chame
`mcp__cowork__request_cowork_directory(path="~/Downloads")`.

Percorra do ponto de corte até a mensagem mais recente **baixando cada imagem, sem parar
para ler**. Use JavaScript, não clique nem screenshot:

```javascript
const imgs = Array.from(document.querySelectorAll('img'))
  .filter(i => i.offsetWidth > 300 && i.offsetHeight > 300 && i.src.startsWith('blob:'));
const img = imgs.sort((a,b) => (b.offsetWidth*b.offsetHeight)-(a.offsetWidth*a.offsetHeight))[0];
const a = document.createElement('a');
a.href = img.src;
a.download = 'ep_tmp_01.jpg';
document.body.appendChild(a);
a.click();
a.remove();
```

- Nomeie sequencialmente: `ep_tmp_01.jpg`, `ep_tmp_02.jpg`… É só para você conseguir voltar
  no arquivo certo (a EP não arquiva nada).
- **Não dê zoom nesta fase. Não leia valor, não decida obra, não decida quem gastou.** Só
  baixe. Ler agora é o que torna a etapa lenta.
- **Anote o horário de cada mensagem** junto do nome do arquivo — vai servir no inventário.
- **PDFs** no visualizador do WhatsApp (iframe cross-origin) não baixam por JS: use o ícone
  de download do próprio visualizador.
- **Screenshot com timeout não trava a colheita.** A página costuma continuar respondendo a
  JS normalmente — siga baixando; você vai ler pelo arquivo depois, não pela tela.

### 2.B. Inventário — conferir cobertura antes de ler qualquer coisa

Agora, com tudo no disco, confira se **faltou bloco** — antes de gastar tempo lendo:

1. **Conte os arquivos** baixados na pasta Downloads (`ep_tmp_*`). → **A**
2. **Role o chat inteiro** (rolagem normal, não lightbox) do ponto de corte até o fim e
   conte quantas mensagens têm imagem. → **B**
3. **A e B têm que bater.** Não bateram? Você pulou bloco na colheita — volte e baixe o que
   faltou antes de seguir.
4. **Continuidade no tempo**: olhe os horários anotados. Um salto grande sem nenhuma
   mensagem no meio (ex.: nada entre 10:12 e 16:49 num dia útil) é suspeito — role de novo
   aquele intervalo específico para confirmar que realmente não havia nada ali, em vez de
   assumir. É assim que um bloco inteiro some sem ninguém notar.
5. **Texto puro**: nessa mesma rolagem, anote as mensagens de texto com sinal financeiro
   (pagamento avisado por escrito, sem foto). Elas não geram arquivo, mas viram item.
   - **Caso clássico**: dinheiro dado a porteiro ou funcionário por favor avulso (ex.:
     "paguei 150 pro porteiro por causa da caçamba") — ver "Pagamentos avulsos sem foto".
6. **Replies**: anote quais mensagens são **resposta do Guilherme citando uma nota** e a qual
   arquivo cada uma se refere. São o critério nº 1 de "quem gastou" (seção 10.1) — ter esse
   mapa pronto agora evita procurar item a item depois.

### 2.C. Leitura — ler os arquivos, não a tela

Só agora leia. Para cada arquivo baixado (`Read` em
`C:\Users\<usuario>\Downloads\ep_tmp_NN.jpg`), extraia fornecedor, valor, data e número da
nota. **Não volte para o WhatsApp para isso** — o arquivo tem tudo, e ler do disco é muito
mais rápido que zoom na tela.

- **Zoom só como exceção**: se o arquivo baixado estiver ilegível, aí sim volte à tela e dê
  zoom. **Não adivinhe e não marque "SN" sem ter tentado antes.**
- **Identifique a obra pela legenda** da mensagem (ex.: "LC Xerém", "Gu-Urca", "M12-CURICICA
  (reembolso)"), usando a tabela de apelidos abaixo. Legenda que não deixa claro → pergunte,
  não adivinhe.
- **CNPJ de holding não indica a obra**: compras faturadas para "FLXY Solutions Patrimonial e
  Investimentos LTDA" aparecem em várias obras — a obra real vem da legenda ou do contexto,
  nunca do CNPJ do destinatário.

### 2.D. 🔒 Regra anti-memória — releia o arquivo antes de fechar cada linha

**Ao montar a tabela final, releia o arquivo específico de cada item antes de preencher
fornecedor, valor e quem gastou. Não confie na memória do que você viu na fase de leitura.**

Numa mesma rodada é comum aparecerem vários comprovantes parecidos (mesmo layout, valores
próximos, mesma loja). Atribuir os dados de um ao item errado é erro real e recorrente —
aconteceu na EP em **27/08/2026** ("quem gastou" trocado) e já tinha acontecido no DG antes,
que resolveu exatamente assim. Reabrir o arquivo custa segundos; refazer o lançamento, não.

### 2.E. Conferência final de contagem

- **A** = arquivos baixados · **T** = mensagens de texto com sinal financeiro (fase 2.B)
- **M** = itens na sua lista (lançamentos + aportes de caixa)
- **A + T deve bater com M.** Não bateu, você pulou ou duplicou algo — resolva antes de
  entregar.

Reporte **A, T e M** ao Supervisor: são esses números que alimentam o Certificado de
Verificação que os chequers vão emitir.

### 3. Apelidos de obra conhecidos

| Legenda no WhatsApp | Obra na planilha |
|---|---|
| "BZ" / "BZ Barra" | JC - Barra (obra pequena "pendurada" na JC) |
| "GA", "Urca", "Box ICRJ" | GA - Urca |
| "MC", "Ipanema" | MC - Ipanema |
| "LT", "Botafogo" | LT - Botafogo |
| "JC", "Barra" | JC - Barra |
| "M12", "Curicica" | M12 - Curicica |
| "LC", "Xerém" | LC - Xerém |
| "AF", "Marechal" | AF - Marechal |
| "PS Buzios", "Pedro Salgado Buzios", "Buzios" | PS - Buzios |
| "PS Leblon" | PS - Leblon |
| "IM", "Joquei", "Giappo Varanda" | IM - Giappo Varanda - Joquei |

Atenção: Marechal já apareceu como "AS" numa versão antiga — **confirmado 04/08/2026**: "AS" e
"AF" são a mesma obra (Marechal), o código só mudou de versão para versão. Pode tratar como
sinônimos.

Códigos antigos não confirmados (perguntar antes de usar): "VS"/Leblon, "FY"/Leblon,
"PS Varanda"/Leblon, "GE"/Recreio.

**Não existe obra "DG" aqui — excluir sempre da análise.** Notas de "Aptos Leilão"/"DG"
pertencem a um sistema próprio do DG Revy, já em funcionamento — nunca tentar lançar aqui,
mesmo que uma nota antiga pareça mencionar esse código (confirmado 04/08/2026).

### 4. Regra do "Caixa X": ignorar vs lançar

- **"X aporte caixa Y"** ou **"Abater caixa"** = controle interno de caixa entre sócio e
  técnico, sem nota real — **não é item de lançamento**. Anote (data, técnico, valor) na lista
  separada de "aportes de caixa" para reportar ao final.
- **"Caixa [técnico]"** como legenda de compra real com nota/comprovante anexado (sem
  "aporte"/"abater") = despesa de verdade — vira item de lançamento normal, "quem gastou" = o
  técnico da legenda.
- Na dúvida, veja se tem nota/comprovante anexado — se tiver, é item de lançamento.
- Nunca lançar diária de sábado/domingo com nome de funcionário (vem da planilha de ponto, não
  da de notas).

### 5. Pagamentos avulsos sem foto (porteiro, funcionário, favor)

Mensagem de texto simples avisando um pagamento pontual a alguém fora do quadro fixo de
técnicos (porteiro, zelador, favor avulso) é item de lançamento normal (não é aporte/vale):

- Descrição = o que foi pago (ex.: "Pagamento porteiro - ajuda caçamba").
- Fornecedor = nome de quem recebeu, se informado, senão pergunte.
- Nota = "SN".
- Quem gastou = quem efetivamente desembolsou — pergunte se não estiver claro.
- Confirme obra, fornecedor e quem gastou com o usuário antes de considerar o item pronto.

### 6. Quem gastou não identificado — regra do remetente

O grupo "EP - Notas fiscais" só tem duas pessoas: **Guilherme e Renato**. Nota sem técnico
identificado na legenda:

- Enviada pelo **Renato** sem outro nome citado → "Quem gastou" = **Renato**.
- Enviada pelo **Guilherme** ("Você") sem outro nome citado → "Quem gastou" = **Guilherme**.
- Mensagem (de qualquer um dos dois) citando outro nome (ex.: "Mecânica carro Uno / Jonathan")
  → usa o nome citado.

**Esta regra do remetente é o último recurso, não o primeiro passo.** Antes de aplicá-la,
seguir a ordem de prioridade da seção 10.1 abaixo — ela substitui qualquer suposição só depois
que o contexto ao redor e o final do cartão (quando existir) já foram checados e não
resolveram.

### 7. Não presuma técnico fixo por fornecedor/loja

Uma mesma loja (ex.: EMC Matos) não pertence a um técnico fixo. Para saber quem gastou sem
legenda clara, siga a ordem de prioridade da seção 10.1 — não use histórico/padrão recorrente
como certeza.

### 8. Compras do Mercado Livre — nunca deixar de fora

Compra no Mercado Livre normalmente aparece como comprovante de Pix (não nota fiscal de loja
física). Isso **não** significa deixar o gasto de fora da lista:

- Inclua o item na lista **normalmente**, com os dados do comprovante de Pix (valor,
  descrição, obra, quem gastou).
- Campo "Nota" = **"ML"**.
- Nunca omita um item só porque não tem número de nota fiscal.

**Resolvido 05/08/2026**: no fluxo EP, o número oficial da NF do Mercado Livre **não é
necessário** — só data e valor importam. Isso é diferente do fluxo DG Revy, onde o número da
nota é obrigatório (uso no imposto de renda dele) e é buscado pela skill `notas-fiscais-ml`
— exclusiva daquele fluxo, não roda aqui. Por isso o campo "Nota" aqui não usa mais "Pendente"
(que sugeria um número a buscar depois): "ML" já é o valor final, não uma etapa intermediária.

### 9. Convenções fixas por técnico

- **Jonathan**: pagamento do bolso dele (reembolsável) → "Quem gastou" = **"$ Jonathan"** (com
  "$"), obra **MC-Ipanema** (onde o caixa dele é controlado).
- **Matheus**: idem, "**$ Matheus**" (se a planilha tiver essa caixa) ou obra **M12-Curicica**.
- **Caixa Cabelinho** e **Caixa Anderson** (compras reais) → obra **MC-Ipanema**, "Quem gastou"
  = nome **sem** "$".
- **"$Nome" vs "Nome" não são a mesma coisa**: "$ Jonathan" = caixa pessoal dele (alimenta
  SUMIF da caixa). "Jonathan" sem "$" = compra com cartão da empresa (pintura em azul — decisão
  de cor fica com o `ep-pintor-notas`, mas registre aqui qual dos dois casos é).
- **Regra crítica — o caixa manda mais que a obra do gasto**: se a nota é "caixa
  [nome]"/"dinheiro [nome]" (pago do bolso/Pix pessoal do técnico), o item vai na obra **onde o
  caixa dele é controlado**, mesmo que a compra tenha sido para outra obra. Pergunte ao usuário
  em qual obra fica o caixa daquele técnico sempre que não tiver certeza.
- **O gatilho real não é a palavra "caixa"/"dinheiro" na legenda — é a forma de pagamento**
  (confirmado 04/08/2026, correção do Guilherme): a pergunta certa não é "a legenda menciona
  caixa?", e sim **"esse pagamento saiu em dinheiro ou Pix pessoal do técnico?"**. Dinheiro/Pix
  pessoal do técnico é sempre dinheiro que a empresa já deixou com ele — é gasto de caixa por
  definição, precisa do mesmo tratamento (obra de quem controla o caixa, nomenclatura "$Nome"),
  **mesmo que a legenda não use as palavras "caixa" ou "dinheiro" e mesmo que a categoria do
  gasto pareça comum** (estacionamento é só o exemplo mais recorrente, não a regra em si —
  pagamento de pedágio, gorjeta, compra avulsa em espécie etc. seguem a mesma lógica). Pagamento
  no **cartão da empresa** nunca entra aqui, mesmo que o técnico tenha feito a compra. Na
  dúvida sobre se um pagamento saiu em espécie/Pix pessoal ou no cartão da empresa, pergunte —
  não presuma pelo tipo de gasto.

### 10. Cartões compartilhados — identificação por final do cartão

Comprovante de cartão (ex.: maquininha Mercado Pago/Point) pode trazer impresso o nome do
**titular do cartão**, não de quem realmente pagou nem do fornecedor — dois técnicos podem usar
cartões diferentes que trazem o mesmo nome impresso. Quando o comprovante mostrar o final do
cartão (ex.: "Master crédito 1678"), use esta tabela como um dos critérios da ordem de
prioridade da seção 10.1:

| Final do cartão | Quem gastou |
|---|---|
| 1678 | Matheus |
| 8900 | Jonathan |

O nome impresso no comprovante (ex.: "Jonathan Cotroffe") também não deve virar Fornecedor só
por aparecer perto do valor — é nome de titular de cartão, não de vendedor. Fornecedor real
desconhecido nesses casos → pergunte ao usuário ou use uma descrição genérica (ex.: "Padaria")
se o usuário confirmar que não há nome de estabelecimento melhor.

### 10.1. Ordem de prioridade para decidir "quem gastou"

Seguir nesta ordem, parar no primeiro critério que resolver:

**1. 🥇 RESPOSTA (reply) do Guilherme citando aquela nota — manda acima de tudo.**

No WhatsApp, quando o Guilherme responde a uma imagem, a mensagem dele aparece com a foto
citada num quadrinho logo acima do texto. **Essa é a correção definitiva daquele item** e
sobrepõe qualquer outro critério — inclusive a legenda original de quem enviou.

Por que ela vale mais que tudo: o Guilherme faz isso justamente quando o texto do
funcionário ficou ruim ou ambíguo. É ele explicando, item a item, quem gastou e do que se
trata. Não é dedução — é instrução direta, e está **estruturalmente amarrada àquela foto
específica**, não solta no meio do chat.

Procure ativamente por reply em cada item: ao ler cada nota, verifique se existe alguma
mensagem posterior que cite aquela imagem. Se existir, leia primeiro. Se ela disser quem
gastou, obra, ou do que se trata — **use o que ela diz e pare por aqui**, não continue
descendo a lista.

Confirmado com o Guilherme em 30/08/2026. É o equivalente, na EP, à tag "Encaminhada" que
faz o fluxo do DG quase não errar: um sinal explícito e vinculado ao item, no lugar de
inferência.

**2. Nome citado explicitamente na legenda da própria mensagem** (item 6, terceiro bullet).

**3. Contexto das mensagens imediatamente acima/abaixo**, no chat, sobre o mesmo gasto —
releia as linhas ao redor da nota; às vezes o nome está numa mensagem vizinha que **não** é
um reply formal. Menos confiável que o item 1 justamente por não ter vínculo explícito com
a foto.

**4. Final do cartão no comprovante**, contra a tabela do item 10 — só se 1, 2 e 3 não
resolverem.

**5. Regra do remetente** (item 6, primeiros dois bullets) — último recurso, só quando nada
acima resolveu.

Se mesmo assim ficar incerto, é dúvida de verdade: pare e pergunte ao usuário, não force um
dos cinco critérios.

**Ao reportar cada item, diga qual critério resolveu** (ex.: "resolvido pelo reply do
Guilherme" / "resolvido pela regra do remetente"). Item resolvido pelos critérios 4 ou 5
entra na lista de dúvidas — são inferência, não informação.

### 11. Não presuma técnico fixo por fornecedor/loja

(ver também item 10.1) Uma mesma loja (ex.: EMC Matos) não pertence a um técnico fixo.

### 12. Fornecedor — substituições fixas

"Bottino"/"Botino" → **Amoedo**. "BMB"/"BNB" (Material de Construção) → **Obramax**.
"Eletrica Pontevedra" → **Pontevedra**. Recibo/pix/ted → nome de quem **recebeu** o valor. Não
identificou? Pergunte.

### 13. Nota/Recibo — como decidir o campo

Número da nota fiscal (sem zeros à esquerda). Sem número de nota → número do recibo/documento.
Sem número nenhum: compra de material → **SN**; comprovante de pagamento → **NA**; compra do
Mercado Livre → **ML** (ver item 8 — não precisa do número oficial da NF neste fluxo).

### 14. Obras pequenas "penduradas" em outra planilha

Nota de obra sem planilha/pasta própria → não adivinhe, pergunte ao usuário em qual planilha
existente "pendurar" o item.

### 15. Combustível: sempre perguntar a obra

Abastecimento não tem obra fixa — pergunte sempre em qual obra lançar, mesmo que pareça óbvio.

### 16. Marca REEMB

Se o contexto indicar reembolso (compra que o cliente vai reembolsar), marque o item com flag
REEMB = sim.

### 17. Comprovante Pix de sócio

Se o pix saiu da conta de um sócio (Guilherme ou Renato) para pagar algo, confirme com o
usuário quem lançar em "Quem gastou" antes de marcar o item como confirmado — o pagador do
comprovante nem sempre é o padrão esperado.

### 18. Ordem cronológica

Ordene a lista final pela **data real da nota** (não a ordem em que você leu/processou).

## Formato de saída (entregar ao Supervisor)

Para cada item de lançamento:

| Obra | Descrição | Fornecedor | Nota | Data | Valor | Quem gastou | REEMB | Confirmado? |
|---|---|---|---|---|---|---|---|---|
| MC-Ipanema | Rotuladora Brother | Mercado Livre | ML | 14/07 | R$ 283,24 | $ Jonathan | não | sim |

Mais duas listas separadas:

- **Aportes de caixa** (data, técnico, valor) — não entram na planilha, só para o resumo final.
- **Dúvidas a confirmar** — todo item onde "Quem gastou" foi decidido por suposição/regra do
  remetente em vez de citação explícita, ou onde qualquer campo ficou incerto. O Supervisor
  deve levar essas dúvidas ao usuário antes de acionar o `ep-lancador-notas`.

## Regra de ouro

Na dúvida sobre obra, fornecedor, quem gastou ou qualquer mapeamento — pare e pergunte ao
usuário. Não entregue um item como "Confirmado: sim" se você mesmo não tem certeza.
