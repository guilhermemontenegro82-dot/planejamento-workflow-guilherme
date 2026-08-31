---
name: orcamento-ep-montagem-da-planilha
description: "Segunda etapa do pipeline de orçamento EP Engenharia: monta a estrutura da planilha (cabeçalho, grupos, subitens com descrição no padrão EP, observações, quadro de valor/m²) a partir do que a Skill 1 — Estudo do Projeto levantou. Preserva as fórmulas do modelo — nunca digita fórmula de memória, sempre copia do padrão existente. Não preenche quantidade (Skill 3), não formata visualmente (Skill 4), não precifica (Skill 5). Acionada pelo Agente Orquestrador — Orçamentos EP depois que a Skill 1 aprova o entendimento do escopo."
---

# Skill 2 — Montagem da Planilha

## Quando invocar

Logo depois da Skill 1 — Estudo do Projeto entregar o resumo de escopo, o tipo de obra
e os grupos prováveis. Chamada pelo Agente Orquestrador — Orçamentos EP.

## O que esta etapa NÃO faz

- Não preenche a coluna de **quantidade** — só a de unidade. Medir é a Skill 3.
- Não aplica cor, fonte, altura de linha ou `print_area` — isso é a Skill 4. Ao limpar
  o corpo do template para escrever conteúdo novo, limpar `value` e `comment` de cada
  célula, mas **não mexer em `fill`/`border`** — resíduo visual de formatação é
  problema da Skill 4, não desta etapa.
- Não lança preço nas colunas L/M — isso é a Skill 5.

## Inputs esperados

- Saída da Skill 1: tipo de obra, resumo de escopo (incluso/não incluso), grupos
  prováveis, dados do cliente e bairro.
- **Planilha modelo**: a que já está na pasta do projeto (prioridade sempre sobre
  qualquer modelo genérico) ou, na falta dela, o `modelo_padrao.xlsx` desta skill.
  **Nunca criar uma planilha do zero** — usar a que existe, mantendo toda a
  formatação e a estrutura de itens já presente.
- Data do orçamento e número da revisão (ex.: R00, R01) — perguntar se não estiver
  claro.

## Regra central: sempre o modelo que está na pasta agora — nunca cache, nunca memória

Toda vez que a pasta "Orçamento" for compartilhada, o modelo a usar é o arquivo que
está **fisicamente nela naquele momento** — nunca uma cópia de trabalho de uma sessão
anterior, e nunca uma versão reconstruída "de memória" por parecer igual ao modelo
de sempre. Guilherme atualiza esse modelo periodicamente (correção de formatação,
ajuste de fórmula); se esta etapa usar uma versão desatualizada sem perceber, o
orçamento inteiro herda algo que já foi corrigido em outro lugar sem saber.

- Reabrir o arquivo do zero a cada orçamento novo — não reaproveitar uma cópia já
  aberta numa sessão anterior, mesmo que pareça a mesma pasta/obra.
- Se houver mais de um arquivo candidato a "modelo" dentro da pasta "Orçamento" (ex.:
  uma versão antiga ao lado da atual), **parar e perguntar** qual usar — nunca
  escolher por suposição (nome, data, tamanho).
- Só usar o `modelo_padrao.xlsx` genérico desta skill quando a pasta "Orçamento" não
  tiver nenhum modelo próprio — e avisar explicitamente que foi esse o caso.
- **Registrar, na saída desta etapa, qual arquivo exato foi usado como modelo** (nome
  e, se disponível, data de modificação). A Skill 4 usa essa mesma referência — não
  resolve de novo — para garantir que estrutura e estilo vêm da mesma fonte.

## Regra central: preservar fórmula, nunca recriar de memória

Toda célula que no modelo é fórmula (subtotais, o quadro de valor por m²) continua
sendo fórmula na planilha nova — nunca substituir por um valor digitado, e nunca
digitar uma fórmula "de cabeça". Ao criar uma linha nova (um subitem, um SUB TOTAL),
copiar o padrão de fórmula de uma linha equivalente do **modelo original** (nunca de
uma cópia já editada, para não herdar erro) e só ajustar as referências de célula.
Isso vale tanto para o corpo quanto para o rodapé e o quadro de m².

## Passo a passo

### 1. Preparar o arquivo
Copiar o modelo para a área de trabalho — nunca editar o arquivo original da pasta do
projeto diretamente.

### 2. Preencher o cabeçalho
Cliente, endereço, A/C, telefone, nome da obra/serviço, data, revisão.

**Formato da data**: sempre forçar `cell.number_format = 'dd/mm/yyyy'` explicitamente
na célula da data. O modelo às vezes carrega `mm-dd-yy` herdado — se não sobrescrever,
a data aparece errada (`7/29/2026` em vez de `29/07/2026`). Tratar como parte
obrigatória do preenchimento, não como detalhe opcional.

### 3. Limpar o corpo existente do template
Limpar `value` e `comment` de cada célula do corpo antes de escrever o conteúdo novo.
Não tocar em `fill`/`border` (ver "O que esta etapa não faz").

### 4. Definir os grupos de serviço
Com base no resumo de escopo da Skill 1, usando como referência os grupos típicos:
Serviços Preliminares, Demolições e Retiradas, grupos específicos da obra (ex.:
Impermeabilização, Investigação e Reparo de Tubulações), Proteção Mecânica,
Recomposição do Revestimento, Serviços Complementares, e **Despesas Indiretas
(sempre presente)** — acompanhamento técnico, RRT/ART, remoção de entulho, fretes,
mobilização/desmobilização, limpeza permanente da área.

