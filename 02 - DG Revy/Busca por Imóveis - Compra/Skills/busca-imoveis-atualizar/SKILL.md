---
name: busca-imoveis-atualizar
description: "Atualiza a planilha de apartamentos à venda em Ipanema e Leblon (DG Revy, compra para investimento): busca VivaReal/Zap, QuintoAndar e Chaves na Mão com os critérios do Guilherme (R$ 500 mil a 1,1 milhão, 35 a 70 m², dentro das áreas marcadas no mapa), acrescenta os anúncios novos, confere se os antigos continuam no ar e marca os removidos, com chequers independentes em cada etapa. Use sempre que o Guilherme pedir para 'atualizar a planilha de imóveis', 'rodar a busca de apartamentos', 'buscar imóveis', 'procurar apartamentos em Ipanema/Leblon', 'ver se tem imóvel novo', 'conferir se os imóveis ainda estão disponíveis' ou qualquer pedido de atualização da pesquisa de compra de imóveis."
---

# Busca por Imóveis (Compra) — Atualizar a planilha

Anuncie-se: `▶ busca-imoveis-atualizar — rodada <AAAA-MM-DD> iniciada`.

Raiz: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra` (chame de `<raiz>`). Leia antes `CLAUDE.md` e `Skills\CONTRATO-DADOS.md` da raiz. Português do Brasil, respostas curtas, resultado primeiro.

## Onde esta skill roda
- **Claude Code no PC do Guilherme (Windows, PowerShell disponível): modo completo**, descrito abaixo. É o modo normal.
- **Cowork (sem PowerShell no PC): não há como rodar a busca.** Diga em uma linha que a atualização roda no Claude Code, ofereça o que dá para fazer aqui (ler a planilha e responder perguntas: skill `busca-imoveis-consultar`) e pare. Nunca tente buscar os sites pelo navegador: é lento, o VivaReal/Zap bloqueia e o resultado não é confiável.

## Regras invioláveis
1. Tudo acontece dentro de `<raiz>`. Nada no OneDrive, nunca. Nada no diretório temporário da sessão.
2. A planilha modelo do Guilherme (`Planilha de Apartamentos Pesquisados\Planilha modelo para preenchimento.xlsx`) é intocável.
3. Nenhuma linha da base é apagada. Imóvel que sumiu vira `REMOVIDO` com data; preço que mudou guarda o anterior. As colunas manuais `AVALIAÇÃO (SÓCIOS)` e `OBSERVAÇÕES` são dele e sobrevivem a toda regeneração.
4. Só os scripts falam com os sites (`curl.exe`). Sem navegador, sem instalar nada.
5. Etapa seguinte não começa sem o certificado `APROVADO` da anterior. Reprovou: corrige e reconfere (até 2 rodadas); persistindo, para e explica.
6. Nunca declarar cobertura que não houve. Fonte que falhou é dita como falhou, e os anúncios dela na base **não** são marcados como removidos naquele dia.
7. Zero perguntas de permissão. Pergunta só de conceito, e só se a resposta mudar o trabalho (ex.: ele pediu para mudar um critério e a instrução é ambígua).

## Etapa 0 — Pré-voo
1. `$hoje = (Get-Date -Format yyyy-MM-dd)`; `$dados = "<raiz>\_dados\$hoje"`; criar a pasta (se já existir, a rodada é refeita no mesmo dia: pode sobrescrever os arquivos de hoje).
2. Conferir que existem: `Sites e critérios para Busca\criterios.json`, `Listagem das ruas\ruas.csv`, `Áreas de interesse\poligonos\ipanema.geojson` e `leblon.geojson`, e os scripts em `Skills\scripts\` (`coletar-vivareal.ps1`, `coletar-quintoandar.ps1`, `coletar-chavesnamao.ps1`, `consolidar.ps1`, `verificacoes.ps1`, `verificar-vivareal.ps1`, `verificar-quintoandar.ps1`, `verificar-chavesnamao.ps1`, `atualizar-base.ps1`, `gerar-planilha.ps1`, `area.ps1`).
3. Se a planilha viva (`Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx`) estiver aberta no Excel (`Get-Process EXCEL` + tentativa de abrir o arquivo para escrita falha), avise em uma linha e peça para fechar; enquanto isso, siga até a etapa 5 (a geração da planilha é a última).
4. Diga ao Guilherme, em 2 linhas, o que vai acontecer e que ele pode continuar trabalhando.

## Etapa 1 — Coleta (os 3 coletores em paralelo)
Rode os três em segundo plano (PowerShell, `run_in_background`), cada um com `-Saida "$dados"`:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\coletar-vivareal.ps1" -Saida "<raiz>\_dados\<hoje>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\coletar-quintoandar.ps1" -Saida "<raiz>\_dados\<hoje>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\coletar-chavesnamao.ps1" -Saida "<raiz>\_dados\<hoje>"
```
Espere os três. Para cada um, leia o `.log` e o exit code: `0` = cobertura completa; `2` = parcial (o log diz o que faltou); outro = falhou. Anote por fonte: total declarado pelo site × linhas obtidas, tempo, erros. Fonte que falhou de vez (sem `bruto-<fonte>.csv`): registrar `FONTE INDISPONÍVEL` e seguir com as outras.

