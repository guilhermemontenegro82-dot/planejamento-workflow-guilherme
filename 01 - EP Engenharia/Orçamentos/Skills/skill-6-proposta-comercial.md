---
name: orcamento-ep-proposta-comercial
description: "Sexta e última etapa do pipeline de orçamento EP Engenharia: gera a proposta comercial em .docx a partir da planilha de orçamento já precificada, revisada e aprovada pelo Guilherme. Substitui a tabela de itens do anexo, atualiza todos os textos específicos do cliente (nunca herdando dado de um projeto anterior), e avisa explicitamente quando não conseguir confirmar o número de páginas final. Acionada pelo Agente Orquestrador — Orçamentos EP depois que Precificação é aprovada pelos dois chequers E o Guilherme dá o sinal verde explícito ('pode gerar a proposta') — nunca antes disso, mesmo que o silêncio pareça aprovação."
---

# Skill 6 — Proposta Comercial

## Quando invocar

Depois que a Skill 5 — Precificação for aprovada pelo Chequer Técnico e pelo Chequer
de Conteúdo, **e** o Guilherme der o sinal verde explícito. Em 100% dos orçamentos
ele revisa e ajusta algo na planilha antes da proposta sair — não só os fatores
finais de preço (impostos, percentuais), mas potencialmente qualquer número. Não
existe forma automática de detectar "ele terminou de revisar": o gatilho é a
confirmação explícita dele na conversa, frase padrão **"pode gerar a proposta"** (ou
equivalente inequívoco). Uma mensagem ambígua não conta como sinal — nunca presumir
aprovação por falta de resposta ou por um comentário genérico sobre a obra.

## O que esta etapa NÃO faz

Não decide preço (Skill 5). Não decide forma de pagamento ou prazo sozinha — sempre
pergunta quando não estiver 100% claro. Não estima número de páginas de cabeça quando
não conseguir confirmar de verdade.

## Inputs esperados

- Planilha de orçamento **revisada e aprovada pelo Guilherme** — itens, unidades,
  quantidades e o total geral final (não o de custo), já com qualquer ajuste que ele
  tenha feito (fatores finais de preço, ou os próprios números do orçamento).
- Modelo de proposta (.docx) — normalmente já existe um na pasta do projeto,
  reaproveitado de um cliente anterior.
- Dados do cliente: nome(s) e endereço completo da obra.
- Número da proposta — pedir um código se não houver um óbvio a partir do
  nome/código do projeto (já levantado na Skill 1).
- Forma de pagamento (sinal %, condição do saldo/medições) — perguntar se não
  estiver claro.
- Prazo de execução (dias corridos + meses, ou dias úteis para serviços avulsos
  pequenos) — perguntar se não houver estimativa.
- Percentual de impostos — normalmente já definido junto com o ajuste final da
  planilha.

**Se o modelo trouxer esses campos preenchidos com dados de um cliente anterior**,
tratar como placeholders a substituir — nunca herdar valor de outro projeto.

## Passo a passo

### 1. Ler a planilha
Extrair de cada linha do corpo: número do item, descrição, unidade, quantidade. As
colunas de preço unitário (L/M, internas de custo) **não** entram na proposta — só o
total geral final, já com os fatores do Guilherme aplicados.

### 2. Preparar o modelo
Usar a skill `docx` (unpack → editar XML → repack). Fazer duas cópias do modelo
original antes de editar: uma cópia de trabalho, onde as edições acontecem, e uma
cópia "limpa" extra, guardada só como referência caso a tabela precise ser
reconstruída do zero (evita herdar uma edição quebrada).

### 3. Substituir a tabela do anexo
A tabela de itens é uma tabela Word (`<w:tbl>`), com uma linha de título por grupo e
uma linha por item.

- Extrair o "molde" de uma linha de título e uma linha de item a partir da tabela
  **original** (nunca de uma cópia já editada, para não herdar erro).
- Gerar uma linha nova para cada grupo/item, trocando apenas o texto dentro de cada
  `<w:t>...</w:t>`.

**Armadilha de regex conhecida**: `<w:t[^>]*>` também casa com `<w:tc>` (a tag da
CÉLULA da tabela), porque as duas começam com `<w:t` — isso destrói a estrutura da
tabela silenciosamente e só aparece na validação final. Usar sempre
`<w:t(?:\s[^>]*)?>` (exige espaço ou fechamento depois do "t", nunca outra letra). Ver
`references/docx-table-editing.md` para o passo a passo com código de exemplo.

Depois de montar as linhas: contar `<w:tc>` e `</w:tc>` no bloco novo — os dois
números têm que bater.