Preencher apenas os subitens pertinentes à obra, excluir o que não for necessário, e
propor novos itens de despesa indireta quando fizer sentido e não estiverem no modelo.

**Obra com múltiplas áreas/blocos independentes** (se o cliente pode contratar cada
área separadamente): montar uma planilha por área, cada uma com seu próprio grupo de
Despesas Indiretas — não copiar os valores do orçamento geral; redimensionar
RRT/ART, seguro, frete, caçamba, mobilização e acompanhamento técnico proporcionalmente
ao porte/duração daquela área específica. Manter o orçamento geral consolidado à
parte, se já existir.

### 5. Escrever os subitens — padrão de linguagem EP
Descrições sempre longas e completas: o que é feito + como é feito + materiais
especificados + o que está incluso. Quando algo **não** está incluso, mencionar
explicitamente. Nomenclatura técnica precisa (ex.: "argamassa colante flexível
AC-III", "manta asfáltica 4mm tipo APP").

Exemplo do padrão esperado:
> Assentamento de pastilha cerâmica no piso interno da piscina com argamassa colante
> flexível AC-III para área molhada (tipo Quartzolit, Weber ou similar), incluso
> cortes, espaçadores e consumíveis. Não incluso o fornecimento das pastilhas.

Preencher a **unidade** de cada subitem (m², ml, vb, unid. etc.) — a quantidade fica
em branco para a Skill 3.

### 6. Escrever as observações
Obs1: o que está incluso (materiais de insumo, consumíveis). Obs2: o que **não** está
incluso (acabamentos, mobiliário, fornecimento de revestimento). Obs3: informação
sobre impostos/NF. Adaptar número e conteúdo ao contexto da obra. Posicionar sempre
**antes** do bloco de totais.

### 7. Montar o rodapé (estrutura, não os valores finais)
Sequência: Obs1/Obs2/Obs3, depois TOTAL DE CUSTO (Mat e Mdo) OBRA CIVIL, depois TOTAL
— sem linha de impostos como cálculo (impostos só na Obs3). As fórmulas de soma dos
subtotais ficam prontas; os valores só fecham depois que quantidade (Skill 3) e preço
(Skill 5) forem preenchidos — isso é esperado nesta etapa.

### 8. Montar o quadro "Estudo de valor por m²"
Manter a estrutura fixa do modelo — não é um bloco opcional:

```
Área total obra   <em branco — Skill 3 preenche>      Mão de obra Planilha     =SOMA(N do corpo)
Valor /m² EP      R$ 3.000/m² (padrão histórico EP,    Mão de obra estimada     <em branco — input do usuário>
                  salvo indicação em contrário)
Valor/m² Alvo     =Área total obra × Valor/m² EP       Diferença                =Mão de obra Planilha − estimada
Valor/m² Plan     =TOTAL_OBRA_CIVIL ÷ Área total obra
```

Deixar a célula de **Área total obra** em branco de propósito — é a Skill 3 quem
preenche, depois de medir. As demais são fórmulas e ficam prontas agora, mesmo
mostrando zero/erro até a Área total obra ser preenchida.

### 9. Remover linhas em branco
Deletar linhas vazias remanescentes no corpo, de baixo para cima (para não deslocar
índices).

### 10. Nomear e salvar
Padrão: `[Número da obra] - [Código da obra] - Planilha - [Resumo do serviço] -
[Bairro].xlsx`. Número e código vêm do nome da pasta compartilhada (a Skill 1 já
deve ter confirmado isso); se a pasta não seguir o padrão, perguntar antes de nomear.
Não incluir prefixo "Orçamento_", nome do cliente, nem sufixo de revisão no nome do
arquivo — a revisão já fica controlada na célula do cabeçalho.

## Saída esperada (o que entrega para a Skill 3)

- Planilha com cabeçalho, grupos, subitens (descrição + unidade, sem quantidade),
  observações e rodapé estruturados — fórmulas prontas, valores ainda abertos.
- Quadro de valor por m² montado, com a célula de Área total obra em branco.
- Lista do que ficou pendente de medição, por subitem, para a Skill 3 seguir direto.
- **Identificação do arquivo-modelo usado** (nome e data de modificação, se
  disponível) — para a Skill 4 reusar a mesma fonte.

## Checklist antes de passar para a Skill 3

- [ ] Modelo usado é o arquivo que está na pasta "Orçamento" agora — não uma cópia de
      sessão anterior nem uma versão reconstruída de memória
- [ ] Cabeçalho completo, com data em `dd/mm/yyyy` explícito
- [ ] Nenhuma fórmula do modelo foi substituída por valor digitado
- [ ] Grupos correspondem ao escopo da Skill 1, com Despesas Indiretas presente
- [ ] Descrições completas no padrão EP, com unidade preenchida e quantidade em branco
- [ ] Observações antes do bloco de totais, sem linha de imposto como cálculo
- [ ] Quadro de valor por m² presente, com Área total obra em branco de propósito
- [ ] Nenhuma linha em branco no corpo
- [ ] Arquivo nomeado conforme o padrão e salvo na pasta do projeto
