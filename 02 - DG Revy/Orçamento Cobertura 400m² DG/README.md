# Orçamento — Cobertura duplex 400 m² (DG)

**Entregável:** `01_Planilha Final\Orçamento Cobertura 400m² DG - R03.xlsx` (revisões anteriores em `01_Planilha Final\Desatualizados`) — orçamento de custo por etapas, para o cliente.

| Pasta | O que tem | Pode apagar? |
|---|---|---|
| `Projeto base para Orçamento` | Plantas do 1º e 2º andar (referência das quantidades) | Não |
| `01_Planilha Final` | A planilha do orçamento | Não |
| `02_Memoria de Calculo` | `indices_base.csv` (índices extraídos da base DG) e `itens_orcamento.csv` (todos os itens com qtd, preço e origem) | Não — é o que sustenta cada número |
| `03_Pesquisa de Precos Internet` | Itens pesquisados na internet, com fonte | Não |
| `99_Scripts` | `01_indices_da_base.ps1` e `02_gerar_planilha_orcamento.ps1` — regeneram tudo | Não — é a ferramenta de atualização |
| `Lixo - pode apagar` | Buscas e imagens de conferência de layout | **Sim** |

## Como atualizar

- **Mudar uma medida ou premissa** (área, prazo, comprimento do alimentador, bancadas): edite as células amarelas da aba *Premissas* direto no Excel. Tudo se recalcula.
- **Mudar um preço, item ou etapa:** edite o bloco `ITENS` em `99_Scripts\02_gerar_planilha_orcamento.ps1` e rode o script (sobrescreve a planilha).
- **Base DG atualizada** (obra nova, mão de obra lançada): rode `01_indices_da_base.ps1` e confira os índices novos em `02_Memoria de Calculo\indices_base.csv` antes de copiá-los para o gerador.

## Revisões

| Rev. | Data | Total | O que mudou |
|---|---|---|---|
| R00 | 26/09/2026 | R$ 1.390.213 | Primeira versão. MDO = pagamentos semanais da GUS403 projetados para 19 semanas (R$ 1.365,29/m²). |
| R01 | 29/09/2026 | R$ 1.219.880 | MDO pelos 9 contratos de empreitada da base revisada (Bruno, Ivan, Tiago em RAI601, PRU614, VIS509): reta fixo + R$/m² por empreiteiro, R$ 379.544 (R$ 948,86/m²). Índices de material reprocessados com a base de 29/09 (elétrica 94,22, gesso 42,03, iluminação 34,10 R$/m²; indiretos 12,04%). Retirado o item 9.5 (instalação de bancadas) — está no contrato do Tiago. |
| R02 | 29/09/2026 | R$ 1.248.068 | Serviços sem histórico na base pesquisados, com a fonte em cada item: nova etapa 19 (mão de obra especializada: manta e pastilha pelo SINAPI-RJ ago/2026; deck, equipamentos da piscina, churrasqueira e coifa por guias de preço) e materiais que faltavam (primer e proteção mecânica da manta; barrotes, parafusos inox e stain do deck; areia do filtro; base e frete da churrasqueira). Nova cor de fonte: SINAPI-RJ (lilás). |
| R03 | 29/09/2026 | R$ 1.230.672 | Entraram os 3 contratos de mão de obra da GUS403 (Leme, 63 m²: Bruno R$ 123.800, Ivan R$ 15.000, Tiago R$ 9.750). Retas refeitas com 4 obras / 12 contratos: R$ 85.085 fixos + R$ 692,66/m² (r = 0,937). Etapa 18 = R$ 362.148 (R$ 905,37/m²), antes R$ 379.544 (R$ 948,86/m²). |

## Decisões tomadas com o Guilherme

- **Mão de obra (R01, atualizada na R03 com o Leme):** contratos de empreitada da base DG — 12 contratos em 4 obras. Em obra maior o R$/m² cai (parcela fixa se dilui), então aplica-se a reta fixo + variável, e não um R$/m² fixo. 400 m² está fora da faixa medida (50–187 m²): é extrapolação, declarada na planilha; teto de referência = R$/m² da Rainha × 400 = R$ 464.172.
- Serviços sem contrato de referência na base (R02): SINAPI-RJ quando há composição oficial; senão guia de preço de mercado, ponto médio da faixa, sempre com a fonte e o link no item.
- Escopo ampliado: revestimentos, impermeabilização, pisos secos, iluminação, ar-condicionado, portas, gás e reforma da piscina.
- Apresentação: custo + acompanhamento técnico de R$ 6.000/mês × prazo (11 meses, pela produtividade da Rainha).
- Marcenaria: R$ 1.000/m² × 400 m² (definido pela DG).