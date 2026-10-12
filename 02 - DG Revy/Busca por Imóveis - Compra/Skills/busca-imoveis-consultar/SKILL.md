---
name: busca-imoveis-consultar
description: "Consulta a pesquisa de apartamentos à venda em Ipanema e Leblon (DG Revy) sem rodar busca nova: responde perguntas sobre a planilha e a base (menores R$/m², o que entrou ou saiu desde a última rodada, quedas de preço, filtros por bairro, quartos, vagas, andar), monta o resumo para os sócios investidores e explica como um imóvel foi classificado. Use quando o Guilherme perguntar 'quais os melhores imóveis', 'o que mudou na planilha', 'quantos imóveis temos no Leblon', 'me manda um resumo para os sócios', 'por que esse imóvel está como limite', ou qualquer pergunta sobre a pesquisa de compra de imóveis que não seja pedido de atualização (para atualizar, é a skill busca-imoveis-atualizar). Funciona no Claude Code e no Cowork."
---

# Busca por Imóveis (Compra) — Consultar

Anuncie-se: `▶ busca-imoveis-consultar iniciada`.
Raiz: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra`. Português do Brasil, resposta curta, resultado primeiro.

## Fontes de leitura (nesta ordem)
1. `_dados\base.csv` — fonte da verdade (UTF-8, separador `;`, decimal com ponto). Colunas em `Skills\CONTRATO-DADOS.md` (seção "Base").
2. `_dados\<última rodada>\resumo-rodada.json` — novos, removidos, reativados, preço alterado da última rodada; `consolidar-resumo.json` — contagens por fonte e por área.
3. `Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx` — só quando ele perguntar algo que está na planilha e não na base (colunas manuais dele: `AVALIAÇÃO (SÓCIOS)`, `OBSERVAÇÕES`), ou no Cowork, se preferir ler a planilha.
Nunca altere nenhum desses arquivos nesta skill. Nada de busca nova nos sites.

## Como responder
- **Ranking / "melhores"**: por padrão, só `status = ATIVO` e `dentro_area = SIM`, ordenado por R$/m² (preco / area_util) crescente; mostre bairro, endereço (rua, nº), área, preço, R$/m², condomínio + IPTU mensais, quartos, vagas, destaques, link. Diga quantos ficaram de fora por `LIMITE`/`A CONFIRMAR` e ofereça incluí-los.
- **"O que mudou"**: leia o `resumo-rodada.json` mais recente (listas `novos`, `removidos`, `preco_alterado`, `reativados`) e traduza em frases; traga os links dos novos.
- **Filtros** (bairro, faixa de preço, quartos, vagas, andar, elevador, varanda, vista): aplique sobre a base; `destaques` é lista separada por ` | `.
- **"Por que esse imóvel está como LIMITE / A CONFIRMAR / REMOVIDO"**: cite `motivo_area`, `precisao_coord`, `removido_em` e o `evidencia` do `verificacao.csv` da rodada em que saiu.
- **Resumo para os sócios**: texto pronto para WhatsApp/e-mail, até 15 linhas: data da rodada, total ativo por bairro, mediana de R$/m² por bairro, 5 melhores oportunidades (com link), o que saiu e o que caiu de preço, pendências. Sem jargão.
- Valores em reais com separador de milhar (`R$ 980.000`), R$/m² sem centavos, área com `m²`.
- Se a base não existir ainda, diga que a primeira rodada ainda não rodou e que é a skill `busca-imoveis-atualizar` que a cria.

## Ferramentas
- Claude Code: PowerShell (`Import-Csv -Delimiter ';' -Encoding UTF8`), ou leitura direta do CSV.
- Cowork: leia o CSV/planilha da pasta do projeto com as ferramentas de arquivo disponíveis; se só a planilha estiver acessível, use a aba `IMÓVEIS` (coluna `CHAVE` identifica o anúncio).

## Log de mudanças
- 11/10/2026 — v1.