**Coluna de quantidade**: não usar padding manual com espaços para simular
alinhamento à direita. Em células estreitas, isso força quebra de linha no meio do
número (ex.: "1,0" numa linha e "0" na linha de baixo). Usar apenas o valor formatado
("1,00", "18,00") e deixar o alinhamento a cargo do `jc` da célula.

### 4. Atualizar os textos
Localizar o texto atual do modelo antigo e trocar: data da capa e número da proposta;
nome do cliente (saudação e endereçamento); endereço da obra; preço total dos
serviços + valor por extenso; percentual de impostos; forma de pagamento; prazo de
execução; data de assinatura (bater com a data da capa); nome do cliente na segunda
via de assinatura ("DE ACORDO").

**Detalhe fácil de esquecer — bloco "DE ACORDO"**: depois do título "DE ACORDO" e da
linha de assinatura, existe um parágrafo separado logo abaixo com o nome de quem
assina, em itálico/negrito e centralizado sob a linha. Esse nome vem preenchido com
valor de um cliente/projeto **anterior**, e é fácil não perceber que precisa trocar
— não está na mesma linha do texto "DE ACORDO", não tem keyword óbvia como
"cliente"/"nome" por perto, é só um nome próprio solto e plausível. Localizar esse
parágrafo (geralmente o primeiro texto em itálico+negrito depois da linha de
assinatura) e trocar pelo nome do cliente atual, mantendo a formatação.

Qualquer valor não 100% claro (forma de pagamento, prazo, numeração) → perguntar
antes de escrever.

### 5. Validar o conteúdo
Rodar o `pack.py` da skill `docx` (valida a estrutura do XML). Para conferir o
**conteúdo** rapidamente: `pandoc arquivo.docx -o saida.md` e ler o texto extraído —
mais rápido que gerar PDF, e permite conferir se os itens da planilha entraram certos
e se os valores batem.

Ao gerar parágrafos novos com `w14:paraId` aleatório: garantir que o valor hexadecimal
fique abaixo de `0x80000000` (gerar com `random.randint(0, 0x7FFFFFFF)`), senão a
validação de XML rejeita.

### 6. Conferir o número de páginas — não pular esta etapa
A proposta termina com "Encerramos a presente proposta em X (extenso) folhas". Esse
número só é confiável olhando o arquivo renderizado de verdade — a conversão
automática para PDF pode ser lenta ou travar em documentos com tabelas grandes.

- Se for possível gerar o PDF em tempo razoável: gerar e conferir a contagem antes de
  entregar, ajustando a frase se necessário.
- Se travar ou demorar demais: **não insistir** — avisar claramente, na entrega, que
  o usuário precisa abrir no Word, olhar o número de páginas (canto inferior
  esquerdo) e corrigir a frase antes de enviar ao cliente. Nunca entregar sem esse
  aviso.

### 7. Entregar
Copiar o arquivo final para a pasta do projeto (mesmo nome do modelo, ou "R01"/"R02"
se for revisão), verificando antes se não existe um arquivo de trava do Word aberto
(`~$...docx`) na pasta — se existir, avisar o usuário antes de sobrescrever. Se a
pasta de destino não permitir sobrescrever (ex.: pasta sincronizada que bloqueia
substituição), salvar como próxima revisão em vez de forçar.

## Saída esperada (entrega final do pipeline)

- Proposta comercial em .docx pronta, com tabela de anexo batendo com a planilha,
  todos os textos atualizados para o cliente atual.
- Aviso explícito se o número de páginas não pôde ser confirmado automaticamente.
- Vai para a revisão final do Guilherme (ver Agente Orquestrador) antes do envio ao
  cliente.

## Checklist antes de entregar

- [ ] Tabela do anexo bate com a planilha atual (mesmos itens, unidades, quantidades)
- [ ] Preço total e valor por extenso corretos
- [ ] Cliente, endereço e escopo corretos — nada sobrou do projeto anterior usado
      como modelo
- [ ] Nome do cliente conferido também no bloco de assinatura "DE ACORDO"
- [ ] Forma de pagamento e prazo conferidos com o usuário, não herdados do modelo
- [ ] Conteúdo conferido via extração de texto (pandoc), não só visualmente
- [ ] Usuário avisado para conferir o número de páginas final, se não confirmado
      automaticamente
- [ ] Arquivo salvo na pasta correta do projeto, sem sobrescrever um arquivo em uso

## Arquivo de referência

`references/docx-table-editing.md` — detalhe técnico da reconstrução da tabela do
anexo (o bug de regex, código de exemplo, checagem de sanidade).
