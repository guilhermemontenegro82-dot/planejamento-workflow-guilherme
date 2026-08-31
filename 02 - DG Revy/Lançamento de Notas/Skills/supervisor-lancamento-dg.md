---
name: "supervisor-lancamento-dg"
description: "Orquestra o pipeline modular (piloto) de lançamento de notas fiscais das obras DG em 6 etapas fixas — dg-leitor-notas → dg-chequer-leitura → dg-lancador-notas → dg-organizador-notas → dg-conferidor-notas → dg-pintor-notas — mais uma Etapa fixa de fechamento (dg-limpador-notas), que organiza a Downloads e encerra o ciclo comum, seguida de um checkpoint perguntando se roda a Etapa condicional (skill notas-fiscais-ml — normalmente só a cada 2-3 ciclos, não em todo lançamento) e, se aprovada e executada, uma segunda passada do dg-limpador-notas para varrer os PDFs que ela baixou. Ainda convive com a skill lancamento-notas-obra-dg (fluxo único, já validado). Use esta skill SOMENTE quando o usuário disser explicitamente algo como \"Supervisor de lançamento DG, vamos começar\", \"roda o supervisor DG\", \"testa o supervisor do DG\". Pedidos genéricos de lançamento de notas DG (\"lança as notas de hoje\", \"tem notas pra lançar\") continuam acionando a skill lancamento-notas-obra-dg até este piloto ser validado pelo usuário."
---

## O que é isso

Versão modular, em teste, do fluxo de lançamento de notas do DG. O trabalho é dividido em 6
etapas fixas + 1 etapa fixa de fechamento + 1 checkpoint + 1 etapa condicional + 1 possível
segunda passada de limpeza, cada uma sua própria skill, chamadas em sequência por este
Supervisor:

1. **`dg-leitor-notas`** — busca no grupo de WhatsApp da obra (ou pasta local) e baixa TUDO
   (JPG, PDF, prints de PIX), lê texto puro também.
2. **`dg-chequer-leitura`** — relê o mesmo grupo do zero, de forma independente, e confere se
   alguma mensagem com sinal financeiro ficou de fora da lista do Leitor. Roda antes de
   qualquer coisa ser mostrada ao usuário ou escrita na planilha.
3. **`dg-lancador-notas`** — escreve os dados na aba LANÇAMENTO, resolve fluxo
   multi-comprovante e marca ML como "Pendente".
4. **`dg-organizador-notas`** — move e numera os arquivos na pasta Notas/Numeradas de cada
   obra (incluindo o caso de item com múltiplos arquivos).
5. **`dg-conferidor-notas`** — valida a sequência numérica dos arquivos contra a planilha.
6. **`dg-pintor-notas`** — pinta as linhas por técnico, confere soma/formatação e devolve a
   planilha ao usuário.
7. **`dg-limpador-notas`** (fixa) — roda **logo depois** do `dg-pintor-notas` confirmar que a
   planilha foi salva com sucesso, fechando o ciclo comum de lançamento (inclusive a limpeza da
   Downloads) — **antes** da etapa do Mercado Livre, não depois. Move pra `Downloads/Deletar`
   os arquivos temporários que o `dg-leitor-notas` baixou nesta rodada, já com cópia confirmada
   (mesmo tamanho em bytes) na pasta Numeradas/Recibos adm.
8. **Checkpoint** — só se houver item "Pendente" do Mercado Livre, pergunta ao usuário se quer
   rodar a busca de NF agora ou deixar acumulando pros próximos ciclos.
9. **`notas-fiscais-ml`** (condicional, só se aprovada no checkpoint) — busca as notas fiscais
   oficiais dos itens marcados "Pendente" no Mercado Livre. **Não roda em todo ciclo** — muitas
   NFs do ML só ficam disponíveis um tempo depois da entrega do material, então o usuário
   normalmente prefere rodar essa etapa a cada 2-3 ciclos de lançamento, não em todo lançamento.
10. **`dg-limpador-notas`** (segunda passada, só se a Etapa 9 rodou) — a `notas-fiscais-ml`
    também pode baixar PDFs pra Downloads; se ela rodou, chama `dg-limpador-notas` mais uma vez
    ao final pra varrer esses arquivos novos também, fechando de vez o ciclo.

**Diferença importante em relação ao EP**: cada obra DG tem **seu próprio grupo de WhatsApp**
(a EP usa um grupo único para todas as obras), e a DG **precisa dos arquivos físicos salvos e
numerados** (a EP só precisa dos dados, sem arquivo) — por isso o DG tem mais etapas que o EP.

A skill antiga **`lancamento-notas-obra-dg`** continua ativa e responde a pedidos genéricos
("lança as notas de hoje", "notas na pasta"). Este Supervisor só entra quando chamado
explicitamente pelo nome — é o piloto sendo validado.

## Passo a passo

### 1. Confirmar obra e fonte

