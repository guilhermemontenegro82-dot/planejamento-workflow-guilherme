---
name: "supervisor-lancamento-ep"
description: "Orquestra o pipeline modular (piloto) de lançamento de notas fiscais da EP Engenharia em 5 etapas — ep-leitor-notas → Agente Chequer de Leitura + Agente Chequer de Classificação (paralelo) → ep-lancador-notas → ep-pintor-notas — com pausa para o usuário confirmar dúvidas entre a leitura e a escrita. Ainda convive com a skill lancamento-notas-obra-ep (fluxo único, já validado). Use esta skill SOMENTE quando o usuário disser explicitamente algo como \"Supervisor de lançamento EP, vamos começar\", \"roda o supervisor EP\", \"testa o supervisor da EP\". Pedidos genéricos de lançamento de notas EP (\"lança as notas de hoje\", \"tem notas pra lançar\", \"notas na pasta\") continuam acionando a skill lancamento-notas-obra-ep até este piloto ser validado pelo usuário."
---

# Supervisor — Lançamento de Notas EP

## O que é isso

Versão modular, em teste, do fluxo de lançamento de notas da EP. Em vez de uma skill única
fazendo tudo, o trabalho é dividido em 5 etapas — 3 skills e 2 agentes — chamadas por este
Supervisor:

1. **`ep-leitor-notas`** (skill) — lê a fonte (WhatsApp ou pasta) e extrai os dados, sem
   baixar nada.
2. **Agente Chequer de Leitura** (agente, contexto isolado) — relê o grupo do zero, de forma
   independente, e confere se alguma mensagem com sinal financeiro ficou de fora da lista do
   Leitor. Roda em paralelo com o item 3 abaixo.
3. **Agente Chequer de Classificação** (agente, contexto isolado) — reclassifica obra,
   fornecedor, quem gastou e REEMB de cada item direto da mensagem original, **sem ver a
   classificação do Leitor até depois de concluir a própria**, e só então compara. Existe
   porque o Chequer de Leitura só confere cobertura, nunca se os campos preenchidos estão
   certos — sem este agente, um erro de classificação confiante do Leitor passava direto.
   Roda em paralelo com o item 2.
4. **`ep-lancador-notas`** (skill) — escreve os dados na aba LANÇAMENTO.
5. **`ep-pintor-notas`** (skill) — pinta as linhas por técnico e faz a conferência final.

**Por que dividir**: cada etapa carrega só as próprias instruções, em vez de uma skill gigante
inteira toda vez — e cada uma tem uma responsabilidade única, o que facilita achar e corrigir
erros específicos (ex.: se o problema for sempre na pintura, mexe só no `ep-pintor-notas`, sem
tocar no resto).

**Por que os Chequers são agentes e as outras 3 são skills**: os dois Chequers existem pra dar
um "olhar fresco" sobre o que o Leitor já leu/decidiu — isso só é garantido de verdade rodando
em contexto isolado (agente), não pedindo pro mesmo processo "fingir que não viu" dentro da
mesma conversa. As outras 3 etapas são sequenciais e dependem do resultado da anterior — não
precisam de isolamento de contexto, precisam de execução em ordem.

**Por que dois Chequers, não um**: cobertura ("alguma mensagem ficou de fora?") e classificação
("os campos que preencheram estão certos?") são perguntas diferentes — um item pode estar
100% coberto e ainda assim classificado errado, ou vice-versa. Separar deixa cada um focado
numa pergunta só, mesmo padrão de Orçamentos (Chequer Técnico vs. Chequer de Conteúdo, ali por
motivo de *método* de verificação; aqui por *o que* está sendo verificado).

A skill antiga **`lancamento-notas-obra-ep`** continua ativa e é quem responde a pedidos
genéricos ("lança as notas de hoje", "notas na pasta"). Este Supervisor só entra quando chamado
explicitamente pelo nome — é o piloto sendo validado antes de virar o fluxo padrão.

## Passo a passo

### 1. Confirmar a fonte com o usuário (se não estiver óbvio)

Pergunte (ou confirme pelo contexto da conversa): as notas estão soltas no grupo do WhatsApp
"EP - Notas fiscais", ou já numa pasta local "Notas" de alguma obra?

### 2. Etapa 1 — Leitura

Invoque a skill `ep-leitor-notas` (via ferramenta Skill). Ao final, você deve ter:

- Uma lista de itens de lançamento (obra, descrição, fornecedor, nota, data, valor, quem
  gastou, REEMB, confirmado?).
- Uma lista de aportes de caixa (não entram na planilha).
- Uma lista de dúvidas (itens onde "confirmado?" = não, ou qualquer campo incerto).
- O ponto de corte usado (mensagem "Atualizado até aqui" ou equivalente).

### 3. Etapas 1.5 e 1.6 — Conferência, em paralelo

Invoque os dois agentes ao mesmo tempo (via ferramenta Agent/Task, não Skill — são agentes,
contexto isolado). Eles não dependem um do resultado do outro:

- **Agente Chequer de Leitura** (Etapa 1.5) — recebe o ponto de corte e as listas que o
  `ep-leitor-notas` entregou (lançamentos + aportes de caixa). Relê o grupo do zero e aponta
  qualquer mensagem com sinal financeiro sem correspondência em nenhuma das duas listas.
- **Agente Chequer de Classificação** (Etapa 1.6) — recebe as mensagens originais do período +
  a lista do `ep-leitor-notas`. Reclassifica cada item de forma independente (sem ver a
  classificação do Leitor até concluir a própria) e aponta divergência de campo (obra,
  fornecedor, quem gastou, REEMB).

