# CLAUDE.md

Contexto para o Claude Code (e qualquer sessão futura) neste repositório. Este arquivo é
a "verdade compartilhada" versionada no Git — complementa, mas não substitui, a memória
automática entre sessões.

## Sobre o Guilherme

Arquiteto (2010), 43 anos. Sócio-diretor da GAM Soluções em Engenharia (12 anos de
empresa, obras civis, reforços estruturais e gerenciamento) e da EP Engenharia
(2 sócios + 2 técnicos + 15 operacionais). Papel: diretor financeiro e comercial —
controle financeiro, orçamentos, propostas, notas fiscais, documentação e marketing.

**EP Engenharia — modelo de negócio**: ~R$ 3.000/m², obras de 80–300m², margem
20–35%. Portfolio: 70% reforma de apartamento, 10% casas, 10% reforços estruturais,
10% diversos. Clientes: 40% arquitetos, 30% clientes antigos, 20% fornecedores
parceiros, 10% amigos. Ferramentas do dia a dia: Excel, Word, AutoCAD, PowerPoint,
PDF reader, Windows 10.

**Maior gargalo**: atualização de planilhas de controle financeiro + organização de
documentos. As planilhas são 100% padronizadas (mesma estrutura, fórmulas, cores,
formatação) entre obras, com pequenas variações de regra conforme é obra EP ou
gerenciamento GAM.

**Fluxo de trabalho atual da empresa** (o que as skills deste repositório visam
automatizar, etapa por etapa): (1) planilha por obra, atualizada semanalmente →
(2) leitura de notas fiscais no WhatsApp → (3) lançamento manual na aba
"Lançamento" + pintura de linha por técnico → (4) arquivamento de PDFs →
(5) conteúdo para Instagram → (6) relatório fotográfico para clientes →
(7) relatórios técnicos → (8) planilhas de orçamento → (9) propostas comerciais.
Tentativas anteriores de automatizar com skills prontas tiveram erros (notas
ignoradas, duplicadas, regras puladas) — é essa dor que motiva o desmembramento em
skills menores e verificadas descrito abaixo.

## Como colaborar com o Guilherme

- **Iniciante em IA** — explicar simples, sem jargão técnico desnecessário.
- Objetivo é eliminar trabalho braçal/mecânico, não adicionar complexidade.
- Comunicação natural, concisa, direta — clareza acima de gramática perfeita.
- Qualidade > economia: priorizar o resultado certo, não o caminho mais barato.
- **Sinceridade e pushback técnico de verdade**, não concordância por padrão. Quando
  ele pergunta "o que acha" ou propõe uma arquitetura, ele quer uma opinião pesada
  com trade-offs — e já melhorou várias vezes minhas propostas iniciais quando eu dei
  esse tipo de resposta (ex.: consolidar rubricas em 2 agentes chequer em vez de 5,
  depois embutir as rubricas dentro dos próprios agentes em vez de skills separadas).
  Quando ele muda o design, adotar e explicar o porquê, não só executar.
- **Nunca mudar regra de negócio/domínio em silêncio** (preços, fórmulas, códigos de
  formatação, letras de coluna) que vieram das skills originais dele. Se algo parecer
  inconsistente, sinalizar explicitamente no arquivo e perguntar — nunca supor ou
  "corrigir" por conta própria.
- Ao final de uma tarefa: resumo do que foi feito + perguntas/decisões pendentes.
  Recomendar a skill certa quando fizer sentido. Se uma proposta melhorar o
  resultado, apresentar durante a execução, não só depois.
- Respostas curtas por padrão, a não ser que ele peça mais detalhe.
- Clientes da EP/GAM têm nível intelectual alto — textos técnicos e objetivos, sem
  jargão específico de construção civil quando o output for para eles (propostas,
  relatórios).

## Fluxo de trabalho: staging local → Cowork

Não existe conector direto para o Claude Cowork neste ambiente. O padrão é sempre:
1. Construir/revisar tudo localmente aqui (Claude Code), numa pasta de rascunho
   dedicada por pipeline.
2. Guilherme revisa e só então copia e cola manualmente no Cowork.
3. Se algo quebrar depois de instalado no Cowork, o erro volta para *este mesmo*
   projeto Claude Code para ser corrigido — nunca é remendado direto no Cowork. Os
   arquivos locais são sempre a fonte da verdade.
4. Cada skill/agente gerado mantém um "Log de mudanças" / changelog no próprio
   arquivo.

## Estrutura do repositório

- `Mapa mental/` — mapas mentais (imagens + pptx) do ecossistema de trabalho
  completo: Agente Central → linhas EP Engenharia, DG Revy, GAM Soluções, Pessoal.