Pergunte (ou confirme pelo contexto): qual obra DG vamos processar, e as notas estão soltas no
grupo de WhatsApp daquela obra, ou já numa pasta local?

**Cuidado ao localizar a pasta/planilha da obra** — confirmado pelo usuário como risco real:

- Os nomes das pastas de obra **não seguem um padrão fixo**. Às vezes o número do apartamento
  vem antes do número do prédio, às vezes o nome da rua vem no final do nome da pasta, etc.
  Leia o nome completo da pasta com atenção — não confie em bater só uma palavra-chave (ex.:
  "Leme", "Prudente", "Visconde") pra identificar a obra certa.
- **Só use pastas que estão direto dentro de `599 - DG - Planilha de mão de obra - Aptos
  Leilão`** — essas são as obras vigentes (em andamento). **Nunca use nada dentro de `Obras
  Concluídas`** — são obras já finalizadas, sem mais lançamento.
- **Nomes de rua se repetem.** Uma obra concluída pode ter o mesmo nome de rua (ou nome
  parecido) de uma obra nova, vigente, que abriu depois no mesmo endereço ou perto dele. Antes
  de abrir qualquer planilha, confirme que o caminho encontrado está dentro da pasta raiz das
  obras vigentes, nunca dentro de `Obras Concluídas` — mesmo que o nome pareça bater.
- Quando uma obra vigente for concluída, ela migra pra `Obras Concluídas` e para de receber
  lançamento. Vai sempre existir a possibilidade de obras novas abrirem com nomes de rua iguais
  ou parecidos aos de obras já concluídas — o procedimento de lançamento é o mesmo, só muda a
  pasta e os dados específicos daquela obra.

### 2. Etapa 1 — Busca e download

Invoque `dg-leitor-notas` (via ferramenta Skill). Ao final, você deve ter: lista de arquivos
baixados com dados identificados (obra, quem gastou, valor, data, observações — incluindo
sinalização de itens multi-comprovante) + lista de dúvidas + o ponto de corte usado (mensagem
"Atualizado até aqui" ou equivalente).

### 3. Etapa 1.5 — Conferência da leitura

Invoque `dg-chequer-leitura`, passando o ponto de corte e a lista completa que o
`dg-leitor-notas` acabou de entregar. Ela relê o grupo do zero, de forma independente, e aponta
qualquer mensagem com sinal financeiro que não tenha correspondência na lista.

- **Cobertura 100%**: siga para o checkpoint normalmente.
- **Divergência apontada**: volte ao `dg-leitor-notas` para extrair os dados completos do(s)
  item(ns) que faltou(faltaram) antes de prosseguir — nunca leve uma divergência em aberto para
  o checkpoint com o usuário.

### 4. Checkpoint com o usuário

Se houver qualquer dúvida na lista da Etapa 1 (já com a cobertura confirmada pela Etapa 1.5),
**pare e pergunte antes de continuar**. Só avance com a lista confirmada.

### 5. Etapa 2 — Lançamento

Invoque `dg-lancador-notas`, passando a lista confirmada. Ela escreve as linhas na cópia local
da planilha e devolve: caminho do arquivo, itens escritos (número da linha + arquivos
associados a cada um), e quais itens ficaram com Nota = "Pendente" (Mercado Livre) — guarde
essa lista, ela decide se o checkpoint da Etapa 9 aparece mais à frente.

### 6. Etapa 3 — Organização dos arquivos

Invoque `dg-organizador-notas`, passando a lista de itens + arquivos da Etapa 2. Ela move e
numera tudo na pasta Notas/Numeradas da obra.

### 7. Etapa 4 — Conferência da numeração

Invoque `dg-conferidor-notas`. Se ela reportar divergência, volte para a etapa indicada
(`dg-lancador-notas` ou `dg-organizador-notas`) antes de prosseguir — não pule para a pintura
com numeração suja.

### 8. Etapa 5 — Pintura e conferência final

Só depois do Conferidor validar limpo, invoque `dg-pintor-notas`. Ela pinta, confere soma e
formatação, e devolve a planilha ao computador do usuário com o relatório final. **Anote se o
commit final foi bem-sucedido** — é a condição nº 1 tanto para a Etapa 6 (limpeza) quanto,
depois, para o checkpoint da Etapa 9 (Mercado Livre).

### 9. Etapa 6 — Limpeza da pasta Downloads (fixa, fecha o ciclo comum)

Roda assim que o `dg-pintor-notas` confirmar que a planilha foi salva com sucesso — **antes**
da etapa do Mercado Livre, não depois. Se o commit da Etapa 5 falhou, **não invoque esta
etapa** — não mexa em nada enquanto a planilha final não estiver salva de verdade.

Invoque `dg-limpador-notas`. Ela move pra `Downloads/Deletar` os arquivos temporários desta
rodada que já têm cópia confirmada (mesmo tamanho em bytes) na pasta Numeradas/Recibos adm, e
reporta quantos moveu e quais (se algum) pulou. **Ela nunca apaga nada de fato** — só organiza;
a exclusão final é sempre uma decisão do usuário, no computador dele.

