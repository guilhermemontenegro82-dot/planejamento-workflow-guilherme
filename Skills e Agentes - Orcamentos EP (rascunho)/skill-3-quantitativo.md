---
name: orcamento-ep-quantitativo
description: "Terceira etapa do pipeline de orçamento EP Engenharia: extrai quantitativos (áreas, medidas, pesos) das plantas técnicas em PDF/DWG, preenchendo a coluna de quantidade e a célula de Área total obra na planilha já montada pela Skill 2. Etapa mais sensível a erro do pipeline inteiro — critério e precisão em primeiro lugar, toda estimativa citada como tal, nunca apresentada como medida exata. Acionada pelo Agente Orquestrador — Orçamentos EP depois que Montagem é aprovada pelos dois chequers."
---

# Skill 3 — Quantitativo

## Quando invocar

Depois que a Skill 2 — Montagem da Planilha for aprovada pelo Chequer Técnico e pelo
Chequer de Conteúdo. Esta é a etapa que você mais relatou como fonte de erro — o
padrão aqui é desconfiar do próprio resultado antes de escrever, não só depois.

## O que esta etapa NÃO faz

Não decide estrutura, grupo ou descrição de subitem — isso já foi feito pela Skill 2;
aqui só se preenche o número. Não formata visualmente (Skill 4). Não precifica
(Skill 5). Não reinventa o inventário de documentos — isso a Skill 1 já entregou;
aqui é onde de fato se abre e se lê cada um.

## Inputs esperados

- Saída da Skill 1: inventário de documentos técnicos por disciplina.
- Saída da Skill 2: planilha com todos os subitens já descritos e com unidade
  preenchida, quantidade em branco, e a célula de Área total obra também em branco.
- Os PDFs/DWG das plantas em si, na pasta do projeto.

## Passo a passo

### 1. Abrir de fato os documentos do inventário da Skill 1
Ler **todos** os PDFs de cada área — não só a planta baixa, mas também o **Quadro de
Materiais**, o **Quadro de Esquadrias**, a **Planta de Teto Refletido** (com o
**Quadro de Forro**, quando houver) e a **Planta de Pontos** (elétrica/hidráulica).
São essas legendas que geram a maior parte dos itens granulares — pular alguma é a
forma mais comum de entregar um quantitativo raso.

### 2. Confirmar a identidade de cada documento antes de usar
A Skill 1 já pode ter sinalizado pasta/prancha com nome trocado — aqui é onde isso se
confirma de verdade, pelo carimbo e pela legenda internos do próprio desenho. O
conteúdo do desenho manda, nunca o nome do arquivo/pasta.

### 3. Cruzar Levantamento (as-built) × Anteprojeto
Sempre que os dois existirem: o as-built revela áreas reais mais precisas que uma
estimativa a olho, e também demolições implícitas (ex.: duas salas existentes virando
um ambiente novo). Usar o mais preciso, e sinalizar a diferença encontrada.

### 4. Extrair o quantitativo de cada subitem
Ir item por item na lista que a Skill 2 deixou pendente, localizando a fonte certa:

- **Piso/parede**: código do Quadro de Materiais.
- **Esquadria**: código do Quadro de Esquadrias, m² = L × H × quantidade.
- **Forro**: tipo do Quadro de Forro.
- **Pontos elétricos/hidráulicos**: contagem por símbolo na Planta de Pontos.
- **Estrutura metálica**: peso oficial da Lista de Material da prancha, quando
  existir (nem toda prancha tem — projetos em estudo preliminar geralmente não
  trazem); se não existir, estimar por taxa kg/m² de mercado e marcar
  `[ESTIMATIVA]` explicitamente. **Sempre em kg, nunca em ml/m².**
- **Revestimentos**: uma linha por tipo de acabamento — não agrupar tudo genérico.
- **Esquadrias com mais de um tipo de material no mesmo ambiente**: separar por tipo
  (ex.: alumínio + vidro temperado, veneziana, porta pintura branca).

### 5. Montar a memória de cálculo antes de preencher
Para cada quantitativo: item, fonte, cálculo, resultado. Apresentar isso junto com a
entrega da etapa — mesmo que o Chequer de Conteúdo seja quem valida formalmente
depois, a memória de cálculo visível é o que permite auditar de onde veio cada número.

### 6. Marcar toda medida incerta como estimativa
Contagem de símbolo, hachura sem cota, projeto em estudo preliminar — nunca
apresentar como se fosse número exato do projeto. Isso vale tanto no valor quanto no
comentário da célula.

### 7. Citar a fonte em cada nota de célula
Número da prancha, item do quadro de materiais/esquadrias, ou pesquisa de mercado
quando não houver nenhum precedente no projeto — sempre explícito, nunca um número
solto sem rastro.

> Nota: o texto original de referência desta etapa usava a tag `[MKT]` (normalmente
> reservada à Skill 5 — Precificação) também para citar fonte de quantitativo sem
> precedente. Mantive por enquanto para não mudar convenção sem confirmar com você —
> mas vale considerar uma tag própria (ex.: `[PESQUISA]`) para não confundir "fonte de
> quantitativo" com "fonte de preço" nas duas etapas.

### 8. Preencher a Área total obra
Somar as áreas efetivamente usadas nos quantitativos (não um valor genérico copiado
de outro orçamento) e escrever na célula que a Skill 2 deixou em branco no quadro de
"Estudo de valor por m²".

### 9. Obra com múltiplas áreas independentes
Se a Skill 2 já sinalizou isso: medir e preencher cada área separadamente, sem
misturar quantitativos entre elas.

## Saída esperada (o que entrega para a Skill 4)

- Planilha com todas as quantidades preenchidas e a Área total obra fechada.
- Memória de cálculo completa, item a item, com fonte citada.
- Toda estimativa sinalizada como tal, explicitamente, em valor e comentário.

## Checklist antes de passar para a Skill 4

- [ ] Todas as legendas relevantes foram lidas (Materiais, Esquadrias, Forro,
      Pontos) — não só a planta baixa
- [ ] As-built × anteprojeto cruzados quando ambos existiam
- [ ] Nenhuma medida incerta apresentada como exata
- [ ] Estrutura metálica em kg, com fonte identificada (Lista de Material ou taxa
      estimada, nunca confundidas)
- [ ] Revestimentos e esquadrias separados por tipo, com código do quadro citado
- [ ] Área total obra preenchida com a soma real das áreas usadas
- [ ] Memória de cálculo apresentada, não só os números finais
