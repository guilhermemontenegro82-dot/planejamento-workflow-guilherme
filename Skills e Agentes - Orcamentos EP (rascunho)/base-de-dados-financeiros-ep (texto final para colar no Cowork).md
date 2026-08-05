---
name: base-de-dados-financeiros-ep
description: "Consultar a base de dados financeira e de preços de obras da EP Engenharia — orçamentos fechados, custo real por disciplina, catálogo de preços por serviço, benchmarks de R$/m² e margem histórica por tipo de obra. Use sempre que o usuário pedir para orçar uma obra nova (completa ou uma estimativa rápida de bate-papo), comparar preço de venda x custo, checar margem/lucro de obras já executadas, ou buscar uma referência de preço por disciplina (elétrica, hidráulica, pintura, mão de obra etc.) ou por tipo de obra (apartamento, cobertura, telhado, pintura avulsa etc.) da EP Engenharia. Fonte única de preços da EP — substitui a antiga skill referencia-orcamento."
---

# Base de Dados Financeiros — EP Engenharia

## Quando invocar este skill

Sempre que o pedido envolver preço, orçamento, custo, margem, lucro, benchmark de R$/m² ou histórico de obras da EP Engenharia — mesmo que o usuário não cite os nomes dos arquivos diretamente.

## Como esses arquivos chegam até você

No início de cada orçamento novo, o usuário compartilha duas pastas juntas: a pasta de projeto da obra a ser orçada, e a pasta "Base de Dados", que contém um arquivo `_LEIA-ME` (visão geral) e os arquivos descritos abaixo. Trate os nomes de arquivo como identificadores — não assuma nenhum caminho fixo.

## Ordem de consulta ao iniciar um orçamento novo

1. **`_LEIA-ME`** — abrir primeiro, visão geral rápida da base.
2. **Entender o job**: tipo de obra, bairro, área (m²) e escopo (reforma completa ou parcial) — vem da pasta de projeto compartilhada junto.
3. **Escolher a referência de R$/m² certa dentro de `BENCHMARK - Disciplinas por Obra EP`**:
   - Reforma completa de apartamento, 40 a 200 m²: aba "Benchmark Reforma Completa" (mais confiável para esse perfil).
   - Apartamento/cobertura na mesma faixa de área mas com escopo parcial (só pintura, só varanda etc.): aba "Benchmark Apto 40-200m2" — atenção, ela mistura escopos e isso puxa a mediana de Mão de Obra pra baixo.
   - Qualquer outro perfil (fora da faixa de área, não é apartamento etc.): aba "Benchmark Geral", que cobre todas as obras.
4. **Itens de serviço específicos** (ex.: "quanto custa troca de piso vinílico"): procurar em `Catálogo de Preços por Serviço`.
5. **Aplicar o BDI**: os valores do Benchmark e do Catálogo são de CUSTO. Para chegar num preço de venda, aplicar o BDI (historicamente 25% a 30%) por cima.
6. **Conferir a margem esperada** em `BANCO DE DADOS - Obras EP` (aba "Resumo Executivo") — para saber se o preço sugerido está dentro da faixa de rentabilidade histórica da empresa (Margem = Lucro / Recebido).
7. **`EP - Histórico de obras executadas 21-22-23-24-25`** — consultar por último, só como contexto histórico adicional (não foi auditado como os outros 3).

## Modo estimativa rápida (bate-papo, não vira proposta formal)

Quando o pedido for só "me dá uma ideia de quanto custa" — não vai virar orçamento formal nem proposta pro cliente — não rodar a ordem de consulta completa acima. Abrir só:

1. `BENCHMARK - Disciplinas por Obra EP`, aba **"Benchmark Reforma Completa"** (reforma de apartamento 40–200 m²) ou **"Benchmark Geral"** (qualquer outro perfil).
2. Ler a linha de **TOTAL** (R$/m²) — conferir na legenda da aba se já é venda (com BDI) ou custo puro antes de responder.
3. Responder com o valor, deixando claro que é estimativa, não orçamento fechado: algo como "ballpark de R$ X/m², baseado no benchmark de obras similares — pra um número fechado preciso montar o orçamento completo."

Não abrir os outros 3 arquivos neste modo — o objetivo aqui é ser rápido e barato. Se o pedido evoluir para "monta o orçamento" de verdade, seguir a ordem de consulta completa acima.

## Os 4 arquivos de referência

