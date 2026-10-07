# Base Histórica de Custos DG

Banco histórico de custos das obras de reforma da DG. Nasceu para que perguntas como
"qual nosso custo médio por m²?" ou "quanto custa um banheiro?" sejam respondidas a partir de uma
base já destrinchada, em vez de reabrir planilhas e projetos a cada pergunta.

**Comece por:** `04_Saidas\BASE_DG.xlsx`, aba *1. Leia-me*.

---

## Antes de usar qualquer número

A base tem **duas metades que não se somam**:

- **5 obras concluídas** — só material e serviços de terceiros. A mão de obra da equipe não está
  nas planilhas de origem dessas obras.
- **3 obras em andamento** (Rainha 601, Prudente 614, Visconde 452) — têm os contratos de mão de
  obra, lançados em 29/09/2026 a partir das células laranja da aba `QUADRO FECHAMENTOS`. São
  valores **contratados, ainda não pagos**: o "Total pago" está zerado nos nove contratos.

Por isso o R$/m² de material das concluídas **não é comparável** com um R$/m² que inclua mão de
obra, e na tabela de custo por serviço a MDO fica em **coluna própria**, nunca somada ao material.

---

## O que tem dentro

9 obras — 5 concluídas, 4 em andamento — e 1.484 lançamentos financeiros, R$ 1.019.369,56.

| Obra | Status | Lanç. | Total | Área | R$/m² |
|---|---|---|---|---|---|
| ATA603 Ataulfo de Paiva 630/603 | Concluída | 189 | 99.175,06 | 54 m² | 1.836,58 |
| PRU103 Prudente de Morais 1757/103 | Concluída | 159 | 94.090,55 | 100 m² | 940,91 |
| PRU104 Prudente de Morais 1757/104 | Concluída | 197 | 93.142,37 | 55 m² | 1.693,50 |
| VIS803 Visconde de Pirajá 584/803 | Concluída | 176 | 107.159,71 | 43,5 m² | 2.463,44 |
| VIS401 Visconde de Pirajá 584/401 | Concluída | 190 | 98.394,08 | 55 m² | 1.788,98 |
| GUS403 Gustavo Sampaio 528/403 | Andamento | 129 | 146.544,31 | 63 m² | — |
| PRU614 Prudente de Morais 614/103 | Andamento | 69 | 58.396,12 | 80 m² | — |
| RAI601 Rainha da Bélgica 621/601 | Andamento | 251 | 236.397,68 | 187 m² | — |
| VIS509 Visconde de Pirajá 452/509 | Andamento | 124 | 86.069,68 | 50 m² | — |

Obra em andamento tem desembolso incompleto: por isso não entra em média histórica e não tem R$/m²
publicado. O campo `status_obra` separa as duas coisas em todas as tabelas.

---

## Estrutura de pastas

```
_BASE DE DADOS\
├── 00_Documentacao\   este README, dicionário de dados, critérios, logs
├── 01_Extracao_Bruta\ extração fiel das planilhas, sem interpretação
├── 02_Base\           as tabelas da base
├── 03_Pendencias\     o que precisa da conferência do Guilherme
├── 04_Saidas\         BASE_DG.xlsx e os CSVs de resultado
└── 99_Scripts\        os .ps1, reexecutáveis
```

### Como atualizar quando uma obra nova fechar

Rode os scripts em ordem, de `99_Scripts`:

```powershell
.\01_extrair_lancamentos.ps1      # extrai e concilia com K4
.\02_importar_classificacao_fxf.ps1
.\03_classificar_lancamentos.ps1  # classifica e afere as regras
.\04_montar_dim_obras.ps1         # áreas e sanidade de R$/m²
.\05_ratear_e_consolidar.ps1      # rateio e custo por serviço
.\06_gerar_planilha.ps1           # BASE_DG.xlsx
.\08_analisar_banheiros.ps1      # areas molhadas
.\10_importar_mao_de_obra.ps1    # contratos de MDO (celulas laranja)
.\11_benchmark_mao_de_obra.ps1   # MDO por m2 + grau de confianca
.\09_gerar_resumo_raiz.ps1       # planilha RESUMO na raiz
```

Os scripts são idempotentes: rodar de novo regenera tudo a partir das planilhas de origem, que
nunca são alteradas — são abertas somente em modo leitura.

---

## Rastreabilidade

Todo lançamento carrega `origem_arquivo`, `origem_aba` e `origem_linha`: de qualquer número num
gráfico se chega à célula exata da planilha que o originou. O campo `nf_arquivo` aponta a foto da
nota fiscal correspondente — as notas são nomeadas pelo número do item do lançamento
(item 100 → `Notas Fiscais\Numeradas\100.jpg`); a grande maioria dos lançamentos tem a nota ligada.

