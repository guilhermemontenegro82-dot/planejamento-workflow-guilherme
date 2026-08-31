# Leia-me — Ordem de instalação no Cowork

Revisão do pipeline modular (piloto) de lançamento de notas fiscais da EP Engenharia
— `supervisor-lancamento-ep` já existia no Cowork antes desta revisão; aqui ele volta
corrigido, com um agente novo, junto com as skills que ele orquestra. Construído e
revisado nesta pasta antes de qualquer coisa voltar pro Cowork.

## Mapa geral da pasta

**Skills de execução (nesta ordem de uso, dentro do pipeline)**
- `skill-ep-leitor-notas.md` — Etapa 1: lê a fonte (WhatsApp ou pasta), extrai dados.
- `skill-ep-lancador-notas.md` — Etapa 2: escreve na aba LANÇAMENTO, uma obra por vez.
- `skill-ep-pintor-notas.md` — Etapa 3: pinta linhas, confere, devolve a planilha, uma
  obra por vez. Sem alteração de conteúdo nesta revisão, só trazida pra cá como
  referência.

**Removida desta pasta**: `notas-fiscais-ml` é exclusiva do fluxo de lançamento do
DG Revy — nunca fez parte do pipeline EP. Tinha sido extraída aqui por engano numa
revisão anterior (de um documento maior, "Fluxo Completo de Notas Fiscais de Obra",
que misturava as duas coisas); movida pra fora desta pasta em 05/08/2026, a pedido do
Guilherme. O motivo de fundo: o fluxo EP **não precisa do número oficial da NF do
Mercado Livre** (só data e valor) — diferente do DG, onde o número é obrigatório
(imposto de renda). Itens de compra do ML no `ep-leitor-notas` usam o campo Nota =
"ML" (valor final, não uma pendência) — não "Pendente" como antes.

**Verificação (rodam em paralelo, entre a Etapa 1 e o checkpoint com o usuário)**
- `agente-chequer-leitura.md` — confere **cobertura**: alguma mensagem com sinal
  financeiro ficou de fora da lista do Leitor? Antes era a skill `ep-chequer-leitura`;
  agora é agente, contexto isolado, mesmo motivo que levou os chequers de Orçamentos a
  virarem agentes.
- `agente-chequer-classificacao.md` — **novo nesta revisão**. Confere **classificação**:
  os campos (obra, fornecedor, quem gastou, REEMB) que o Leitor preencheu batem com o
  conteúdo real da mensagem? Reclassifica cada item de forma independente, sem ver a
  resposta do Leitor até depois de concluir a própria, e só então compara. Existe
  porque o Chequer de Leitura nunca checou isso — só cobertura.

**Orquestração (por último, referencia tudo acima pelo nome)**
- `skill-supervisor-lancamento-ep.md` — chama as skills e os 2 agentes, agrupa a lista
  confirmada por obra, e repete o lançamento/pintura uma vez por obra.

## O que mudou nesta revisão (04/08/2026)

**Primeira rodada:**
1. `ep-chequer-leitura` virou agente (`agente-chequer-leitura.md`).
2. `ep-leitor-notas`: ordem de prioridade explícita (item 10.1) pra decidir "quem
   gastou" — antes as regras de remetente e final de cartão não tinham precedência
   definida entre si.
3. `ep-leitor-notas`: resolvido "AS" = "AF" (Marechal) e confirmado que obra
   "DG"/"Aptos Leilão" nunca entra aqui.