Depois, consolidar (área + duplicatas + reconferência dos critérios):
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\consolidar.ps1" -Pasta "<raiz>\_dados\<hoje>"
```
Saída: `coleta.csv`, `consolidar.log`, `consolidar-resumo.json`. Olhe o resumo: se `A CONFIRMAR` passar de 40 % das linhas, algo quebrou no módulo de área (geocodificação ou polígonos): investigue antes de seguir.

## Etapa 2 — Certificado de coleta + chequer
Escreva `<dados>\CERTIFICADO-COLETA.md`:
```
CERTIFICADO DE COLETA — rodada <hoje>
Fontes: VIVAREAL <exit> (<obtidos>/<declarado pelo site>) | QUINTOANDAR ... | CHAVESNAMAO ...
Consolidado: <n> linhas aceitas | área: SIM <n> LIMITE <n> A CONFIRMAR <n> NAO <n> | duplicatas: <n> grupos
Fontes indisponíveis: <lista ou nenhuma>
Arquivos: coleta.csv (<n> linhas, <hash SHA256 curto>), bruto-*.csv, logs
Premissas desta rodada: <lista ou nenhuma>
```
Depois invoque o chequer **em contexto isolado**: ferramenta `Agent` (`subagent_type: general-purpose`), com o prompt: *"Você é o agente descrito em `<raiz>\Skills\agentes\agente-chequer-coleta.md`. Leia esse arquivo inteiro e execute o papel dele à risca. Parâmetros: pasta da rodada `<dados>`; certificado `<dados>\CERTIFICADO-COLETA.md`; rodada do chequer n."* Ele grava `<dados>\CERTIFICADO-COLETA.certificado.md` com `VEREDITO: APROVADO|REPROVADO`.
Leia o veredito. `REPROVADO`: corrija o que ele apontou (script, consolidação ou o próprio certificado), rode de novo o que precisar e chame o chequer de novo (rodada n+1), no máximo 2 vezes. Só siga com `APROVADO`.

## Etapa 3 — Disponibilidade dos imóveis antigos
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\verificacoes.ps1" -Modo listar -Pasta "<raiz>\_dados\<hoje>"
```
Gera `a-verificar-<fonte>.csv` com as chaves da base que não apareceram hoje (na primeira rodada não há base: pule para a etapa 4). Para cada fonte **que coletou com sucesso** (exit 0 ou 2) e tem arquivo a verificar:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\verificar-vivareal.ps1"    -Chaves "<dados>\a-verificar-vivareal.csv"    -Saida "<dados>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\verificar-quintoandar.ps1" -Chaves "<dados>\a-verificar-quintoandar.csv" -Saida "<dados>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\verificar-chavesnamao.ps1" -Chaves "<dados>\a-verificar-chavesnamao.csv" -Saida "<dados>"
```
(podem rodar em paralelo). Fonte que falhou na coleta: **não verificar** (os anúncios dela ficam como estavam). Depois:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\verificacoes.ps1" -Modo juntar -Pasta "<raiz>\_dados\<hoje>"
```
Saída `verificacao.csv` (`ATIVO` = ainda no ar mas fora da busca; `INATIVO`/`NAO_ENCONTRADO` = vira REMOVIDO; `ERRO` = fica como estava).

