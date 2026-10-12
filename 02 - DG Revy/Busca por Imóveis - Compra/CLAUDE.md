# Busca por Imóveis (Compra) — contexto do projeto (lido automaticamente pelo Claude Code)

Pesquisa recorrente de apartamentos à venda em Ipanema e Leblon (Rio de Janeiro) para decisão de compra do
Guilherme com os sócios investidores (DG Revy). Dono: Guilherme (explique simples, sem jargão; respostas curtas,
resultado primeiro; português do Brasil).

**Leia primeiro:** `ROTINA.md` (como a atualização roda), depois `Skills\CONTRATO-DADOS.md` (colunas, regras técnicas).
Descobertas sobre os sites: `_trabalho\DESCOBERTAS-TECNICAS.md`.

## Escopo de acesso
- Raiz deste projeto: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra`. Autonomia total aqui dentro.
- **Regra 1 do Guilherme: NUNCA mexer ou entrar com arquivos no OneDrive.** Este projeto não precisa de nada de lá.
- Qualquer outro caminho fora do workspace `D:\12- Claude - works`: pedir antes.
- Scripts, testes e arquivos de apoio em `_trabalho\` ou `Skills\scripts\`, nunca no diretório temporário da sessão.

## O que o Guilherme decidiu (11/10/2026) — não reabrir sem ele pedir
1. **Motor roda no Claude Code**, neste PC (scripts PowerShell + `curl.exe`). No Cowork só consulta/leitura.
2. **Área de interesse = polígono do mapa + lista de ruas como conferência.** Anúncio sem número/coordenada ou nas 2 vias pendentes entra como `LIMITE` / `A CONFIRMAR`, nunca descartado em silêncio.
3. **Imóvel que sumiu do site fica na planilha**, em cinza, `STATUS = REMOVIDO` + data. Mudança de preço guarda o anterior + data.
4. **Uma linha por anúncio** (site + código), com coluna `POSSÍVEL DUPLICATA` agrupando os que parecem o mesmo imóvel.
5. A planilha modelo dele é só o modelo de informações: a planilha viva pode ter mais colunas e formato melhor.
6. Critérios: apartamento residencial (inclui kitnet/studio), R$ 500.000 a R$ 1.100.000, 35 a 70 m² (`criterios.json`).

## Regras do projeto
- Skills executam (`Skills\busca-imoveis-atualizar`, `Skills\busca-imoveis-consultar`). Agentes só conferem (`Skills\agentes\`), nunca corrigem. Chequer roda em contexto isolado (ferramenta Agent, general-purpose, lendo o `.md` do agente).
- Toda skill/agente se anuncia (`▶ … iniciado`). Veredito PASS/FAIL por item com evidência citada. Etapa seguinte recusa iniciar sem certificado `APROVADO` da anterior (arquivos `CERTIFICADO-*.certificado.md` na pasta da rodada).
- Fechamento sempre com prestação de contas (etapa por etapa: feita, pulada com motivo ou falhou).
- Nunca apagar linha da base; nunca alterar a planilha modelo; nunca declarar cobertura que não houve.
- HTTP só pelo `curl.exe` do Windows (o .NET é barrado pelo Cloudflare). Sem navegador, sem instalar nada.
- `.ps1` com BOM UTF-8; CSV UTF-8 com BOM, `;`, decimal com ponto, datas ISO.
- Git: commit ao fechar cada rodada/etapa (texto, scripts, CSVs; nunca xlsx). Mensagem clara.
- Arquivos temporários meus: apagar livremente. Conteúdo do Guilherme: só quando a tarefa pedir.

## Mapa
```
Áreas de interesse\            mapas dele (JPG) · poligonos\ (geojson gerados + poligonos.html para conferir no navegador)
Listagem das ruas\             documento dele · ruas.csv (45 vias com CEP/faixa/lado; 2 pendentes)
Sites e critérios para Busca\  documento dele · criterios.json (parâmetros em vigor)
Planilha de Apartamentos Pesquisados\
                               Planilha modelo (INTOCÁVEL) · Apartamentos Pesquisados - Ipanema e Leblon.xlsx (viva)
