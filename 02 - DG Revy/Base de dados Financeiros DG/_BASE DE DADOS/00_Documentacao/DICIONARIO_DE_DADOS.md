# Dicionário de dados

Todos os CSV são UTF-8 com BOM, separador `;` e vírgula decimal — o Excel pt-BR abre direto.

> **Ao reler esses CSV em PowerShell**, converta os números com
> `[double]($s -replace '\.','' -replace ',','.')`. Um `[double]` direto sobre `"1836,58"` usa
> cultura invariante e devolve **183658**. É um erro silencioso: não quebra, só dá o número errado.

---

## 01_Extracao_Bruta\lancamentos_brutos.csv — 1.441 linhas

Extração fiel da aba LANÇAMENTO das 9 planilhas. Sem interpretação nenhuma.

| Campo | Descrição |
|---|---|
| `id_lancamento` | Chave única. `OBRA-ITEM` (ex. `VIS401-0161`). Ganha sufixo `L<linha>` quando o item é repetido na origem |
| `id_obra` | ATA603, PRU103, PRU104, VIS803, VIS401, GUS403, PRU614, RAI601, VIS509 |
| `status_obra` | CONCLUIDA \| ANDAMENTO |
| `item_original` | Número do item na planilha. É também o nome do arquivo da nota fiscal |
| `data` | dd/MM/yyyy, já convertida do serial do Excel |
| `data_bruta_origem` | O que estava na célula, sem tratamento |
| `data_inferida` | SIM quando a data foi corrigida — veja o README |
| `descricao_original` | Coluna C da origem, intocada |
| `fornecedor`, `nota_recibo` | Colunas D e E |
| `valor` | Coluna G. A soma por obra bate com a célula K4 |
| `tipo_planilha` | Coluna H (MAT/MDO). **Só 2 das 9 obras preenchem — não confiar** |
| `quem_gastou` | Coluna I |
| `origem_arquivo`, `origem_aba`, `origem_linha` | Caminho de volta à célula de origem |
| `nf_arquivo` | Caminho relativo da foto da nota fiscal |
| `obs_extracao` | Registro de qualquer intervenção feita na extração |

## 01_Extracao_Bruta\quadro_fechamentos.csv

Aba QUADRO FECHAMENTOS das planilhas. **`natureza_dado = ESPELHO_NAO_SOMAR`**: esses valores já
constam na aba LANÇAMENTO. Está aqui só para conferir parcelas de contrato. Somar dobraria o custo.

## 01_Extracao_Bruta\_conciliacao.csv

Uma linha por obra: nº de lançamentos, soma, K4 da planilha, diferença, período e nº de notas
ligadas. `confere = OK` significa diferença zero.

---

## 02_Base\fato_lancamentos.csv — 1.461 linhas

A base classificada. Mais linhas que lançamentos porque uma nota que reúne disciplinas vira mais de
uma linha, cada uma com sua parcela (critério herdado do FxF).

| Campo | Descrição |
|---|---|
| `servico` | Um dos 17 do cronograma, ou `INDIRETO (rateado)`, `MAO DE OBRA (equipe)`, `NAO_IDENTIFICADO` |
| `valor_lancamento` | Valor cheio do lançamento |
| `valor_alocado` | Parcela alocada a este serviço. **É este que se soma** |
| `natureza` | DIRETO \| INDIRETO \| A_DEFINIR |
| `fonte_classificacao` | `FxF` (conferida no projeto anterior) \| `DICIONARIO` (descrição idêntica a uma já classificada) \| `REGRA` (palavra-chave) \| `NENHUMA` |
| `confianca` | ALTA \| MEDIA \| NECESSITA_VALIDACAO |
| `multipla_disciplina` | SIM quando a descrição reúne disciplinas concorrentes |
| `obs_classificacao` | Os serviços candidatos e a pontuação de cada um |

## 02_Base\fato_custo_servico.csv — 124 linhas

Custo por obra e serviço, sempre em três visões:

| Campo | Descrição |
|---|---|
| `custo_direto` | Lançamentos atribuídos diretamente ao serviço |
| `indireto_rateado` | Parcela dos indiretos, proporcional ao custo direto |
| `custo_completo` | `custo_direto + indireto_rateado` |
| `pct_do_direto` | Peso do serviço no custo direto da obra |
| `custo_completo_m2` | Só quando a área está confirmada |
| `criterio_rateio` | O critério aplicado, em texto |

## 02_Base\dim_obras.csv — 9 linhas

Identificação, período e área de cada obra. As colunas `area_art_qtde`, `area_art_obs`,
`area_cronograma` e `area_qcargas` guardam **cada fonte separadamente**, e `area_m2` é o valor
adotado — vazio quando as fontes conflitam. `fonte_area` explica a escolha e `confianca_area` é
ALTA \| MEDIA \| BAIXA \| CONFLITO.

## 02_Base\fato_alocacao_servico.csv / dic_descricao_servico.csv