Tratamento do resultado dos dois:

- **Chequer de Leitura aponta divergência**: volte ao `ep-leitor-notas` para extrair os dados
  completos do(s) item(ns) que faltou(faltaram) antes de prosseguir — nunca leve uma
  divergência de cobertura em aberto para o checkpoint.
- **Chequer de Classificação aponta divergência**: **não decida sozinho qual dos dois chequers
  está certo**. Adicione o item à lista de dúvidas (mesmo que o `ep-leitor-notas` o tivesse
  marcado "Confirmado: sim"), mostrando as duas classificações candidatas e o critério usado
  por cada uma — vira pergunta pro usuário no checkpoint, não uma correção automática.
- **Os dois aprovam sem ressalva**: siga para o checkpoint normalmente.

### 4. Checkpoint com o usuário

Se houver qualquer dúvida — da lista original da Etapa 1, ou adicionada pela divergência do
Chequer de Classificação (Etapa 1.6) — **pare e pergunte ao usuário antes de continuar**;
mostre os itens em questão e o que está incerto (obra? fornecedor? quem gastou? — e, quando
vier do Chequer de Classificação, as duas classificações candidatas lado a lado). Só avance
para a Etapa 2 com a lista 100% confirmada e a cobertura já validada pela Etapa 1.5.

### 5. Agrupar por obra antes de lançar

**A lista confirmada normalmente cobre mais de uma obra numa única leitura** — o grupo do
WhatsApp "EP - Notas fiscais" reúne notas de todas as obras, não de uma só. Agrupar a lista
confirmada por "Obra" e repetir os passos 6 e 7 abaixo **uma vez por grupo**, cada vez
apontando o `ep-lancador-notas`/`ep-pintor-notas` para a planilha de controle financeiro
daquela obra específica — nunca tentar lançar itens de obras diferentes na mesma execução do
Lançador. **Achado em revisão (04/08/2026)**: nem o `ep-lancador-notas` nem o
`ep-pintor-notas` tratam disso sozinhos — os dois foram escritos como se sempre existisse uma
única planilha na conversa, então o agrupamento é responsabilidade do Supervisor.

### 6. Etapa 2 — Lançamento (por obra)

Para cada grupo de itens de uma mesma obra: invoque a skill `ep-lancador-notas`, passando só os
itens dessa obra + o caminho da planilha de controle financeiro correspondente. Ela escreve as
linhas na cópia local da planilha e devolve o caminho do arquivo + intervalo de linhas
escritas.

### 7. Etapa 3 — Pintura e conferência (por obra)

Para o mesmo grupo: invoque a skill `ep-pintor-notas`, passando o arquivo devolvido pela Etapa
2 (Lançamento) + a lista de itens **dessa obra** (para conferência de soma). Ela pinta, confere
e devolve a planilha ao computador do usuário, com o relatório final daquela obra.

### 8. Fechamento

Depois de repetir os passos 6 e 7 para todas as obras da lista, apresente ao usuário:

- A tabela final de lançamentos de **cada obra** (vinda do `ep-pintor-notas`), separadas por
  obra, não misturadas numa tabela só.
- A lista de aportes de caixa, separada.
- Como isto é um piloto: pergunte se o usuário quer comentar algo que não bateu com o esperado,
  para ajustar a etapa específica (Leitor, algum dos dois Chequers, Lançador ou Pintor) antes
  da próxima obra.

## Regra de ouro geral

Na dúvida sobre qualquer coisa — obra, fornecedor, quem gastou, formato — pare e pergunte antes
de escrever ou pintar. Isso vale em qualquer uma das etapas.

## Log de mudanças

- **04/08/2026** — Etapa 1.5 (Chequer) passou a ser invocada como agente, não skill (ver
  `agente-chequer-leitura.md`). Corrigida referência confusa no passo 6 ("arquivo da Etapa 5",
  que não existia — era o número do passo, não o nome da etapa do pipeline) para "arquivo
  devolvido pela Etapa 2 (Lançamento)".
- **04/08/2026 (segunda rodada — revisão completa do pipeline)** — dois achados: (1) não
  existia checagem semântica de classificação (obra/fornecedor/quem gastou), só cobertura —
  criado o **Agente Chequer de Classificação** (Etapa 1.6, roda em paralelo com o Chequer de
  Leitura), e o pipeline foi renumerado de 4 para 5 etapas; (2) `ep-lancador-notas` e
  `notas-fiscais-ml` foram escritos como se sempre existisse uma única planilha na conversa,
  mas uma leitura normal cobre várias obras — adicionado passo 5 (agrupar por obra) e os
  passos de lançamento/pintura passaram a repetir por obra, não rodar uma vez só pra lista
  inteira.
- **04/08/2026 (terceira rodada — correção do Guilherme)** — `notas-fiscais-ml` é exclusiva
  do fluxo de lançamento do DG Revy, nunca fez parte deste pipeline EP. Removidas todas as
  sugestões de rodar essa skill (aqui, no `ep-leitor-notas` e no `ep-pintor-notas`).
- **05/08/2026 — resolvido de vez**: o Guilherme confirmou que o fluxo EP **não precisa do
  número oficial da NF do Mercado Livre** — só data e valor, diferente do DG (onde o número é
  obrigatório, uso no imposto de renda dele). O campo "Nota" de compras do ML passou de
  "Pendente" (sugeria pendência a resolver) para **"ML"** (valor final, sem ação seguinte).
  Removida do fechamento (passo 8) a menção a itens pendentes de ML — não existe mais nada
  pendente por definição.
