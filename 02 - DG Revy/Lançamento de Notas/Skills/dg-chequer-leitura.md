---
name: "dg-chequer-leitura"
description: "Etapa 1.5 do pipeline \"Supervisor de lançamento DG\": roda logo depois do dg-leitor-notas e antes do checkpoint com o usuário. Relê o mesmo grupo de WhatsApp da obra, do zero, em modo normal (sem lightbox), e cruza toda mensagem com sinal financeiro contra a lista que o dg-leitor-notas entregou — apontando qualquer item que tenha ficado de fora antes de qualquer coisa ser lançada. Não decide dados de negócio (fornecedor, quem gastou) nem escreve nada — só confere cobertura. Só deve ser chamada pela skill supervisor-lancamento-dg, logo após o dg-leitor-notas."
---

---
name: "dg-chequer-leitura"
description: "Etapa 1.5 do pipeline \"Supervisor de lançamento DG\": roda logo depois do dg-leitor-notas e antes do checkpoint com o usuário. Relê o mesmo grupo de WhatsApp da obra, do zero, em modo normal (sem lightbox), e cruza toda mensagem com sinal financeiro contra a lista que o dg-leitor-notas entregou — apontando qualquer item que tenha ficado de fora antes de qualquer coisa ser lançada. Não decide dados de negócio (fornecedor, quem gastou) nem escreve nada — só confere cobertura. Só deve ser chamada pela skill supervisor-lancamento-dg, logo após o dg-leitor-notas."
---

## Papel nesta pipeline

Etapa 1.5 do fluxo `supervisor-lancamento-dg`. Roda **depois do `dg-leitor-notas`** e **antes
do checkpoint com o usuário**. Existe porque o `dg-leitor-notas` pode passar por cima de uma
mensagem sem perceber — não por falta de regra, mas porque quem já leu 20 comprovantes seguidos
tende a relaxar exatamente no 21º. Um segundo agente, sem o cansaço/viés da primeira leitura e
com uma tarefa única (conferir cobertura), pega isso com muito mais confiabilidade do que pedir
para o mesmo agente "reler com atenção".

**Não é um revisor de dados** — não questiona se o fornecedor está certo, se "quem gastou" foi
bem atribuído, ou se o valor está certo. Isso é problema do `dg-leitor-notas` (e, depois, do
`dg-lancador-notas`). O Chequer só responde a uma pergunta: **"alguma mensagem do período ficou
de fora da lista?"**

## Objetivo

Reler o mesmo grupo de WhatsApp da obra, do mesmo ponto de corte usado pelo `dg-leitor-notas`
até a mensagem mais recente, listando **toda mensagem com qualquer sinal financeiro** (foto de
nota/comprovante, PDF, ou texto mencionando compra/pagamento/aporte/reembolso) — e cruzar essa
lista bruta contra a lista estruturada que o `dg-leitor-notas` entregou.

## Passo a passo

### 1. Receber da Etapa 1

- O nome/grupo da obra e o ponto de corte usado (texto e horário da mensagem "Atualizado até
  aqui" ou equivalente).
- A lista de itens que o `dg-leitor-notas` entregou (arquivo temporário, obra, quem gastou,
  valor, data, observações).

### 2. Reler do zero, em modo normal — não lightbox

- Abra o grupo da obra no WhatsApp Web e vá até o ponto de corte.
- **Role o histórico normal do chat (não o filminho/lightbox)**, mensagem por mensagem, até o
  fim. O lightbox agrupa imagens em sequência e facilita pular uma mensagem colada em outra no
  mesmo minuto — o modo normal mostra a ordem real, com o texto de contexto ao redor.
- Vá devagar: prefira telas menores de rolagem e conferir cada uma, a rolar rápido demais e
  confiar na memória do que já viu.
- Não pule mensagens de texto puro (sem foto) — pagamento avisado só por escrito, ou legenda
  detalhada sobre um comprovante que apareceu antes/depois, conta como sinal financeiro.

### 3. Montar a lista bruta

Para cada mensagem com sinal financeiro no intervalo, anote só o suficiente para identificar:
horário, tipo (foto / PDF / texto), e uma descrição de uma linha (ex.: "14:32 foto — comprovante
Pix Casa Cartrill", "08:39 texto — compra de areia pelo Mestre, sem nota"). Não precisa (e não
deve) decidir fornecedor exato, quem gastou ou valor definitivo aqui — só identificar que a
mensagem existe.

### 4. Cruzar contra a lista do Leitor

- Cada mensagem da lista bruta deve corresponder a exatamente um item na lista do
  `dg-leitor-notas` (ou fazer parte de um item multi-comprovante já sinalizado por ele).
- **Mensagem sem correspondência na lista do Leitor** → possível item perdido. Anote horário e
  descrição breve.
- **Item do Leitor sem mensagem correspondente** (mais raro) → possível duplicata ou dado
  inventado. Anote também.
- Mensagens que claramente não são financeiras (figurinha, "bom dia", localização, assunto de
  obra sem valor envolvido) não entram na lista bruta e não geram divergência.

### 5. Reportar ao Supervisor

- **Cobertura 100%**: "Reli o grupo do zero, todas as mensagens do período batem com a lista do
  Leitor. Nada a ajustar."
- **Divergência encontrada**: liste cada mensagem sem correspondência (horário + descrição
  breve) e devolva ao Supervisor. O Supervisor decide se manda de volta ao `dg-leitor-notas`
  para extrair os dados completos daquele item **antes** de levar qualquer coisa ao checkpoint
  com o usuário — nunca deixe passar para a Etapa 2 com uma divergência em aberto.

## Regra de ouro

Não decida dado de negócio nenhum (fornecedor, quem gastou, valor) e não escreva em planilha ou
mova arquivo nenhum — isso não é papel do Chequer. Se não tiver certeza se uma mensagem é ou não
sinal financeiro, inclua na lista bruta mesmo assim — é mais barato revisar um item que não era
nada do que deixar passar um que era.

## Troubleshooting

| Problema | Solução |
|---|---|
| Duas mensagens muito próximas em horário (mesmo minuto) | Trate como duas mensagens distintas até confirmar que são a mesma coisa — não assuma duplicata |
| Foto "Encaminhada" com legenda escrita por Guilherme logo abaixo | São a mesma mensagem (a legenda é o comentário sobre a foto acima) — mas confira se não existe uma segunda foto colada que é outro item |
| Não lembra se já viu essa mensagem na Etapa 1 | Não importa — o Chequer relê do zero, ignore o que a Etapa 1 fez e monte a lista bruta de forma independente |
| Screenshot do WhatsApp Web trava com timeout | A página costuma continuar respondendo — espere e tente de novo |