## Etapa 4 — Atualizar a base
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\atualizar-base.ps1" -Pasta "<raiz>\_dados\<hoje>" -Rodada <hoje>
```
Saída: `<raiz>\_dados\base.csv` (fonte da verdade; a anterior vai para `<dados>\base-anterior.csv`), `resumo-rodada.json` (novos, reativados, removidos, preço alterado, fora dos critérios, não verificados) e `atualizar-base.log`. Leia o resumo.

## Etapa 5 — Planilha
Se a planilha estiver aberta no Excel, peça para fechar e espere (é a única pausa possível). Depois:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<raiz>\Skills\scripts\gerar-planilha.ps1" -Base "<raiz>\_dados\base.csv" -Saida "<raiz>\Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx" -Rodada <hoje> -ResumoRodada "<dados>\resumo-rodada.json"
```
Acrescente `-Png "<dados>\png"` para exportar as imagens de conferência. O script lê as colunas manuais da planilha anterior (backup em `manuais-backup-<data>.csv` ao lado do xlsx), regenera as abas `IMÓVEIS`, `RESUMO`, `HISTÓRICO RODADAS` ("Histórico" sozinho é nome reservado no Excel pt-BR) e `CRITÉRIOS`, e grava `gerar-planilha.log` ao lado do xlsx. Olhe os PNGs (Read): coluna estreita, texto cortado, número como texto.

## Etapa 6 — Certificado da planilha + chequer
Escreva `<dados>\CERTIFICADO-PLANILHA.md` (rodada, caminho do xlsx, linhas por aba, contagens do resumo-rodada.json, hash curto do xlsx e do base.csv, backup das colunas manuais). Invoque o chequer isolado (`Agent`, general-purpose): *"Você é o agente descrito em `<raiz>\Skills\agentes\agente-chequer-planilha.md`. Leia esse arquivo inteiro e execute o papel dele à risca. Parâmetros: pasta da rodada `<dados>`; certificado `<dados>\CERTIFICADO-PLANILHA.md`; planilha `<caminho do xlsx>`; rodada do chequer n."* Mesma regra: só fecha com `APROVADO` (até 2 correções).

## Etapa 7 — Fechamento
1. `git add` dos arquivos de texto do projeto (skills, scripts, CSVs de dados, certificados, logs; **não** xlsx) e `git commit -m "Busca Imóveis: rodada <hoje> — <n> novos, <n> removidos, <n> preços alterados"`; `git push` se houver remoto. Siga o `.gitignore` do workspace.
2. Prestação de contas no chat, neste formato, curto:
```
✔ Planilha atualizada — rodada <hoje>
<caminho do xlsx>

Coleta: VivaReal/Zap <n> · QuintoAndar <n> · Chaves na Mão <n>  (dentro da área: <n>; limite/a confirmar: <n>)
Base: <total> anúncios, <ativos> ativos
Novos: <n>   Removidos: <n>   Preço alterado: <n> (<n> caíram)   Reativados: <n>
Destaques novos (menor R$/m²): 1) <bairro, endereço, área, preço, R$/m², link>  2) ...  3) ...
Pendências: <A CONFIRMAR n — por quê> · <fonte indisponível> · <nenhuma>
Chequers: coleta APROVADO (rodada n) · planilha APROVADO (rodada n)
Etapas: 0 ✔ 1 ✔ 2 ✔ 3 ✔/pulada (1ª rodada) 4 ✔ 5 ✔ 6 ✔ 7 ✔
```
Toda etapa aparece na lista como feita, pulada (com motivo) ou falhou. Nunca omitir.

## Quando algo dá errado
- Site fora do ar / Cloudflare barrando o `curl.exe`: registre no certificado como fonte indisponível, siga com as outras, e diga na prestação de contas. Não insista mais do que as 3 tentativas do script.
- `A CONFIRMAR` em excesso: abra `consolidar.log`; se a geocodificação (Nominatim) falhou, rode `area.ps1 -Teste`; se os polígonos sumiram, pare e avise.
- Excel preso (processo EXCEL.EXE órfão): `Stop-Process -Name EXCEL` só se não houver janela do Excel aberta pelo Guilherme (`MainWindowTitle` vazio).
- Mudança de critério pedida por ele (preço, área, ruas, mapa): edite `criterios.json` / `ruas.csv` / polígonos **e registre no CLAUDE.md da raiz** (seção "Premissas e decisões"), depois rode a atualização normalmente.

## Log de mudanças
- 11/10/2026 — v1, escrita no Claude Code a partir dos documentos do Guilherme (critérios, ruas, planilha modelo, mapas) e das decisões dele: motor no Claude Code; área = polígono + ruas; removidos ficam na linha, marcados; uma linha por anúncio com marcação de duplicata.
