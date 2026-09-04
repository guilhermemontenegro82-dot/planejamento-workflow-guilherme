---
name: "supervisor-lancamento-ep"
description: "Orquestra o pipeline modular (piloto) de lançamento de notas fiscais da EP Engenharia em 5 etapas — ep-leitor-notas → Agente Chequer de Leitura + Agente Chequer de Classificação (paralelo) → ep-lancador-notas → ep-pintor-notas — com pausa para o usuário confirmar dúvidas entre a leitura e a escrita. Ainda convive com a skill lancamento-notas-obra-ep (fluxo único, já validado). Use esta skill SOMENTE quando o usuário disser explicitamente algo como \"Supervisor de lançamento EP, vamos começar\", \"roda o supervisor EP\", \"testa o supervisor da EP\". Pedidos genéricos de lançamento de notas EP (\"lança as notas de hoje\", \"tem notas pra lançar\", \"notas na pasta\") continuam acionando a skill lancamento-notas-obra-ep até este piloto ser validado pelo usuário."
---

# Supervisor — Lançamento de Notas EP

## O que é isso

Versão modular, em teste, do fluxo de lançamento de notas da EP. Em vez de uma skill única
fazendo tudo, o trabalho é dividido em 5 etapas — 3 skills e 2 agentes — chamadas por este
Supervisor:

1. **`ep-leitor-notas`** (skill) — lê a fonte (WhatsApp ou pasta), baixa cada comprovante
   para a Downloads como âncora de leitura e extrai os dados **do arquivo**, não da tela.
   Não arquiva nem numera — os arquivos são temporários e vão para `Downloads/Deletar` no
   fim do ciclo (passo 7.1).
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

### 4.1. Montar o Certificado de Verificação

**É este bloco que autoriza a escrita na planilha.** Monte-o juntando os vereditos que os
dois chequers emitiram (não reescreva os números — copie o que eles reportaram):

```
=== CERTIFICADO DE VERIFICAÇÃO — LANÇAMENTO EP ===
Obra(s): <lista das obras da leitura>

[1.5] CHEQUER DE LEITURA ......... APROVADO
      Ponto de corte: <texto e horário>
      Mensagens financeiras no período: <N>
      Itens na lista do Leitor: <N>   |   Aportes de caixa: <N>
      Divergências: nenhuma

[1.6] CHEQUER DE CLASSIFICAÇÃO ... APROVADO
      Itens reclassificados de forma independente: <N>
      Divergências de campo: nenhuma

[Checkpoint] Dúvidas confirmadas pelo Guilherme em: <data/hora>
=== FIM DO CERTIFICADO ===
```

**Só monte o certificado se os dois chequers realmente rodaram e emitiram veredito.** Se
algum não rodou, ou emitiu `REPROVADO`, ou você não tem os números dele — **não monte
nada**. Volte e faça a etapa que faltou. Um certificado montado sem os chequers é pior
que certificado nenhum: dá aparência de verificado ao que não foi.

Passe o certificado para o `ep-lancador-notas` junto com a lista confirmada. Ele foi
instruído a recusar a escrita sem esse bloco.

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

Para cada grupo de itens de uma mesma obra, invoque a skill `ep-lancador-notas` passando **três
coisas** — as três são obrigatórias:

1. **O Certificado de Verificação** (o bloco montado no passo 4.1, com os dois `APROVADO`).
   O Lançador foi instruído a **recusar escrever sem ele** — se você não passar, ele para e o
   lançamento não acontece. Passe o certificado **em toda invocação**, uma vez por obra, não
   só na primeira.
2. Os itens **dessa obra** (só dela, já agrupados).
3. O caminho da planilha de controle financeiro correspondente.

Ela escreve as linhas na cópia local da planilha e devolve o **Comprovante de Escrita**
(caminho do arquivo, intervalo de linhas, soma dos valores) — guarde esse bloco, o passo 7
precisa dele.

### 7. Etapa 3 — Pintura e conferência (por obra)

Para o mesmo grupo, invoque a skill `ep-pintor-notas` passando **duas coisas** — as duas são
obrigatórias:

1. **O Comprovante de Escrita** que a Etapa 2 acabou de emitir (bloco
   `=== COMPROVANTE DE ESCRITA — ETAPA 2 ===`, com arquivo, intervalo de linhas e soma). O
   Pintor foi instruído a **parar sem ele** — sem o comprovante ele não sabe em qual arquivo
   nem em quais linhas trabalhar.
2. A lista de itens **dessa obra** (para conferência de soma).

Ela pinta, confere e devolve a planilha ao computador do usuário, com o relatório final
daquela obra.

### 7.1. Limpeza dos arquivos temporários

**Só depois** de o `ep-pintor-notas` confirmar que a planilha foi salva com sucesso. Se o
commit falhou, **não faça esta limpeza** — não mexa em nada enquanto a planilha final não
estiver salva de verdade.

O `ep-leitor-notas` baixou os arquivos (`ep_tmp_NN.jpg`) só como âncora de leitura — a EP não
arquiva nota. Agora que os dados já estão na planilha:

- Crie a pasta `Downloads/Deletar` se ela ainda não existir.
- **Mova** para lá todos os `ep_tmp_*` desta rodada.
- **Nunca apague nada de fato.** Mover é o máximo que este pipeline faz — a exclusão final é
  decisão do Guilherme, no computador dele.
- Reporte quantos arquivos foram movidos (entra na prestação de contas do passo 8).

### 8. Fechamento — prestação de contas obrigatória

Depois de repetir os passos 6 e 7 para todas as obras da lista, apresente ao usuário:

**8.1. Primeiro, a prestação de contas do pipeline.** Antes de qualquer tabela, esta
lista — dizendo, etapa por etapa, se a skill/agente foi **realmente invocada**:

```
=== PRESTAÇÃO DE CONTAS DO PIPELINE ===
[1]   ep-leitor-notas ................... invocada / NÃO invocada
[1.5] Agente Chequer de Leitura .......... invocado / NÃO invocado  → APROVADO/REPROVADO
[1.6] Agente Chequer de Classificação .... invocado / NÃO invocado  → APROVADO/REPROVADO
[ck]  Checkpoint com o Guilherme .......... feito / NÃO feito
[2]   ep-lancador-notas (por obra) ....... invocada / NÃO invocada
[3]   ep-pintor-notas (por obra) ......... invocada / NÃO invocada
[7.1] Limpeza p/ Downloads/Deletar ....... N arquivos movidos / não executada
=== FIM DA PRESTAÇÃO DE CONTAS ===
```

Regras que valem aqui, e não são negociáveis:

- **Fazer o trabalho "à mão" ou por script, replicando o que a skill pede sem invocá-la,
  conta como `NÃO invocada`.** Não é atalho, é etapa pulada — e tem que aparecer assim.
  Em 27/08/2026 a Etapa 3 foi executada exatamente assim e o relatório não disse nada;
  o Guilherme só descobriu perguntando semanas depois.
- Qualquer `NÃO invocada` ou `REPROVADO` na lista → **avise em destaque, no topo da
  resposta**, que o lançamento saiu sem verificação completa e precisa ser revisado
  manualmente. Nunca entregue um lançamento incompleto com aparência de concluído.
- Não preencher esta lista "por dedução". Se você não tem certeza se uma etapa rodou,
  o valor é `NÃO invocada`.

**8.2. Depois, os resultados:**

- A tabela final de lançamentos de **cada obra** (vinda do `ep-pintor-notas`), separadas por
  obra, não misturadas numa tabela só.
- A lista de aportes de caixa, separada.
- Como isto é um piloto: pergunte se o usuário quer comentar algo que não bateu com o esperado,
  para ajustar a etapa específica (Leitor, algum dos dois Chequers, Lançador ou Pintor) antes
  da próxima obra.

## Regra de ouro geral

Na dúvida sobre qualquer coisa — obra, fornecedor, quem gastou, formato — pare e pergunte antes
de escrever ou pintar. Isso vale em qualquer uma das etapas.