- `Skills e Agentes - Orcamentos EP (rascunho)/` — pipeline de orçamentos da EP
  Engenharia, desmembrado de 3 skills monolíticas do Cowork
  (`orcamento-obra`, `proposta-comercial-obra`, `referencia-orcamento`) em 6 skills
  de execução + 2 agentes chequer (Técnico e Conteúdo) + 1 agente orquestrador.
  Ver `00-LEIA-ME-ordem-de-instalacao.md` nessa pasta para a ordem de instalação e
  detalhes de cada etapa.
- `Skills e Agentes - Lancamento Notas EP (rascunho)/` — pipeline de lançamento de
  notas fiscais da EP Engenharia (revisão do `supervisor-lancamento-ep` que já
  existia no Cowork): skills de leitura/lançamento/pintura de notas + skill irmã de
  busca de NF-e no Mercado Livre, com 2 agentes chequer (Leitura confere cobertura,
  Classificação confere se os campos batem com a mensagem original). Ver o
  `00-LEIA-ME-ordem-de-instalacao.md` dessa pasta.
- `Guia de motores Claude.docx`, `Sequência de execução - próximos trabalhos.docx` —
  planejamento de alto nível.

## Projeto: Pipeline de Orçamentos EP

**Por quê**: as skills originais eram monolíticas (tudo em uma passada, sem
verificação independente) e havia duas skills de referência de preço concorrentes
(`referencia-orcamento` vs `base-de-dados-financeiros-ep`) com gatilhos quase
idênticos e sem sincronia — risco real de respostas conflitantes, não redundância
inofensiva.

**Ordem do pipeline** (decidida pelo Guilherme: montar estrutura antes de medir, não
o contrário): 1) Estudo do projeto (sem chequer dedicado) → 2) Montagem da planilha
(Chequer Técnico + Conteúdo) → 3) Quantitativo (Chequer de Conteúdo — etapa
historicamente com mais erros) → 4) Formatação (Chequer Técnico — outra etapa com
erros frequentes) → 5) Precificação, via `base-de-dados-financeiros-ep` (Chequer
Técnico + Conteúdo) → **gate humano explícito**: só avança com a frase literal "pode
gerar a proposta" (silêncio nunca é aprovação) → 6) Proposta comercial (Chequer
Técnico + Conteúdo) → revisão final do Guilherme → saída.

**Princípio de design**: Chequer Técnico só conclui PASS rodando código/ferramenta
contra o arquivo real (nunca "parece certo" visual); Chequer de Conteúdo só conclui
PASS citando o trecho exato da fonte como evidência.

**Status em 2026-08-04**: Skills 1 e 2 já instaladas no Cowork. Skills 3–6, os dois
chequers e o orquestrador revisados localmente, instalação em andamento.
`referencia-orcamento` já foi desinstalada do Cowork (à frente do plano) — a skill
`orcamento-obra`, ainda em produção, quebra se usada antes do pipeline novo
substituí-la; Guilherme optou por não editá-la até o novo ciclo ser testado.

**Próximos passos**: (1) terminar de instalar o que falta no Cowork, (2) rodar um
orçamento real ponta a ponta contra uma obra pequena já precificada, comparando
etapa por etapa com o que foi entregue de fato, (3) corrigir o que o teste real
encontrar de volta aqui, (4) só então aposentar `orcamento-obra` +
`referencia-orcamento` juntos, nunca um antes do outro.

**Mapa mental do ecossistema**:
https://claude.ai/code/artifact/92fa999b-b579-4627-ad11-18f6ea74317a

## Projeto: Pipeline de Lançamento de Notas EP

Revisão (piloto, 2026-08-04) do `supervisor-lancamento-ep` que já existia no Cowork,
seguindo o mesmo padrão do pipeline de Orçamentos: skills pequenas e verificadas em
vez de uma skill monolítica. Pipeline: Leitor de notas (Etapa 1, WhatsApp ou pasta)
→ Chequer de Leitura (cobertura) + Chequer de Classificação (campos batem com a
mensagem original, roda cego antes de comparar) em paralelo → checkpoint com
Guilherme → Lançador (Etapa 2, escreve na aba LANÇAMENTO) → Pintor (Etapa 3, pinta
linhas, confere, devolve a planilha) — tudo uma obra por vez. Skill irmã
`skill-notas-fiscais-ml.md` busca NF-e de itens "Pendente" do Mercado Livre depois
do lançamento. Ver `00-LEIA-ME-ordem-de-instalacao.md` da pasta para o mapa completo
e o changelog de revisão.
