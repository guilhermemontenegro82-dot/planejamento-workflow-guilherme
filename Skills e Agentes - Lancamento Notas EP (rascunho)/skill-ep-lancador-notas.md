---
name: "ep-lancador-notas"
description: "Etapa 2 do pipeline supervisor-lancamento-ep: recebe a lista de itens já extraída pelo ep-leitor-notas e confirmada pelo usuário, e escreve cada item na aba LANÇAMENTO da planilha de controle financeiro da obra. Não decide quem gastou nem identifica obra — isso já vem pronto. Não pinta linha. Só deve ser chamada pelo supervisor-lancamento-ep."
---

## Papel nesta pipeline

Etapa 2 do fluxo `supervisor-lancamento-ep`. Recebe a lista de itens já extraída pelo
`ep-leitor-notas` **e já confirmada pelo usuário** (dúvidas resolvidas) e escreve cada item na
planilha. Não decide "quem gastou" nem identifica obra — isso já veio pronto da Etapa 1. Não
pinta linha (isso é `ep-pintor-notas`).

## Regra de ouro — de onde vêm os dados

**Só escreva a partir de uma lista gerada pelo `ep-leitor-notas` nesta mesma execução do
Supervisor.** Se por qualquer motivo você receber uma lista de lançamentos vinda de uma
conversa antiga, resumida/compactada, ou de qualquer fonte que não seja a Etapa 1 rodando
agora — **pare**: peça ao Supervisor para rodar o `ep-leitor-notas` de novo antes de escrever
qualquer linha. Já aconteceu de um valor sem nota correspondente nenhuma ir parar na planilha
(R$66,70 na MC-Ipanema) por causa de uma lista pré-pronta executada sem reconferência — não
repita esse erro.

## Regras de ouro (invioláveis)

1. **Nunca altere dados já lançados anteriormente** — nem valores, textos, datas ou cores de
   linhas antigas. Escreva só nas linhas novas.
2. **Nunca mexa em outras abas** (ORÇAMENTO, NOTAS CNPJ, FLUXO DE CAIXA etc.).
3. **Não altere formatação existente**: formato de data, fontes, alinhamento. Para linhas
   novas, copie o estilo (fonte, borda, alinhamento, formato de número) das células da última
   linha preenchida.
4. **Nunca rode o recálculo via LibreOffice** (recalc.py do skill xlsx): reescreve os formatos
   de número da planilha inteira (datas viram m/d/yyyy, o formato R$ muda). Não precisa: o
   Excel recalcula sozinho ao abrir.

## Passo a passo

### 1. Localizar e preparar os arquivos

- **Esta skill trabalha com uma obra por vez.** Recebe do Supervisor só os itens já
  agrupados de uma única obra — se a lista recebida tiver mais de uma obra
  diferente, pare e avise o Supervisor: o agrupamento deveria ter acontecido antes
  de chamar esta skill.
- A planilha fica na pasta conectada de controle financeiro da obra (ex.:
  `D:\...\Controle Financeiro`).
- Atenção a `~$*.xlsx`: planilha pode estar aberta no Excel — avise que precisa fechar sem
  salvar.
- Copie a planilha para uma pasta de trabalho local antes de editar (nunca edite o arquivo
  montado do usuário direto). Guarde o `mtimeMs` para o commit final (feito na Etapa 3).

### 2. Entender a aba LANÇAMENTO

- Cabeçalho na linha 7: B=ITEM, C=DESCRIÇÃO E RESUMO MATERIAL, D=FORNECEDOR, E=NOTA/RECIBO,
  F=DATA, G=VALOR NOTA, H=CENTRO DE CUSTO, I=QUEM GASTOU.
- A coluna B já vem numerada; não renumere. Ache a última linha com dados em C e continue na
  seguinte.
- As primeiras linhas da coluna M (M2:M6) trazem a grafia exata dos nomes que ativam as
  fórmulas SUMIF — use sempre essa grafia na coluna I (a lista do Leitor já deve vir com essa
  grafia, mas confira).

### 3. Escrever cada item (na ordem cronológica da lista)

Para cada item da lista confirmada, na próxima linha vazia:

- **C** = Descrição. **D** = Fornecedor. **E** = Nota/Recibo (número, SN, NA ou ML).
  **F** = Data — como data de verdade (datetime), nunca como texto, mantendo o formato de
  exibição da planilha (dd/mm/aaaa). **G** = Valor — número puro, o formato R$ vem do estilo
  copiado. **H** = deixar em branco. **I** = Quem gastou, grafia exata da coluna M.
- **A** = se o item veio com flag REEMB, escreva "REEMB" com fundo amarelo, copiando o estilo
  de uma linha REEMB existente (se for a primeira da planilha, confirme com o usuário antes).
  Nota: o amarelo marca reembolso pendente do cliente; quando o cliente paga, o usuário mesmo
  pinta de verde depois — isso não é uma ação que você precisa fazer.
- Copie o estilo (fonte, borda, alinhamento, number_format) da última linha preenchida para a
  linha nova, célula a célula.
- **Cuidado com number_format ao copiar estilo**: a planilha costuma vir pré-formatada bem além
  da última linha com dado. Se a linha-modelo escolhida tiver um number_format levemente
  diferente do padrão da coluna, prefira o formato padrão (pegue de uma célula vazia abaixo dos
  dados) — a conferência final disso é feita pelo `ep-pintor-notas` na etapa seguinte, mas
  evite introduzir a diferença aqui.

### 4. Entregar para a próxima etapa

Ao terminar de escrever todos os itens, informe ao Supervisor: caminho do arquivo local
editado, quantas linhas foram escritas (intervalo), e repasse a lista original (com valores)
para o `ep-pintor-notas` conferir a soma.

## Troubleshooting

| Problema | Solução |
|---|---|
| Arquivo `~$*.xlsx` na pasta | Planilha aberta no Excel — pedir para fechar (sem salvar) antes de continuar |
| Editou a planilha direto no computador do usuário e o arquivo corrompeu | Nunca escreva a versão final direto no arquivo montado do usuário. Sempre: stage → edita cópia local → entrega pro `ep-pintor-notas` fazer o commit final |
| Acabou de copiar a planilha e a releitura mostra conteúdo antigo | Cache do estágio pode ficar defasado por alguns segundos — não confie numa releitura imediata, confirme pelo tamanho/mtime reportado pela própria escrita |

## O que ainda falta decidir

- O mapeamento exato de "nome da obra" (ex.: "MC-Ipanema") para o caminho da pasta/planilha
  de controle financeiro correspondente ainda não foi confirmado com o Guilherme — o
  Supervisor precisa dessa informação para rotear cada grupo de itens (ver
  `skill-supervisor-lancamento-ep.md`, passo 5) pra planilha certa.

## Log de mudanças

- **04/08/2026** — revisão do pipeline completo achou que esta skill (e o
  `notas-fiscais-ml`) estava escrita como se sempre existisse uma única planilha na
  conversa, mas o `ep-leitor-notas` normalmente produz itens de várias obras numa
  leitura só (o grupo do WhatsApp cobre todas as obras). Adicionada regra explícita
  de que esta skill trabalha uma obra por vez — o agrupamento por obra passou a ser
  responsabilidade do Supervisor (novo passo 5 lá).
