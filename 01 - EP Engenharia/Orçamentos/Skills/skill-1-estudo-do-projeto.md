---
name: orcamento-ep-estudo-do-projeto
description: "Primeira etapa do pipeline de orçamento EP Engenharia: ler o memorial descritivo, fotos e a conversa de escopo com o cliente, para formar um entendimento geral da obra antes de montar a planilha. Não mede quantidades (isso é a Skill 3 — Quantitativo) e não abre plantas técnicas para extração de área. Use como primeiro passo sempre que for iniciar um orçamento novo da EP Engenharia, acionada pelo Agente Orquestrador — Orçamentos EP."
---

# Skill 1 — Estudo do Projeto

## Quando invocar

Primeiro passo de todo orçamento novo, antes de qualquer linha ser escrita na
planilha. Chamada pelo Agente Orquestrador — Orçamentos EP logo depois da pasta do
projeto ser compartilhada.

## O que esta etapa NÃO faz

Não abre plantas em PDF/DWG para medir área — isso é a Skill 3 (Quantitativo), mais
adiante no pipeline, e é de propósito: só vale medir o que já sabemos que vai entrar
no orçamento, depois que o escopo estiver definido aqui. Não monta a planilha, não
escreve descrição de subitem, não precifica.

## Inputs esperados

Da pasta do projeto compartilhada:

1. **Memorial descritivo** (se existir) — texto do projeto/arquiteto descrevendo o
   que será feito.
2. **Fotos** do local/obra — estado atual, o que motivou a reforma.
3. **Conversa de escopo** com o usuário — o que ele já explicou no chat sobre o que o
   cliente quer, mesmo sem estar em nenhum documento.
4. **Nome da pasta do projeto** — geralmente traz número e código da obra
   (`<número> - <código> - <descrição> - <bairro>`); se não seguir esse padrão,
   perguntar o número/código antes de seguir (a nomenclatura de arquivo, mais adiante
   no pipeline, depende disso).
5. **Dados do cliente** — nome, endereço completo da obra, telefone e referência
   (A/C), se ainda não tiverem sido passados na conversa. Perguntar diretamente se
   não constarem em nenhum documento — a Skill 2 precisa disso pronto para o
   cabeçalho, e não tem de onde mais buscar.

Não é necessário, nesta etapa, que o usuário já tenha a planilha modelo em mãos —
isso é input da Skill 2.

## Passo a passo

### 1. Ler o memorial descritivo e as fotos

Formar uma ideia geral do que é a obra: tipo de imóvel, estado de conservação, motivo
da reforma, ambientes envolvidos. Anotar qualquer coisa que o memorial deixe implícita
mas não explícita (ex.: fotos mostrando infiltração que o texto não menciona) —
sinalizar como observação, não como fato.

### 2. Identificar o tipo de obra

Classificar num nível alto: reforma completa de apartamento, reforma parcial (só
banheiro/varanda/forro), cobertura, telhado, pintura avulsa, impermeabilização,
estrutural etc. Essa classificação alimenta diretamente a Skill 5 (qual aba de
Benchmark usar em `base-de-dados-financeiros-ep`) — vale acertar aqui, não deixar
para depois.

### 3. Inventariar a pasta do projeto (sem medir nada ainda)

Listar quais documentos técnicos existem — plantas, quadro de materiais, quadro de
esquadrias, planta de teto refletido/quadro de forro, planta de pontos, projetos
estrutural/elétrico/hidráulico — organizados por disciplina. Não abrir para extrair
quantidade: só confirmar o que existe, para a Skill 3 saber por onde começar.

**Atenção**: pastas ou arquivos com nome trocado acontecem (ex.: uma pasta chamada
"Terraplenagem" cujo conteúdo real é Teto Refletido). Se notar isso nesta etapa,
sinalizar explicitamente na saída — não corrigir silenciosamente, e não deixar para a
Skill 3 descobrir sem aviso.

### 4. Montar o resumo de escopo

Um texto curto e objetivo cobrindo: tipo de obra, ambientes/áreas envolvidos, o que o
cliente pediu, e — igualmente importante — **o que explicitamente NÃO está incluso**,
quando isso já estiver claro (acabamentos por conta do cliente, mobiliário etc.). Esse
resumo é o que a Skill 2 vai usar para decidir quais grupos de serviço criar.

### 5. Levantar dúvidas antes de seguir

Qualquer ambiguidade de escopo — o que não dá para resolver só com o memorial e as
fotos — vira uma pergunta para o usuário aqui, não uma suposição carregada adiante.
Como esta etapa não tem chequer dedicado depois dela, o cuidado tem que estar aqui:
preferir perguntar a mais do que deixar uma dúvida passar para a Skill 2.

## Saída esperada (o que entrega para a Skill 2)

- Tipo de obra identificado
- Número/código da obra e bairro
- Dados do cliente (nome, endereço da obra, telefone, A/C)
- Resumo de escopo (o que está incluso, o que não está)
- Lista preliminar de grupos/disciplinas prováveis (ponto de partida para a Skill 2,
  não uma lista fechada)
- Inventário de documentos técnicos disponíveis, por disciplina (para a Skill 3)
- Qualquer inconsistência encontrada (pasta/arquivo com nome trocado, informação
  contraditória entre memorial e fotos) sinalizada explicitamente

## Checklist antes de passar para a Skill 2

- [ ] Memorial e fotos revisados (ou confirmado que não existe memorial, e o escopo
      veio só da conversa)
- [ ] Tipo de obra classificado
- [ ] Número/código da obra e bairro confirmados
- [ ] Dados do cliente (nome, endereço, telefone, A/C) confirmados
- [ ] Resumo de escopo escrito, incluindo o que não está incluso quando souber
- [ ] Documentos técnicos inventariados por disciplina, sem medir nada ainda
- [ ] Nenhuma dúvida de escopo em aberto sem ter sido perguntada ao usuário
