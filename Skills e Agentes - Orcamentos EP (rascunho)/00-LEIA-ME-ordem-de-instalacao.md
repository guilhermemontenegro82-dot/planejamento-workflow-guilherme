# Leia-me — Ordem de instalação no Cowork

Pipeline de orçamento EP Engenharia, desmembrado de 3 skills monolíticas em 6 skills
de execução + 2 agentes-chequer + 1 agente orquestrador + 1 skill de referência
atualizada. Construído e revisado nesta pasta antes de qualquer coisa ir pro Cowork —
ver a seção "Depois de instalar tudo" antes de considerar isso substituindo o que já
está em produção.

## Mapa geral da pasta

**Dado de referência (atualiza uma skill que já existe)**
- `base-de-dados-financeiros-ep (texto final para colar no Cowork).md` — texto
  completo e final, pronto pra colar no lugar da skill atual. Já inclui o modo
  estimativa rápida e o apêndice legado absorvidos da `referencia-orcamento`. É o
  único arquivo desta categoria na pasta — a nota de trabalho intermediária que
  explicava as duas seções novas foi removida por já estar toda incorporada aqui.

**Skills de execução (o pipeline em si, nesta ordem de uso)**
- `skill-1-estudo-do-projeto.md`
- `skill-2-montagem-da-planilha.md`
- `skill-3-quantitativo.md`
- `skill-4-formatacao-da-planilha.md`
- `skill-5-precificacao.md`
- `skill-6-proposta-comercial.md`

**Verificação (rodam entre as skills acima, nunca no lugar delas)**
- `agente-chequer-tecnico.md` — só aprova o que consegue verificar rodando
  código/ferramenta sobre o arquivo real. A rubrica de cada etapa (montagem,
  formatação, precificação, proposta) já está embutida dentro dele, seção por
  seção — não é um arquivo separado.
- `agente-chequer-conteudo.md` — só aprova o que consegue verificar citando o trecho
  exato usado como evidência. Mesma lógica: rubrica de cada etapa (quantitativo,
  montagem, precificação, proposta) embutida dentro do próprio agente.

**Orquestração (por último, referencia tudo acima pelo nome)**
- `agente-orquestrador-orcamentos-ep.md` — chama as 6 skills em sequência, intercala
  os chequers certos em cada etapa, e tem um gate humano embutido antes da Skill 6
  (confirmar que você já aplicou os fatores finais de preço na planilha).

## Ordem de instalação sugerida

1. Colar `base-de-dados-financeiros-ep (texto final para colar no Cowork).md` no
   lugar da skill atual — independente do resto, seguro fazer isso já.
2. Criar as 6 skills de execução, uma de cada vez, via `/skill-creator`.
3. Criar os 2 agentes-chequer — o texto de cada um já vem completo, com as rubricas
   de todas as etapas embutidas por dentro. Não precisa anexar nada separado.
4. Criar o Agente Orquestrador por último — ele só faz sentido com as 6 skills e os
   2 chequers já existindo.

**Nota sobre a mudança de desenho**: as rubricas começaram como arquivos de
referência separados, mas isso dependia de um agente "disparar" a leitura desse
arquivo sozinho no meio da própria execução — um tipo de gatilho que eu não tinha
como confirmar se o Cowork suporta de forma confiável. Embutir a rubrica dentro de
cada agente-chequer elimina essa dúvida por completo: o agente já nasce sabendo o
que verificar, sem depender de nada externo disparar certo.

## Antes de instalar — o que NÃO fazer ainda

- **Não apague `referencia-orcamento` do Cowork.** Ela já foi absorvida no conteúdo,
  mas a skill `orcamento-obra` (a atual, ainda em produção) chama ela pelo nome. As
  duas só saem juntas, quando `orcamento-obra` for editada ou substituída pelo
  pipeline novo — decisão sua, ainda pendente.
- **Não edite `orcamento-obra`** — combinamos deixar isso para depois do ciclo novo
  estar pronto e testado.

## Depois de instalar tudo — o teste real

Antes de considerar isso pronto para substituir o `orcamento-obra` atual: rode um
orçamento completo de uma obra pequena que você já orçou de verdade e sabe o
resultado de cor. Compare o que o pipeline novo produz, etapa por etapa, com o que
você entregou na época. Essa é a única forma de pegar o tipo de bug que uma revisão
de texto não alcança — sintaxe real, referência de célula real, comportamento real do
Cowork.

## Se algo der errado

Volta pra mim (nesta mesma pasta/projeto) com: qual skill/etapa estava rodando, o que
você esperava, o que aconteceu de fato. Eu corrijo o arquivo aqui, você cola a versão
corrigida de volta — mesmo fluxo que usamos pra construir tudo isso.