1. **`BANCO DE DADOS - Obras EP`** — P&L por obra fechada (jan/2025 em diante), 24 obras. Abas: "Banco de Dados" (Orçamento, Total Recebido, Total Gasto, Lucro, Margem, Observação por obra + linha de TOTAIS), "Resumo Executivo" (ranking de lucratividade + estatísticas agregadas), "Legenda" (definição de cada coluna). **Use para**: resultado financeiro real de uma obra já fechada, ou estatísticas agregadas da empresa.
2. **`BENCHMARK - Disciplinas por Obra EP`** — R$/m² por disciplina (16 categorias). Abas principais: "Orçamento por Disciplina" e "Gasto Real por Disciplina" (uma coluna por obra), "Benchmark Geral", "Benchmark Reforma Completa", "Benchmark Apto 40-200m2", "Resumo das Obras" (cross-check consolidado). **Use para**: pesquisar um preço de referência por disciplina/m² para uma proposta nova.
3. **`Catálogo de Preços por Serviço`** — banco de preços item a item (1148 linhas, 30 obras, 19 categorias de disciplina — taxonomia mais granular que o Benchmark). Colunas: Disciplina, Serviço, Unidade, Material, Mão de obra, Total, Obra, Ano. **Valores de CUSTO** (pré-BDI). **Use para**: preço de um serviço específico já praticado em obras anteriores.
4. **`EP - Histórico de obras executadas 21-22-23-24-25`** — ledger histórico bruto e mais amplo (obras de 2021 a 2025, ~430 linhas, uma aba só). **Não foi auditado/cruzado como os outros 3** — obras mais antigas e menos estruturadas, algumas nem aparecem nos outros arquivos. Se uma obra aparecer tanto aqui quanto no Banco de Dados, o Banco de Dados é a fonte mais confiável.

Cada um dos 4 arquivos tem sua própria aba "Legenda" ou "Leia-me" com a definição exata de cada coluna — **sempre confira lá antes de assumir o significado de uma coluna**.

## A pasta com o histórico de cada obra (documentos-fonte)

Subpastas, uma por obra (nomeada `<código> - <iniciais> - <descrição> - <bairro>`), com os documentos originais — nunca editar. Estrutura típica: uma pasta "Controle Financeiro" (lançamentos reais de gasto/recebimento) e uma pasta "Orçamento" (planilha de orçamento item a item + proposta enviada ao cliente). Obras menores podem ter só a proposta em PDF/docx, sem planilha própria — nesse caso os dados no Catálogo/Benchmark vêm de leitura manual do PDF, sinalizado na respectiva linha.

## Custo x Venda (regra mais importante)

Dentro do orçamento de cada obra existem duas visões paralelas dos mesmos itens:

- **Custo puro**: colunas "MATERIAL"/"MDO" na seção "LANÇAMENTO CUSTOS" — o que a EP efetivamente paga.
- **Preço de venda**: colunas "Material"/"Mão de obra" na aba "ORÇAMENTO" — valor cobrado do cliente, já com BDI aplicado (historicamente 25% a 30% sobre o custo).

O Catálogo de Preços e as abas "Orçamento por Disciplina"/"Gasto Real por Disciplina" do Benchmark usam base de **CUSTO**. Já "Orçamento" e "Total Recebido" no Banco de Dados são valores de **VENDA**. Não misturar as duas ao comparar números entre arquivos diferentes.

## Fórmula de margem (padronizada em 03/08/2026)

`Margem (%) = Lucro / Total Recebido` (não mais Lucro/Orçamento). Foi corrigido depois de descobrirmos que 11 de 24 obras tinham "Total Recebido" errado (copiado por engano do Orçamento ou do Gasto). Use a invariante `Lucro = Recebido − Gasto` para validar qualquer número novo — se não bater, desconfie da fonte.

## Taxonomias de disciplina (cuidado, são diferentes)

- **Catálogo de Preços**: 19 categorias ("01 Serviços Preliminares" ... "19 Outros").
- **Benchmark**: 16 categorias (mesma lista, mas sem "Gerenciamento" na aba "Benchmark Geral") — ao mapear entre as duas, pular esse item; não iterar as duas listas em paralelo sem esse ajuste.

## Avisos conhecidos / limitações