---

## Grau de confiança

**Financeiro: exato.** A soma dos lançamentos bate com a célula K4 de cada planilha nas 9 obras,
diferença zero. O rateio fecha com o lançado (diferença total de R$ 0,09, arredondamento).

**Classificação: 79,6% aferida.** 588 linhas vêm da classificação já conferida no Cronograma Físico
x Financeiro. O restante foi classificado por regras de palavra-chave, e essas regras foram testadas
contra as 550 linhas que o FxF já havia classificado: acertaram 79,6%. Fora do FxF, portanto, cerca
de 1 em cada 6 classificações pode precisar de ajuste. As divergências estão em
`03_Pendencias\revisar_divergencia_regra.csv` e servem para melhorar
`99_Scripts\dicionario_classificacao.csv`, que é um CSV editável.

**Não classificado: 1,5% do valor**, 147 lançamentos, listados em
`03_Pendencias\revisar_nao_identificado.csv`.

**Áreas: as 9 preenchidas.** Vêm das ARTs do CREA, dos cronogramas, dos quadros de carga e das
plantas de projeto.

Critério de desempate, definido em 20/09/2026: **vale a área de projeto**; não havendo área de
projeto confiável, adota-se a **média das áreas encontradas**. As divergências são pequenas e não
deslocam os indicadores, e com mais obras na base o efeito tende a zero. O campo `criterio_area`
registra como cada número foi obtido:

| Obra | Fontes | Adotado | Critério |
|---|---|---|---|
| PRU103 | ART 100 m²; planta cotada `DG_AP_R00_CONSTRUIR` | 100 m² | PROJETO |
| PRU104 | ART: campo 50 m², observações 60 m² | 55 m² | média das fontes |
| VIS803 | ART 42 m²; quadro de cargas 45 m² | 43,5 m² | média das fontes |

As outras seis têm fontes concordantes.

### Indicadores de R$/m² — 5 obras concluídas

Média **R$ 1.744,68/m²** · mediana **R$ 1.788,98** · mínimo 940,91 (PRU103) · máximo 2.463,44
(VIS803) · desvio padrão 542,15. Ponderado por área (307,5 m² no total): **R$ 1.599,88/m²**.

O PRU103 puxa a média para baixo por ser a maior obra da série (100 m²) com custo total parecido
com o das demais: o desvio é de porte e escopo, não de erro de área — a planta cotada confirma a
metragem. Lembrando que tudo isso é **sem mão de obra própria**.

---

## Correções feitas na origem

O dado bruto nunca é sobrescrito: fica em `data_bruta_origem`, a correção vai em `data`, e
`data_inferida = SIM` sinaliza a intervenção.

| Lançamento | Origem trazia | Adotado | Por quê |
|---|---|---|---|
| PRU103-0045 | texto `2408/2025` | 24/08/2025 | vizinhas: 22/08 e 27/08/2025 |
| VIS401-0049 | texto `15/072025` | 15/07/2025 | vizinhas: ambas 15/07/2025 |
| RAI601-0026 | `10489.29` na célula de data | 17/06/2026 | a célula recebeu o próprio valor; vizinhas 16/06 e 18/06 |
| RAI601-0120 (2 linhas) | item 120 repetido | ids separados por linha | numeração repetida na origem; nota fiscal não ligada, por ambiguidade |

---

## Armadilhas conhecidas desta base

**`QUADRO FECHAMENTOS` não é fonte de custo.** Essa aba espelha as parcelas de contratos
(ar-condicionado, gás, granito, vidro, esquadrias) que **já estão lançados** na aba LANÇAMENTO.
Verificado na VIS401: os R$ 11.030 de esquadrias do Julio aparecem nas linhas 161 e 196 da
LANÇAMENTO. Está extraída em `01_Extracao_Bruta\quadro_fechamentos.csv` apenas para conferência,
marcada como `ESPELHO_NAO_SOMAR`. Somá-la dobraria o custo desses itens.

**A coluna MAT/MDO da planilha de origem não é confiável.** Só 2 das 9 obras a preenchem. Ela está
preservada como `tipo_planilha`, mas a classificação da base não depende dela.

**Ferramenta não é material.** "Raspador de gesso acartonado" é ferramenta, não gesso;
"desbastador de porcelanato" é ferramenta, não revestimento. As regras tratam isso com prioridade
acima das disciplinas.