A classificação importada do Cronograma Físico x Financeiro e o dicionário descrição → serviço
aprendido a partir dela. Descrições que foram rateadas entre disciplinas ficam fora do dicionário:
ensinariam a regra errada.

## 02_Base\fato_mao_de_obra.csv, fato_mobiliario.csv, fato_custos_imovel.csv

**Vazias, com o cabeçalho pronto.** Recebem a mão de obra própria, o mobiliário e os custos do
imóvel quando esses dados chegarem. O domínio de `tipo_custo` do imóvel está em
`00_Documentacao\dominio_tipo_custo_imovel.csv`.

---

## 03_Pendencias

| Arquivo | O que é |
|---|---|
| `validar_areas.csv` | Uma linha por obra, com cada fonte de área, o alerta e a coluna `AREA_CORRIGIDA_PREENCHER_AQUI` |
| `revisar_nao_identificado.csv` | 152 lançamentos sem serviço, ordenados por valor |
| `revisar_divergencia_regra.csv` | Onde a regra discordou do FxF. Serve para melhorar `dicionario_classificacao.csv` |

## 04_Saidas

| Arquivo | O que é |
|---|---|
| `BASE_DG.xlsx` | A planilha navegável, 7 abas |
| `resumo_por_obra.csv` | Uma linha por obra, com direto, indireto, MDO, não identificado e total |
| `benchmark_por_servico.csv` | Média, mediana, mínimo, máximo e desvio de R$/m² por serviço |

---

## 99_Scripts\dicionario_classificacao.csv

**Este arquivo é feito para ser editado.** Cada linha é uma regra:

| Campo | Descrição |
|---|---|
| `prioridade` | Menor roda primeiro. Ferramentas e EPI (1–7) vêm antes das disciplinas (20–97) |
| `servico` | Serviço de destino |
| `padrao` | Termos separados por `\|`, sem acento e em minúsculas |
| `nota` | Por que a regra existe |

A classificação conta **quantos termos de cada serviço** aparecem na descrição; vence o serviço com
mais termos, e a prioridade desempata. Por isso "Mão de obra para instalação de infra de AC" vai
para Instalações Elétricas (2 termos) e não para Mão de Obra (1 termo).

Depois de editar, rode `03_classificar_lancamentos.ps1`: ele reafere as regras contra o gabarito do
FxF e mostra se a acurácia subiu ou caiu.

---

## 02_Base\fato_mao_de_obra.csv — uma linha por contrato × serviço

Mão de obra **contratada** das 3 obras em andamento, lida das células laranja da aba
`QUADRO FECHAMENTOS`. Cada contrato gera várias linhas, uma por serviço do seu escopo.

| Campo | Descrição |
|---|---|
| `id_mdo` | Chave sequencial (`MDO-0001`) |
| `contrato` | Texto do contrato, como está na planilha de origem |
| `profissional` | Bruno, Ivan, Tiago ou Ronaldo |
| `tipo_vinculo` | `CONTRATO_FECHADO` |
| `servico` | Serviço que recebeu esta parcela |
| `valor_contrato` | Valor cheio do contrato (repetido em todas as linhas dele) |
| `base_material` | Material daquele serviço usado como base do rateio |
| `pct_do_contrato` | Quanto por cento do contrato esta linha representa |
| `valor` | **A parcela alocada. É este campo que se soma** |
| `material_estimado` | `SIM` quando o serviço ainda não tinha compra e o material foi estimado pelo peso típico das concluídas |
| `valor_pago_contrato` | Quanto já foi pago do contrato — **zero nos nove** |
| `origem_arquivo`, `origem_aba`, `origem_linha` | Caminho de volta à célula laranja |

## 04_Saidas\benchmark_mao_de_obra.csv — R$/m² de MDO por serviço

`coef_variacao_pct` é a dispersão entre as 3 obras, e `confianca` a traduz: **USAVEL** (até 35%),
**PROVISORIO** (35–60%), **INSTAVEL** (acima). Só os usáveis servem para orçar hoje.

## 04_Saidas\mao_de_obra_por_obra.csv

Total contratado, total pago, R$/m² e número de contratos por obra.

## Colunas novas em fato_custo_servico.csv

`mao_de_obra_contratada` e `custo_com_mdo` (material + indireto + MDO), mais `mdo_m2`.
A MDO fica em coluna separada de propósito: material é desembolso realizado, MDO é valor fechado
ainda não pago. Somar os dois numa coluna só apagaria essa diferença.

> **Cuidado ao consultar os CSV com `awk -F';'`**: três descrições contêm `;` dentro do texto
> (ex.: "ar condicionado (2 de 18k; 3 de 12k)"). O arquivo está correto — os campos estão entre
> aspas — mas `awk` não respeita aspas e quebra essas linhas. Use `Import-Csv` no PowerShell, ou um
> parser que entenda CSV de verdade.