- **"Benchmark Apto 40-200m2"** controla TAMANHO mas não ESCOPO: mistura reformas completas com obras de escopo parcial, o que puxa para baixo medianas de disciplinas grandes como Mão de Obra. Para orçar uma reforma completa, preferir "Benchmark Reforma Completa".
- 4 obras não têm planilha de orçamento própria estruturada — dados vieram de PDFs de proposta, com granularidade menor. Sinalizado nas respectivas linhas do Catálogo.
- Obras anteriores a 2025 foram deliberadamente deixadas fora do Banco de Dados/Benchmark — decisão do usuário (obras mais antigas, sazonais/atípicas), não é erro.

## Apêndice — margem por tipo de obra (dado legado, pendente de auditoria)

Antes desta skill existir, a skill `referencia-orcamento` (hoje aposentada) mantinha uma tabela de margem e R$/m² por **tipo de obra** (não por disciplina). Essa visão ainda não foi confirmada como coberta pelas abas atuais desta skill (`Benchmark Geral` organiza por **disciplina**, um eixo diferente de "tipo de obra").

**Enquanto isso não for verificado**: para orçar uma obra fora do perfil apartamento, usar as tabelas abaixo como referência secundária — sinalizando sempre, ao citá-las, que são dado **não auditado** e podem carregar o erro de "Total Recebido" já corrigido nas outras fontes desta skill (ver Log de mudanças). Nunca usar sem esse aviso.

### Margem e R$/m² típicos por tipo de serviço (mediana, dado legado)

| Tipo de serviço | Venda/m² | Custo/m² | Margem |
|---|---|---|---|
| Reforma de apartamento — completa | 2.800–3.500 | 1.500–1.640 | 22–35% |
| Reforma de ambiente — parcial (banheiro, varanda, forro) | 400–1.500 | 200–1.200 | ~30% |
| Cobertura — completa | 2.500–2.750 | 2.000–2.150 | 22–25% |
| Telhado / calha / cobertura parcial | 640–1.375 | 450–815 | 30–40% |
| Pintura / piso vinílico | 200–640 | 90–265 | 40–60% |
| Impermeabilização / infiltração | ~520 | ~255 | ~50% |
| Revestimento / fachada | — | ~220 | ~58% |
| Estrutural / manilhamento / diversos | 440–1.665 | 360–1.900 | ~37% |

> Reforma completa de apartamento tem a **menor margem** (muita mão de obra); serviços especializados (pintura, impermeabilização, fachada) têm margem bem maior. Não replicar a margem de um tipo em outro.

### Quadro de obras (dado legado — venda = orçado contratado; custo = total gasto)

