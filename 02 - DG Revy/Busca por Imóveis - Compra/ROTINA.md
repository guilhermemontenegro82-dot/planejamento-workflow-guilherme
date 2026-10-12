# Rotina — Busca por Imóveis para compra (Ipanema e Leblon) · v1, 11/10/2026

Pasta raiz: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra`. Roda no Claude Code (VS Code), no PC do
Guilherme. Não precisa de navegador nem de ninguém olhando.

## O que o Guilherme faz
1. Abre o Claude Code na raiz do workspace e diz: **"atualizar a planilha de imóveis"** (ou "rodar a busca de apartamentos").
2. Fecha a planilha no Excel se ela estiver aberta (só isso trava a geração).
3. Recebe a prestação de contas no chat e abre a planilha.
4. Quando quiser, preenche as colunas **AVALIAÇÃO (SÓCIOS)** e **OBSERVAÇÕES** na aba `IMÓVEIS`: elas sobrevivem às próximas atualizações.
5. Para perguntar sem atualizar ("quais os melhores do Leblon?", "o que mudou?", "resumo para os sócios"): skill `busca-imoveis-consultar` (funciona também no Cowork, lendo a planilha/base da pasta).

Para mudar a busca: editar `Sites e critérios para Busca\criterios.json` (preço, área, tipos), `Listagem das ruas\ruas.csv` (ruas) ou pedir ao Claude para redesenhar os polígonos (`Áreas de interesse\poligonos\poligonos.html` mostra os atuais no navegador).

## O que acontece quando ele pede a atualização
```
0 Pré-voo        confere arquivos, cria _dados\<hoje>\
1 Coleta         3 coletores em paralelo (VivaReal/Zap · QuintoAndar · Chaves na Mão) → bruto-*.csv
                 consolidar.ps1: reconfere preço/área/tipo, decide a área (polígono + ruas), marca duplicatas → coleta.csv
2 Chequer 1      agente-chequer-coleta confere cobertura, fidelidade ao site, área, formato → CERTIFICADO-COLETA.certificado.md
3 Disponibilidade imóveis da base que não apareceram hoje são consultados um a um no site → verificacao.csv
4 Base           atualizar-base.ps1: novos, reativados, removidos (com data), preço alterado (com anterior) → _dados\base.csv
5 Planilha       gerar-planilha.ps1 regenera o xlsx a partir da base (abas IMÓVEIS, RESUMO, HISTÓRICO, CRITÉRIOS), preservando as colunas manuais
6 Chequer 2      agente-chequer-planilha confere planilha × base × coleta → CERTIFICADO-PLANILHA.certificado.md
7 Fechamento     commit no git + prestação de contas no chat
```
Tempo esperado: alguns minutos (a coleta é a parte lenta; páginas de anúncio do QuintoAndar e do Chaves na Mão são abertas uma a uma).

## Como ler a planilha
- `STATUS`: `ATIVO` (no ar e dentro da busca), `NOVO` destacado em verde na rodada em que entrou, `FORA DOS CRITÉRIOS` (continua no ar, mas preço/área saíram da faixa ou o endereço ficou fora da área), `REMOVIDO` (sumiu do site; linha em cinza, com a data).
- `ÁREA DE INTERESSE`: `SIM` (dentro do polígono), `LIMITE` (a até 50 m da borda ou nas 2 vias pendentes), `A CONFIRMAR` (sem número ou sem coordenada; a rua está na lista). Amarelo pede uma olhada humana.
- `VALOR/M²` e `CUSTO MENSAL` (condomínio + IPTU) são fórmulas. IPTU sempre em R$/mês.
- `POSSÍVEL DUPLICATA`: anúncios com o mesmo código `D001`, `D002`… parecem ser o mesmo imóvel em sites/imobiliárias diferentes.
- `LOCAL PESQUISA` = VivaReal/Zap (os dois portais compartilham o mesmo banco; o link principal é do VivaReal e `LINK ZAP` o do Zap), QuintoAndar ou Chaves na Mão.
- Aba `RESUMO`: contagens por bairro e fonte, novos/removidos/preços da rodada, R$/m² por bairro, 10 menores R$/m². Aba `HISTÓRICO RODADAS`: uma linha por rodada. Aba `CRITÉRIOS`: os parâmetros em vigor e as ruas.
- `BAIRRO` mostra `Ipanema`, `Leblon` ou `Arpoador (Copacabana)` (a fatia de Copacabana que está dentro da marcação de Ipanema).

## Onde fica cada coisa
```
_dados\base.csv                      fonte da verdade (todas as rodadas); a planilha é gerada dela
_dados\AAAA-MM-DD\                    coleta do dia, verificações, certificados, logs, PNGs de conferência
Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx   a planilha viva
Skills\                               skills (atualizar, consultar), agentes (chequers), scripts
```

## Instalar no Cowork (opcional)
Copiar as pastas `Skills\busca-imoveis-atualizar` e `Skills\busca-imoveis-consultar` como skills no Cowork. Lá, a de atualizar só avisa que a busca roda no Claude Code; a de consultar funciona normalmente lendo a pasta do projeto.