Skills\                        busca-imoveis-atualizar\ · busca-imoveis-consultar\ · agentes\ · scripts\ · CONTRATO-DADOS.md
_dados\                        base.csv (fonte da verdade) · AAAA-MM-DD\ (coleta, verificação, certificados, logs de cada rodada) · geocache.csv
_trabalho\                     testes, relatórios de construção, descobertas técnicas
```

## Ferramentas desta máquina (verificado em 11/10/2026)
Windows 10, PowerShell 5.1, Excel 16 (COM), `curl.exe` 8.13 em `System32`, Git. **Sem Python, Node, Playwright.**
VivaReal e Zap compartilham o mesmo banco (glue-api); QuintoAndar e Chaves na Mão têm APIs internas documentadas em `_trabalho\DESCOBERTAS-TECNICAS.md`.

## Premissas e decisões registradas (acrescentar aqui, com data)
- 11/10/2026 — Kitnet/studio incluído porque a URL do QuintoAndar que ele mandou tinha `/apartamento/kitnet`; aparece em `TIPO` para filtrar.
- 11/10/2026 — Copacabana entra na busca só para alimentar a fatia do Arpoador coberta pelo polígono de Ipanema.
- 11/10/2026 — IPTU normalizado para R$/mês em toda a planilha (VivaReal informa anual; a base original fica em `iptu_informado`).
- 11/10/2026 — Borda do polígono: 50 m = `LIMITE`; coordenada aproximada precisa estar a mais de 150 m para dentro para ser `SIM`.
- 11/10/2026 — Anúncio que continua no ar mas saiu da busca (preço ou área mudou para fora) fica `FORA DOS CRITÉRIOS`, não `REMOVIDO`.
- 11/10/2026 — **IPTU sem rótulo confiável** (VivaReal e Chaves na Mão): valor ≤ 700 é lido como cota mensal, > 700 como anual (÷12); limite em `criterios.json` (`iptu_limite_mensal`; 0 = só o rótulo do site). A validar pelo Guilherme em 2 ou 3 anúncios.
- 11/10/2026 — **VivaReal sem o dedup da API** (`categoryPage=RESULT` desligado): a API agrupava anúncios irmãos (mesmo imóvel em filiais da mesma rede) sob um id representante que muda entre rodadas (8,9 % dos ids trocaram em 6 h), o que geraria falsos NOVO/REMOVIDO. Com ids estáveis, os irmãos entram como linhas separadas e o consolidador os marca em `POSSÍVEL DUPLICATA`, exatamente como ele decidiu.
- 11/10/2026 — QuintoAndar: API real em `apigw.prod.quintoandar.com.br/house-listing-search`; o site só informa faixa de andar (`4-7`), não o andar exato.
- 11/10/2026 — **Regras de área v2** (depois da primeira coleta real; `Skills\CONTRATO-DADOS.md`): a lista de ruas dele pesa como conferência. Rua incluída + coordenada dentro ou até 50 m fora = `SIM`; via pendente = `LIMITE`; rua não listada dentro do polígono a mais de 50 m da borda = `SIM` (ex.: Júlio de Castilhos, Antônio Parreiras, na fatia do Arpoador); rua não listada fora = `NAO`. Resultado na 1ª rodada: SIM 787, LIMITE 169, A CONFIRMAR 65 (antes: 491 / 430 / 365).
- 11/10/2026 — Cobertura (15) e Flat (18) ficaram fora por `tipos_incluidos` = Apartamento + Kitnet/Studio. **A confirmar com ele**; para incluir, basta acrescentar em `criterios.json`.
- 11/10/2026 — Duplicatas em dois graus: `D###` = mesma rua+número (provável mesmo imóvel em várias imobiliárias); `P###` = só rua/CEP sem número (mesmo prédio ou lançamento, podem ser unidades diferentes).
- 11/10/2026 — Pendentes para ele decidir: incluir ou não o trecho final da Av. N. S. de Copacabana (1109/1170 ao fim) e a Rua Francisco Sá (hoje `LIMITE`/`A CONFIRMAR`, ~130 anúncios); prédios de frente para a Av. Visconde de Albuquerque (`LIMITE`).
