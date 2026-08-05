---
name: orcamento-ep-precificacao
description: "Quinta etapa do pipeline de orçamento EP Engenharia: lança o preço unitário (material/mão de obra) em cada item da planilha, usando base-de-dados-financeiros-ep como fonte única. Decide a base venda x custo antes de começar, nunca no meio do trabalho. Consulta o catálogo item a item ou o benchmark por disciplina conforme o caso, aplica BDI quando necessário, e nunca deixa um item sem fonte citada no comentário da célula. Acionada pelo Agente Orquestrador — Orçamentos EP depois que Formatação é aprovada pelo Chequer Técnico."
---

# Skill 5 — Precificação

## Quando invocar

Depois que a Skill 4 — Formatação da Planilha for aprovada pelo Chequer Técnico. A
planilha já está com estrutura, quantidade e visual certos — falta só o preço.

## O que esta etapa NÃO faz

Não decide estrutura, grupo, descrição ou quantidade — isso já foi feito. Não monta a
proposta comercial (Skill 6). Não reabre a discussão de venda x custo depois de
decidida no passo 1 — mudar de base no meio reprecifica a planilha inteira.

## Inputs esperados

- Planilha formatada, com todos os itens já com quantidade preenchida.
- Acesso a `base-de-dados-financeiros-ep` (catálogo, benchmark, banco de dados de
  obras — ver ordem de consulta própria dessa skill).

## Passo a passo

### 1. Confirmar a base de preço ANTES de lançar qualquer valor
Ler os fatores BDI/Risco/RT/Impostos (linha 4/5 da planilha):

- **Zerados** → base é **venda**: o resultado final (coluna de preço total) já é o
  preço cobrado do cliente, sem duplicar margem.
- **BDI preenchido (ex.: 25%) com Risco/RT/Impostos zerados** → base é **custo**: a
  própria planilha já tomou essa decisão. Lançar valores de custo puro (do catálogo)
  e deixar a fórmula da planilha aplicar a margem — **não perguntar de novo** nesse
  caso.
- **Qualquer outra combinação** → perguntar ao usuário antes de seguir. Não assumir.

Decidir isso uma única vez, aqui, antes do primeiro item — nunca no meio do trabalho.

### 2. Consultar `base-de-dados-financeiros-ep` para cada item
Seguir a ordem de consulta própria daquela skill:

1. **Catálogo de Preços por Serviço**: filtrar por disciplina + palavra-chave do
   serviço; preferir o **ano mais recente** disponível para aquele serviço; conferir
   que a **unidade bate** antes de usar o valor.
2. Para contextualizar ou quando o item for mais uma estimativa de conjunto que um
   item unitário: usar a aba de **Benchmark** correta conforme o perfil da obra
   (Reforma Completa / Apto 40-200m2 / Geral — ver Skill 1 para o tipo de obra já
   identificado).
3. **Sem nenhum precedente**: pesquisa de mercado — nunca o primeiro valor
   encontrado, usar a **média** de algumas referências, marcar `[MKT]`.
4. Obra fora do perfil apartamento sem cobertura nas abas de Benchmark: usar o
   apêndice legado (margem por tipo de obra) dessa mesma skill, sinalizando
   explicitamente que é dado não auditado.

### 3. Aplicar o BDI quando necessário
Quando a base for **venda** e o valor de origem for custo puro do catálogo: aplicar
o BDI histórico (25% a 30%) por cima antes de lançar.

### 4. Lançar o valor nas colunas de preço

> **Confirmado pelo Guilherme**: L/M são as colunas internas de "LANÇAMENTO CUSTOS" —
> lançar sempre preço de **custo** ali. Elas alimentam as fórmulas da própria planilha
> que agregam BDI, Risco, Impostos e RT do arquiteto para chegar no preço final. Por
> isso ficam de fora da área de impressão (é exatamente o que a regra de `print_area`
> em duas faixas da Skill 4 já protege). O preço final "fechado" (com os fatores
> percentuais aplicados) **não sai automaticamente da fórmula** — o Guilherme aplica
> esses fatores manualmente depois desta etapa, antes de gerar a proposta. Ver Skill 6
> para esse handoff.

### 5. Citar a fonte no comentário de cada célula
Sempre um dos três: referência ao histórico EP (obra + ano), `[MKT]` com nota de que
é média de pesquisa, ou `[Estimativa]` justificada quando nem histórico nem pesquisa
direta se aplicam (ex.: verba de risco, item muito específico do projeto). Nenhum
item sem essa justificativa.

### 6. Conferir a invariante ao citar uma obra específica
Sempre que um preço ou margem for justificado citando uma obra do `BANCO DE DADOS -
Obras EP`: conferir Lucro = Recebido − Gasto e Margem = Lucro / Recebido naquela
linha. Se não bater, o dado está desatualizado ou errado — não usar sem avisar.

### 7. Checar a sanidade da margem resultante
Comparar a margem que o preço lançado implica com a faixa histórica de rentabilidade
da empresa (`BANCO DE DADOS - Obras EP`, aba "Resumo Executivo"). Se estiver muito
fora da faixa (pra mais ou pra menos), sinalizar antes de fechar — pode ser erro de
leitura da fonte, não necessariamente um preço errado.

## Saída esperada (o que entrega para a Skill 6)

- Planilha com todos os preços lançados, fórmulas de subtotal e totais agora
  fechando com valores reais.
- Todo item com fonte citada no comentário da célula.
- Qualquer margem fora do padrão histórico sinalizada explicitamente.

## Checklist antes de passar para a Skill 6

- [ ] Base de preço (venda x custo) confirmada antes do primeiro item, não decidida
      no meio
- [ ] Todo item consultado no catálogo com unidade conferida e ano mais recente
- [ ] Aba de Benchmark usada é a certa para o perfil da obra
- [ ] BDI aplicado quando a base é venda e a origem é custo puro
- [ ] Toda célula de preço tem comentário com fonte (histórico, `[MKT]` com média, ou
      `[Estimativa]` justificada)
- [ ] Invariante Lucro/Recebido/Gasto conferida em toda obra citada como referência
- [ ] Margem resultante dentro da faixa histórica, ou sinalizada se não estiver