Com isso, o **ciclo comum de lançamento está encerrado** — planilha salva e Downloads
organizada — independente do que acontecer na próxima etapa, que é opcional.

### 10. Checkpoint — rodar o Mercado Livre agora?

Só ofereça este checkpoint se **as duas condições** forem verdadeiras:

1. O `dg-pintor-notas` confirmou o commit com sucesso (mesma condição da Etapa 6).
2. Existe pelo menos um item lançado nesta rodada com Nota = "Pendente" (lista que veio da
   Etapa 2).

**Nenhum item pendente? Pule o checkpoint inteiro** — não vale nem perguntar.

Havendo item pendente, pergunte explicitamente — não rode a `notas-fiscais-ml` sem essa
confirmação: "Ficaram X itens do Mercado Livre pendentes de NF. Quer rodar a busca agora, ou
deixar acumulando pros próximos ciclos?" **Essa etapa normalmente não roda em todo ciclo** — o
usuário costuma preferir rodá-la a cada 2-3 lançamentos, já que muitas NFs do ML só saem um
tempo depois da entrega do material. Não assuma "sim" por padrão.

- **Usuário disse não / adiar**: encerre o Supervisor aqui — o ciclo comum já foi fechado na
  Etapa 6, não fica nada pendente de organização por causa disso.
- **Usuário disse sim**: siga para a Etapa 11.

### 11. Etapa 7 — Buscar notas do Mercado Livre (condicional, aprovada no checkpoint)

Invoque a skill `notas-fiscais-ml` (via ferramenta Skill) já informando de cara o caminho da
planilha (a mesma que já foi salva na Etapa 5) e a estrutura já conhecida (aba LANÇAMENTO,
colunas B-G) — não é preciso repetir as perguntas da "Etapa 0" dela, o Supervisor já sabe as
respostas.

### 12. Etapa 8 — Segunda passada de limpeza (só se a Etapa 11 rodou)

A `notas-fiscais-ml` também pode baixar PDFs pra Downloads. Se ela rodou, invoque
`dg-limpador-notas` **mais uma vez** — ela é segura pra rodar de novo (só move o que ainda não
tinha sido movido e já tem cópia confirmada na pasta definitiva) — pra varrer também esses
arquivos novos, fechando de vez o ciclo.

### 13. Fechamento

Apresente ao usuário:

- A tabela final de lançamentos (vinda do `dg-pintor-notas`).
- Quantos arquivos a Etapa 6 (`dg-limpador-notas`) moveu pra `Downloads/Deletar`.
- Se a Etapa 7 rodou: quais NFs foram encontradas e baixadas, quais itens ficaram como "S/NF"
  (vendedor não emitiu), e quantos arquivos a segunda passada de limpeza (Etapa 8) moveu.
- Se a Etapa 7 não rodou (usuário adiou): lembre quantos itens continuam "Pendente" pra um
  próximo ciclo.
- Como isto é um piloto: pergunte se o usuário quer comentar algo que não bateu com o esperado,
  para ajustar a etapa específica antes da próxima obra.

## Terceiro pagador eventual (sócio/investidor) numa obra específica

Algumas obras têm, além de Guilherme e Mestre, um terceiro pagador ocasional (ex.: um
sócio/investidor da obra, identificado pelo nome próprio, não por apelido/cargo). Isso é
**específico de cada obra** — não altere `dg-leitor-notas` nem `dg-lancador-notas` por causa
disso, é tratado obra a obra:

- Releia como esse terceiro pagador já foi lançado nas linhas anteriores daquela planilha
  (nome exato na coluna I, cor de preenchimento da linha — normalmente um tema diferente do
  tema do Mestre).
- Preste atenção ao que a própria pessoa escreve nas mensagens/comprovantes que ela manda no
  grupo (pedidos explícitos de como lançar, categoria do gasto, etc.) — pode vir instrução
  direta tipo "lança isso como seguro de obra".
- Na dúvida sobre um comprovante desse terceiro pagador (é gasto dele mesmo? é reembolso? qual
  categoria?), pare e pergunte ao usuário antes de lançar — não adivinhe.
- Gastos muito antigos de um terceiro investidor, feitos antes do controle da planilha existir
  (sem comprovante rastreável), são exceção pontual — não tente reconstituir nem lançar
  retroativamente sem o usuário pedir explicitamente.

## Regra de ouro geral

Na dúvida sobre qualquer coisa — obra, fornecedor, quem gastou, numeração, formato, ou se deve
entrar na etapa do Mercado Livre — pare e pergunte antes de escrever, organizar, pintar, mover
arquivo ou navegar no Mercado Livre. Isso vale em qualquer uma das etapas. **Nunca apague
arquivo nenhum permanentemente, em nenhuma etapa** — mover pra `Downloads/Deletar` é o máximo
que qualquer etapa deste pipeline faz.

