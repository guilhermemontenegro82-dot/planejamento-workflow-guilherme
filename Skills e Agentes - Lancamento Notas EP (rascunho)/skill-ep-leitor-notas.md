---
name: "ep-leitor-notas"
description: "Etapa 1 do pipeline supervisor-lancamento-ep: lê notas fiscais, recibos, comprovantes e mensagens de texto do grupo WhatsApp \"EP - Notas fiscais\" (ou pasta local \"Notas\") e devolve uma lista estruturada de itens prontos para lançamento (obra, descrição, fornecedor, nota, data, valor, quem gastou, REEMB), mais lista de aportes de caixa e lista de dúvidas para o usuário confirmar antes de qualquer escrita. Não escreve na planilha nem baixa arquivo físico. Só deve ser chamada pelo supervisor-lancamento-ep."
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

**Diferença chave em relação ao fluxo antigo**: a EP **não precisa de arquivo físico
baixado/arquivado** — só dos dados. Não crie pasta "Notas", não baixe imagem nenhuma, não use
o ícone de download do WhatsApp. Leia a nota (foto ou texto) na tela (lightbox, zoom, ou já na
pasta se for esse o caso) e extraia os dados diretamente.

O usuário está sempre disponível: **na dúvida sobre obra, fornecedor ou quem gastou, pare e
pergunte** — nunca chute e devolva o item como "confirmado" para a próxima etapa.

## Passo a passo

### 1. Identificar a fonte

- Pasta local "Notas" já com fotos → leia os arquivos direto (ordene por mtime).
- Grupo do WhatsApp "EP - Notas fiscais" → abra o WhatsApp Web, localize o grupo, procure a
  última mensagem "Atualizado até aqui" (só as notas depois dela são novas).

### 2. Varrer tudo sem pular nada (fonte WhatsApp)

- **Filminho de mídia**: abra qualquer imagem ("Abrir imagem") e use as setas ◄ ► do rodapé do
  lightbox para passar por todas as mídias em ordem cronológica — não baixe nada, só leia/zoom
  na tela.
- **Texto puro, numa passada separada**: o filminho só pega imagem. Role o histórico normal do
  chat (não o lightbox) entre o checkpoint e a mensagem mais recente, lendo toda mensagem de
  texto — não só legendas de foto. Pagamento avisado só por texto, sem nota nem print, é comum
  e passa batido se você só olhar o filminho de mídia.
  - **Caso clássico**: dinheiro dado a um porteiro ou funcionário por um favor avulso (ex.:
    "paguei 150 pro porteiro por causa da caçamba"). Trate cada menção dessas como um item de
    lançamento: identifique obra e "quem gastou" (pergunte se não estiver claro) — ver
    "Pagamentos avulsos sem foto" abaixo.
- **Identifique a obra pela legenda** da mensagem (ex.: "LC Xerém", "Gu-Urca", "M12-CURICICA
  (reembolso)"). Use a tabela de apelidos abaixo. Se a legenda não deixar claro, pare e
  pergunte ao usuário — não adivinhe.
- **CNPJ de holding não indica a obra**: compras faturadas para "FLXY Solutions Patrimonial e
  Investimentos LTDA" aparecem em várias obras diferentes — a obra real vem da legenda da
  mensagem ou de outro contexto, nunca do CNPJ do destinatário.

#### Conferência antes de fechar a leitura

Confirme que leu TODAS as notas do período (do "Atualizado até aqui" até a mensagem mais
recente) — revise o filminho mais uma vez e confirme que também releu o texto puro do chat
atrás de pagamentos avisados sem foto. Nenhuma nota deve ficar de fora da lista.

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
física). A numeração oficial da NF é buscada depois pela skill `notas-fiscais-ml`. Isso **não**
significa deixar o gasto de fora da lista:

- Inclua o item na lista **normalmente**, com os dados do comprovante de Pix (valor,
  descrição, obra, quem gastou).
- Campo "Nota" = **"Pendente"**.
- Nunca omita um item só porque a NF oficial ainda não foi buscada.

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

### 10.1. Ordem de prioridade para decidir "quem gastou" quando a legenda não é explícita

**Confirmado 04/08/2026** — seguir nesta ordem, parar no primeiro critério que resolver:

1. **Nome citado explicitamente na legenda da própria mensagem** (item 6, terceiro bullet).
2. **Contexto das mensagens imediatamente acima/abaixo, no chat, sobre o mesmo gasto** — releia
   as linhas ao redor da nota antes de aplicar qualquer regra automática; muitas vezes o nome
   está numa mensagem vizinha, não na legenda da própria foto.
3. **Final do cartão no comprovante**, contra a tabela do item 10 — só se (1) e (2) não
   resolverem.
4. **Regra do remetente** (item 6, primeiros dois bullets) — último recurso, só quando nada
   acima resolveu.

Se mesmo assim ficar incerto, é dúvida de verdade: pare e pergunte ao usuário, não force um dos
quatro critérios.

### 11. Não presuma técnico fixo por fornecedor/loja

(ver também item 10.1) Uma mesma loja (ex.: EMC Matos) não pertence a um técnico fixo.

### 12. Fornecedor — substituições fixas

"Bottino"/"Botino" → **Amoedo**. "BMB"/"BNB" (Material de Construção) → **Obramax**.
"Eletrica Pontevedra" → **Pontevedra**. Recibo/pix/ted → nome de quem **recebeu** o valor. Não
identificou? Pergunte.

### 13. Nota/Recibo — como decidir o campo

Número da nota fiscal (sem zeros à esquerda). Sem número de nota → número do recibo/documento.
Sem número nenhum: compra de material → **SN**; comprovante de pagamento → **NA**; compra do
Mercado Livre ainda sem NF → **Pendente** (ver item 8).

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
| MC-Ipanema | Rotuladora Brother | Mercado Livre | Pendente | 14/07 | R$ 283,24 | $ Jonathan | não | sim |

Mais duas listas separadas:

- **Aportes de caixa** (data, técnico, valor) — não entram na planilha, só para o resumo final.
- **Dúvidas a confirmar** — todo item onde "Quem gastou" foi decidido por suposição/regra do
  remetente em vez de citação explícita, ou onde qualquer campo ficou incerto. O Supervisor
  deve levar essas dúvidas ao usuário antes de acionar o `ep-lancador-notas`.

## Regra de ouro

Na dúvida sobre obra, fornecedor, quem gastou ou qualquer mapeamento — pare e pergunte ao
usuário. Não entregue um item como "Confirmado: sim" se você mesmo não tem certeza.

## Log de mudanças

- **04/08/2026** — revisão comparando contra a skill antiga (`lancamento-notas-obra-ep`) e
  esclarecimentos do Guilherme: (1) resolvido "AS"="AF" (Marechal, mesma obra em versões
  diferentes); (2) confirmado que obra "DG"/"Aptos Leilão" nunca entra aqui — sistema próprio
  do DG Revy; (3) adicionada ordem de prioridade explícita (item 10.1) para decidir "quem
  gastou" quando a legenda não é clara — antes as regras de remetente (item 6) e final de
  cartão (item 10) não tinham precedência definida entre si, o que podia gerar atribuição
  errada quando as duas se aplicavam ao mesmo item; (4) item 9 corrigido — o gatilho da regra
  de caixa não é a categoria do gasto (estacionamento foi só o exemplo que apareceu primeiro),
  é a **forma de pagamento**: qualquer valor pago em dinheiro/Pix pessoal do técnico é gasto de
  caixa por definição, independente da palavra "caixa"/"dinheiro" aparecer na legenda ou do
  tipo de despesa.