4. `skill-supervisor-lancamento-ep.md`: corrigida referência confusa ("arquivo da
   Etapa 5") e atualizada invocação do Chequer para agente, não skill.

**Segunda rodada (correção do Guilherme sobre a regra de caixa):**
5. `ep-leitor-notas`, item 9: o gatilho da regra de caixa **não é a categoria do
   gasto** (estacionamento foi só o primeiro exemplo) — é a **forma de pagamento**.
   Qualquer valor pago em dinheiro/Pix pessoal do técnico é gasto de caixa por
   definição, independente da palavra "caixa"/"dinheiro" aparecer na legenda.

**Terceira rodada (revisão completa do pipeline, a pedido do Guilherme):**
6. **Criado o Agente Chequer de Classificação** — o pipeline não tinha nenhuma
   checagem semântica (obra/fornecedor/quem gastou), só cobertura e checagem
   mecânica (soma, formatação). Mesmo tipo de buraco já corrigido em Orçamentos com
   o Chequer de Conteúdo. Pipeline passou de 4 para 5 etapas (a nova Etapa 1.6 roda
   em paralelo com a 1.5).
7. **Roteamento por obra**: `ep-lancador-notas` estava escrita como se sempre
   existisse uma única planilha na conversa — mas uma leitura normal do WhatsApp
   cobre várias obras ao mesmo tempo. Supervisor ganhou um passo de agrupamento por
   obra, e o lançamento/pintura agora repete uma vez por grupo.

**Quarta rodada (correção do Guilherme sobre escopo):**
8. `notas-fiscais-ml` **removida deste pipeline** — é exclusiva do fluxo DG Revy.
   Todas as sugestões de rodá-la (aqui, no `ep-leitor-notas`, no `ep-pintor-notas`)
   foram retiradas. O arquivo saiu desta pasta.
9. **Resolvido de vez**: confirmado que o fluxo EP não precisa do número oficial da
   NF do Mercado Livre — só data e valor (o DG precisa, uso no imposto de renda
   dele). Campo Nota de compras do ML passou de "Pendente" para **"ML"** (final, sem
   pendência). Removida do fechamento do Supervisor a menção a itens pendentes.

## Ordem de instalação sugerida

1. Criar `agente-chequer-classificacao.md` no Cowork (agente novo).
2. Atualizar `agente-chequer-leitura.md` — se ainda existir como skill
   (`ep-chequer-leitura`), remover essa versão antiga e recriar como agente, não
   editar por cima.
3. Atualizar `skill-ep-leitor-notas.md`.
4. Atualizar `skill-ep-lancador-notas.md` (nota de escopo "uma obra por vez").
5. Atualizar `skill-ep-pintor-notas.md` (removida a sugestão de rodar
   `notas-fiscais-ml`).
6. Atualizar `skill-supervisor-lancamento-ep.md` por último — ele referencia os dois
   Chequers e o agrupamento por obra.
7. **Se `notas-fiscais-ml` estiver instalada no Cowork como parte deste fluxo EP**
   (por causa da revisão anterior), remover essa associação — a skill em si continua
   existindo e ativa, só não deve mais ser chamada a partir daqui, só do fluxo DG.

## Ainda em aberto

- **Mapeamento obra → pasta/planilha**: o Supervisor agora agrupa por obra antes de
  lançar, mas o `ep-lancador-notas` ainda não sabe converter "MC-Ipanema" no caminho
  real da planilha daquela obra — precisa confirmar com o Guilherme como esse
  mapeamento existe hoje (pasta-raiz com subpastas por obra? lista fixa?).
- Confirmar com o Guilherme se existem outras categorias de gasto sempre pagas do
  caixa pessoal do técnico além dos já cobertos pela regra de forma de pagamento.
- Fase de auditoria de dados: cruzar a planilha real de lançamentos + amostra de
  notas do WhatsApp, incluindo conferir especificamente se o item de R$66,70 sem nota
  correspondente (MC-Ipanema, mencionado no `ep-lancador-notas` como incidente já
  ocorrido) já foi corrigido.
- A skill `lancamento-notas-obra-ep` (fluxo único antigo, ainda ativa para pedidos
  genéricos) não foi revisada ainda.
- `agente-chequer-classificacao.md` duplica as tabelas de referência do
  `ep-leitor-notas` (apelidos de obra, convenções por técnico etc.) — se uma regra
  mudar num lugar, precisa lembrar de mudar no outro. Diferente de Orçamentos, não
  há um arquivo-modelo pra reler e eliminar esse risco por completo.

## Se algo der errado

Volta pra mim (nesta mesma pasta/projeto) com: qual skill/etapa estava rodando, o que
você esperava, o que aconteceu de fato. Eu corrijo o arquivo aqui, você cola a versão
corrigida de volta — mesmo fluxo que usamos em Orçamentos.