**Os arquivos do Cronograma Físico x Financeiro ganham sufixo de revisão** ("FxF - Gustavo Sampaio
403 - R01.xlsx"). O script 02 procura por padrão de nome e usa sempre a revisão mais recente — se
procurasse pelo nome exato, a obra sairia da importação silenciosamente na próxima revisão, que foi
exatamente o que aconteceu durante a construção desta base.

---

## Mão de obra (incluída em 29/09/2026)

Fonte: as células **laranja** da aba `QUADRO FECHAMENTOS` das obras em andamento — doze contratos,
três em cada uma das quatro obras. São valores **fechados**.

| Obra | Bruno (civil) | Ivan (pintura) | Tiago (revest./portas) | Total | Área | MDO R$/m² |
|---|---|---|---|---|---|---|
| Rainha 601 | 173.000 | 20.000 | 24.000 | 217.000 | 187 m² | 1.160,43 |
| Prudente 614 | 93.000 | 15.000 | 13.000 | 121.000 | 80 m² | 1.512,50 |
| Visconde 452 | 96.000 | 15.000 | 6.000 | 117.000 | 50 m² | 2.340,00 |
| Gustavo Sampaio 403 | 123.800 | 15.000 | 9.750 | 148.550 | 63 m² | 2.357,94 |

Média **R$ 1.842,72/m²** · ponderado por área (380 m²) **R$ 1.588,29/m²**.

### Gustavo Sampaio: o caso da dupla contagem

É a única obra que tem contrato fechado **e** mão de obra de equipe já paga e lançada: R$ 53.770 em
11 pagamentos semanais ao Bruno e sua equipe, contra um contrato civil de R$ 123.800 do mesmo
Bruno, mesmo escopo. O "Total pago" do contrato está zerado na planilha.

Critério definido em 29/09/2026: **esses pagamentos são parcelas do contrato, não custo adicional**.
Pago efetivo R$ 53.770, saldo R$ 70.030. Ao consolidar, o script desconta o que já foi pago antes de
somar o contratado:

`total_com_mdo = lançado − MDO de equipe já paga + MDO contratada`

Para a Gustavo Sampaio: 146.544,31 − 53.770 + 148.550 = **R$ 241.324,31** (R$ 3.830,54/m², com a
obra ainda em andamento). Sem esse desconto, a mão de obra do Bruno entraria duas vezes.

**Detalhe técnico que importa:** essa MDO é reconhecida pela **descrição do lançamento**, não pelo
campo `servico`. Onde o FxF já havia classificado, ele prevalece e diluiu esses pagamentos nas
disciplinas — a linha "MAO DE OBRA (equipe)" nem chega a existir nessa obra.

A aba "MDO Equipe – Média Semanal" criada na Gustavo Sampaio (R$ 4.888/semana em 11 semanas) fica
**fora da base por enquanto**, como conferência do Guilherme.

### Como cada contrato foi distribuído entre os serviços

Cada contrato cobre várias disciplinas. A distribuição é **proporcional ao material** de cada
disciplina na própria obra.

Onde a disciplina ainda não tinha compra (a Prudente-614 não tem material de pintura, portas nem
granitos), o material esperado foi estimado pelo **peso típico daquela disciplina nas 5 obras
concluídas**, trazido para a escala da obra. A coluna `material_estimado` marca essas linhas.

Decisões de escopo:
- **Emboço, impermeabilização e iluminação** entram no contrato do Bruno, por serem serviço
  civil/elétrico, ainda que não citados na descrição.
- **ADM de obra** é diluída nas disciplinas técnicas, sem linha própria — por isso INDIRETO não
  participa da base de rateio.
- **Esquadrias de vidro/alumínio e marcenaria** ficam de fora: a mão de obra já está no preço do
  fornecedor.

### Quanto confiar em cada número

O **total por obra é sólido** — vem de contrato fechado e não depende de rateio nenhum.

O **valor por serviço ainda oscila**, porque as três obras estão em fases diferentes e o rateio
segue o material comprado até agora. `benchmark_mao_de_obra.csv` traz o coeficiente de variação
entre as obras e classifica cada serviço:

| Confiança | CV | Serviços |
|---|---|---|
| **Usável** | até 35% | Granitos-Bancadas (11%), Portas (18%), Revestimentos (32%), Alvenaria (33%) |
| **Provisório** | 35–60% | Pintura (39%), Demolição (48%), Elétrica (59%) |
| **Instável** | acima de 60% | Impermeabilização (68%), Emboços (70%), Gesso (78%), Hidráulica (79%), Granitos-Soleiras (82%), Iluminação (90%) |

Use só os **usáveis** para orçar. Os demais se firmam quando as obras fecharem e o material estiver
completo — aí basta rodar os scripts 10 e 11 de novo.

Atenção ao incluir obra nova: ao entrar a Gustavo Sampaio, a **Elétrica caiu de usável (16%) para
provisório (59%)**. Mais obra nem sempre estabiliza o indicador — reconferir a tabela a cada inclusão.