| Nº | Cliente | Serviço | Área m² | Venda R$ | Custo R$ | Venda/m² | Custo/m² | Margem |
|---|---|---|---|---|---|---|---|---|
| 436 | MC | Reforma Apartamento - Arpoador | 55 | 230.937 | 193.203 | 4.199 | 3.513 | 20% |
| 582 | MC | Reforma Apartamento - Leblon | 75 | 263.773 | 206.200 | 3.517 | 2.749 | 22% |
| 517 | AC | Reforma Apartamento - Copacabana | 45 | 137.000 | 63.601 | 3.044 | 1.413 | 54% |
| 511 | AC | Reforma Apartamento - Laranjeiras | 60 | 170.000 | 66.278 | 2.833 | 1.105 | 62% |
| 546 | MC | Reforma Apartamento - Ipanema | 76 | 211.076 | 159.521 | 2.792 | 2.110 | 26% |
| 524 | PS | Reforma Cobertura - Recreio | 241 | 660.319 | 515.328 | 2.740 | 2.138 | 22% |
| 410 | PS | Obra Cobertura - Leblon | 383 | 951.977 | 762.500 | 2.486 | 1.991 | 25% |
| 384 | RA | Apartamento - Copacabana | 160 | 254.805 | 182.672 | 1.593 | 1.142 | 31% |
| 588 | AP | Reforma em Varanda - Jardim Oceânico | 72 | 105.000 | 86.043 | 1.458 | 1.195 | 23% |
| 712 | PA | Manilhamento - Alto da Boa Vista | 30 | 43.794 | 14.113 | 1.460 | 470 | 65% |
| 716 | MC | Apartamento - Laranjeiras | 300 | 413.831 | 359.657 | 1.379 | 1.199 | 12% |
| 609 | JM | Reparo em Telhado - Botafogo | 12 | 16.500 | 9.797 | 1.375 | 816 | 41% |
| 671 | AS | Serviços Telhado e Cobertura - Barra | 10 | 12.399 | 4.554 | 1.240 | 455 | 63% |
| 320 | CP | Reforma Apartamento - Barra | 200 | 189.070 | 148.480 | 945 | 742 | 35% |
| 669 | IM | Telhado e passarela técnica - Joquei | 250 | 224.000 | 196.351 | 896 | 785 | 12% |
| 720 | GB | Reforma Cobertura Campos Novos | 94 | 61.707 | 37.615 | 656 | 400 | 47% |
| 733 | AS | Troca de Calha - Coelho Neto | 10 | 6.426 | 3.364 | 643 | 336 | 48% |
| 619 | ES | Piso Vinílico e Pintura - AlphaBarra | 19 | 12.136 | 5.013 | 639 | 264 | 59% |
| 796 | FP | Serviços Cobertura - Atlântico Sul | 25 | 13.438 | 14.144 | 538 | 566 | 24% |
| 703 | FP | Infiltração Jardineira - Atlântico Sul | 25 | 13.028 | 6.372 | 521 | 255 | 52% |
| 757 | AM | Tratamento Estrutural - Botafogo | 30 | 13.836 | 8.212 | 461 | 274 | 41% |
| 627 | AC | Reforma Apartamento - Tijuca | 85 | 37.574 | 20.420 | 442 | 240 | 46% |
| 715 | IM | Gerenciamento Giappo - Joquei | 250 | 106.000 | 41.777 | 424 | 167 | 61% |
| 697 | BZ | Reforma AP - Lúcio Costa | 70 | 26.850 | 31.175 | 384 | 445 | 1% |
| 769 | AG | Pintura Apartamento - Botafogo | 85 | 19.500 | 12.468 | 229 | 147 | 40% |
| 764 | AG | Pintura e rejunte - Tijuca | 85 | 17.500 | 7.766 | 206 | 91 | 56% |
| 789 | GB | Reforma em Forro - Barra | 25 | 3.799 | 2.342 | 152 | 94 | 38% |
| 755 | EP | Reforma de Banheiro - Pedra de Itaúna | 18 | 16.670 | 22.016 | 926 | 1.223 | -11% |
| 724 | IM | Mandarim Civil - Jockey | 250 | 416.161 | 474.601 | 1.665 | 1.898 | 21% |
| 710 | IM | Telhado Parcial Mandarim - Joquei | 250 | 24.435 | 24.578 | 98 | 98 | 24% |
| 007 | GE | Troca de Revestimento Fachada - Méier | — | 46.171 | 20.291 | — | — | 58% |

**Ação pendente**: conferir se as abas "Resumo das Obras" (Benchmark) ou "Banco de Dados"/"Resumo Executivo" já dão essa mesma visão por tipo de obra. Se sim, apagar este apêndice inteiro e usá-las como fonte auditada.

## Como trabalhar com esses arquivos com segurança

- Antes de tirar qualquer conclusão de uma coluna, conferir a aba "Legenda"/"Leia-me" do próprio arquivo — nomes de coluna se repetem entre arquivos, mas nem sempre significam a mesma coisa (ver "Custo x Venda" acima).
- Ao montar um orçamento, sempre conferir a matemática: Lucro = Recebido − Gasto, Margem = Lucro / Recebido. Se não bater, tem algo errado na leitura ou na fonte.
- **Nunca editar os 4 arquivos de referência diretamente sem antes copiar o original para um backup** (ex.: `_backup_antes_correcoes_AAAA-MM-DD`). Já houve pelo menos um caso real de dado errado nesta base (Total Recebido incorreto em 11 obras, corrigido em 03/08/2026) — trate os valores como prováveis, mas verificáveis, não como verdade absoluta sem checagem.

## Log de mudanças

- **03/08/2026**: auditoria de consistência dos 4 arquivos; padronização de Margem = Lucro/Recebido; correção de Total Recebido em 11 obras; preenchimento do Catálogo/Benchmark para 4 obras; criação da aba "Benchmark Apto 40-200m2"; criação desta skill e do índice `_LEIA-ME`.
- **03/08/2026**: absorção da skill `referencia-orcamento` (aposentada) — adicionado o "Modo estimativa rápida" e o "Apêndice — margem por tipo de obra" (dado legado, não auditado, pendente de confirmar cobertura em "Resumo das Obras"/"Banco de Dados").
