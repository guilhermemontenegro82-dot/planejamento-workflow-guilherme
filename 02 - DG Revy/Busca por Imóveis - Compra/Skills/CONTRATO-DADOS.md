# Contrato de dados e regras da casa — Busca por Imóveis (Compra)

Raiz do projeto: `D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra`. Tudo que o pipeline
cria fica dentro desta raiz. **Nunca** escrever fora dela (e nunca, em hipótese alguma, no OneDrive).
Scripts e testes meus ficam em `_trabalho/` e `Skills/scripts/`, nunca no diretório temporário da sessão.

## Pastas
```
Áreas de interesse/            mapas do Guilherme (JPG) + poligonos/ (ipanema.geojson, leblon.geojson, pontos-teste.csv)
Listagem das ruas/             documento do Guilherme + ruas.csv (extraído dele)
Sites e critérios para Busca/  documento do Guilherme + criterios.json
Planilha de Apartamentos Pesquisados/
                               Planilha modelo (dele, INTOCÁVEL) + "Apartamentos Pesquisados - Ipanema e Leblon.xlsx" (a planilha viva)
Skills/                        SKILL.md das skills, agentes/ (chequers) e scripts/ (PowerShell)
_dados/                        base.csv (fonte da verdade) + AAAA-MM-DD/ (coletas brutas, verificações, certificados, log de cada rodada)
_trabalho/                     testes, rascunhos, relatórios de construção
```

## Regras técnicas obrigatórias (desta máquina)
1. HTTP **só** com `& "$env:SystemRoot\System32\curl.exe"` (o .NET é barrado pelo Cloudflare). UA de Chrome. Timeout 40 s, até 3 tentativas com pausa de 2 s entre elas; pausa de 0,4 s entre páginas do mesmo site.
2. JSON grande: `System.Web.Script.Serialization.JavaScriptSerializer` com `MaxJsonLength = [int]::MaxValue` (`Add-Type -AssemblyName System.Web.Extensions`). `ConvertFrom-Json` só para respostas pequenas.
3. Arquivos `.ps1` gravados **com BOM UTF-8** (acentos nos comentários quebram o PS 5.1 sem BOM). Ao criar com a ferramenta Write, conferir e, se faltar, regravar com `[System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($true)))`.
4. PowerShell é **case-insensitive**: nunca duas variáveis que só diferem por caixa; variável de laço nunca com nome de uma letra que colida com um dicionário. `${var}` quando a interpolação for seguida de `:`. `@()` em volta de `Where-Object`/`Select -Unique` antes de `.Count`/índice. Casts `[int]`. Conversão de decimal pt-BR só para string vinda de CSV.
5. CSV: UTF-8 **com BOM**, separador `;`, decimal com **ponto** (cultura invariante), datas ISO `yyyy-MM-dd` (hora: `yyyy-MM-dd HH:mm`). Campos de texto entre aspas quando contiverem `;`, aspas ou quebra de linha (usar `Export-Csv -Delimiter ';' -NoTypeInformation -Encoding UTF8` e depois garantir o BOM). Listas dentro de um campo separadas por ` | `.
6. Cada script aceita `-Saida <pasta>` (padrão `_dados\<hoje>`) e grava um log `<nome>.log` ao lado da saída, com contagens e erros. Termina com `exit 0` só se completou; qualquer página que falhou nas 3 tentativas → `exit 2` e log do que faltou (nunca fingir cobertura completa).
7. Nada de navegador. Nada de instalar programa.

## Critérios (de `Sites e critérios para Busca/criterios.json`)
Apartamento residencial à venda (inclui kitnet/studio, sinalizado em `tipo`), **preço R$ 500.000 a R$ 1.100.000** e **área útil 35 a 70 m²** (limites inclusivos), em Ipanema e Leblon conforme os polígonos (o de Ipanema avança sobre Arpoador/Copacabana). Os coletores aplicam preço/área/tipo nos filtros do site **e** reconferem localmente; a decisão de área (polígono + ruas) é do consolidador.

## Arquivo bruto de cada coletor — `_dados/<data>/bruto-<fonte>.csv`
Uma linha por anúncio. Colunas, nesta ordem e com estes nomes exatos:

| coluna | tipo | regra |
|---|---|---|
| `chave` | texto | `<fonte>_<codigo>` — ex.: `VIVAREAL_2915533435`, `QUINTOANDAR_892859489`, `CHAVESNAMAO_47495700`. Chave primária em todo o pipeline. |
| `fonte` | texto | `VIVAREAL` (cobre VivaReal e Zap), `QUINTOANDAR`, `CHAVESNAMAO` |
| `codigo` | texto | id do anúncio no site |
| `link` | texto | URL completa do anúncio (VivaReal: href da API ou `https://www.vivareal.com.br/imovel/...-id-<id>/`) |
| `link_alt` | texto | VivaReal: URL do mesmo anúncio no Zap, se obtida; outros: vazio |
| `tipo` | texto | `Apartamento`, `Kitnet/Studio`, `Cobertura`, `Flat`, `Outro` |
| `titulo` | texto | título do anúncio (até 200 caracteres) |
| `rua` | texto | logradouro como o site informa (`Rua Visconde de Pirajá`); vazio se oculto |
| `numero` | texto | número; vazio se oculto |
| `cep` | texto | `22410-002` (com hífen); vazio se não informado |
| `bairro_site` | texto | bairro como o site informa |
| `lat`, `lon` | número | WGS84 com ponto decimal; vazio se não houver |
| `precisao_coord` | texto | `exata` (ponto do imóvel), `aproximada` (site informa aproximado), `bairro` (centroide do bairro), `nenhuma` |
| `preco` | número | R$ inteiros |
| `area_util` | número | m² (VivaReal `usableAreas[0]`, QA `area`, CNM `area.useful`) |
| `area_total` | número | m² se houver, senão vazio |
| `condominio_mes` | número | R$/mês; vazio se não informado |
| `iptu_mes` | número | **R$/mês normalizado**: VivaReal `yearlyIptu/12` arredondado; QA `iptu` (já mensal); CNM conforme a página do anúncio disser (anual → /12). Vazio se não informado |
| `iptu_informado` | texto | o valor e a base como o site deu, ex.: `760/ano`, `330/mês` (auditoria) |
| `quartos`, `banheiros`, `suites`, `vagas` | número | inteiros; vazio se não informado (0 explícito = 0) |
| `andar` | texto | número do andar ou vazio |
| `anunciante` | texto | nome da imobiliária/anunciante |
| `tipo_anunciante` | texto | `Imobiliária`, `Particular`, `Construtora`, `Plataforma` (QuintoAndar), vazio se desconhecido |
| `publicado_em` | data | data de publicação/criação no site (ISO) ou vazio |
| `atualizado_em` | data | data da última atualização no site (ISO) ou vazio |
| `capturado_em` | data-hora | quando o coletor pegou (ISO, hora local) |
| `fotos` | número | quantidade de fotos (se disponível) |
| `destaques` | texto | lista ` | ` normalizada em minúsculas, extraída de amenities/descrição/título: `varanda`, `vista mar`, `vista livre`, `reformado`, `garden`, `elevador`, `portaria 24h`, `piscina`, `academia`, `mobiliado`, `andar alto`, `quadra da praia`, `aceita financiamento`, `aceita permuta`, `sol da manhã`, `silencioso`, `vaga na escritura`, `dependência`, `churrasqueira`, `pet`, `lavabo`. Só o que aparecer de fato. |
| `descricao_resumo` | texto | primeiros 300 caracteres da descrição, sem quebras de linha |
| `status_site` | texto | `ATIVO` para tudo que veio da busca. **Última coluna do bruto.** |

Não existe coluna com o JSON do anúncio: os JSONs de página ficam em `_dados/<data>/json/<fonte>/` para auditoria. (Os coletores gravam uma coluna extra `bruto_json` no fim, vazia ou com o nome do JSON de auditoria em `json/<fonte>/`; o consolidador a ignora.)

## Consolidado — `_dados/<data>/coleta.csv`
Todas as colunas acima + `dentro_area` (`SIM`, `LIMITE`, `A CONFIRMAR`, `NAO`), `motivo_area` (texto curto, ex.: `polígono Ipanema, 120 m da borda`, `rua na lista; nº oculto`, `coordenada aproximada a 30 m da borda`, `rua fora da lista`), `poligono` (`Ipanema`, `Leblon` ou vazio), `bairro` (nome para a planilha: `Ipanema`, `Ipanema/Arpoador` quando o polígono é Ipanema e o site diz Copacabana, `Leblon`; fora dos polígonos, o `bairro_site`), `duplicata_grupo` (id de grupo quando outro anúncio tem área ±2 m² e preço ±2 % no mesmo endereço: `D001`, `D002`… = mesma rua+número (provável mesmo imóvel em várias imobiliárias); `P001`, `P002`… = só rua/CEP sem número (mesmo prédio ou lançamento: podem ser unidades diferentes); vazio se único).
Regras de área (ordem; versão 2 de 11/10/2026, depois da primeira coleta real — a lista de ruas do Guilherme pesa como conferência). Primeiro classificar a rua com `ruas.csv` (faixa de número e lado quando houver): **incluída**, **pendente**, **fora** (rua conhecida, não listada) ou **sem rua**. Depois, havendo coordenada (`exata` ou `aproximada`) e a distância à borda do polígono:
(1) **incluída**: dentro → `SIM`; fora até 50 m → `SIM` (motivo "na borda"); fora de 50 a 300 m com coordenada aproximada → `A CONFIRMAR`; além → `NAO` (motivo cita o conflito lista × polígono, ex.: Bartolomeu Mitre ao norte da Humberto de Campos).
(2) **pendente**: dentro ou fora até 50 m → `LIMITE`; fora de 50 a 300 m aproximada → `A CONFIRMAR`; além → `NAO`.
(2b) **fora** (não listada): dentro a mais de 50 m da borda → `SIM` (motivo "rua não listada"); dentro até 50 m → `LIMITE`; fora → `NAO`.
(2c) **sem rua**: `exata` dentro → `SIM`, até 50 m da borda (dentro ou fora) → `LIMITE`, fora além → `NAO`; `aproximada` dentro a mais de 150 m → `SIM`, dentro até 150 m → `LIMITE`, fora até 300 m → `A CONFIRMAR`, além → `NAO`.
(3) sem coordenada mas com rua+número: geocodificar (Nominatim/Overpass com interpolação de números, cache em `_dados/geocache.csv`) e voltar aos passos acima com precisão `exata`; se a geocodificação falhar, cair no passo 4. (4) sem coordenada útil: rua na lista `ruas.csv` (respeitando faixa de número e lado quando houver) → `A CONFIRMAR` com motivo `rua na lista; sem coordenada`; rua fora da lista → `NAO`; sem rua → `A CONFIRMAR` se `bairro_site` for Ipanema, Leblon, Arpoador ou Copacabana, senão `NAO`. As duas vias pendentes do documento (Rua Francisco Sá; Av. N. S. de Copacabana do 1109/1170 ao fim) contam como `LIMITE` quando decidirem sozinhas.
Só `SIM`, `LIMITE` e `A CONFIRMAR` vão para a planilha; `NAO` fica no CSV para auditoria.

## Base — `_dados/base.csv` (fonte da verdade entre rodadas)
Colunas do consolidado + `status` (`ATIVO`, `REMOVIDO`, `FORA DOS CRITÉRIOS`), `primeira_captura` (data), `ultima_verificacao` (data), `removido_em` (data ou vazio), `preco_anterior`, `preco_alterado_em`, `historico_precos` (`2026-10-11:980000 | 2026-10-25:950000`), `avaliacao_socios`, `observacoes` (estas duas são do Guilherme: lidas de volta da planilha antes de regenerar e preservadas pela `chave`).

## Verificação de disponibilidade — `_dados/<data>/verificacao.csv`
Para cada `chave` da base que **não** apareceu na coleta do dia: `chave;status_site;preco_atual;verificado_em;evidencia`. `status_site`: `ATIVO` (ainda no ar; saiu da busca por mudar de preço/área/filtro), `INATIVO` (site diz suspenso/vendido/inativo), `NAO_ENCONTRADO` (404 / sem resultado), `ERRO` (não deu para verificar; **não** marcar como removido). Fontes: VivaReal `listings?id=<id>` → `status`; QuintoAndar página `/imovel/<id>/comprar` → `status` publicado/suspenso ou 404; Chaves na Mão página do anúncio → `active` ou redirecionamento/404.

## Planilha — `Planilha de Apartamentos Pesquisados/Apartamentos Pesquisados - Ipanema e Leblon.xlsx`
Regenerada a cada rodada a partir de `base.csv` (Excel COM). Abas: `IMÓVEIS` (uma linha por anúncio; linha de `REMOVIDO` em cinza e no fim; novos da rodada em destaque), `RESUMO` (contagens por bairro/fonte/status, novos e removidos da rodada, R$/m² mediano por bairro), `HISTÓRICO` (uma linha por rodada), `CRITÉRIOS` (parâmetros em vigor). Cabeçalho `Data atualização:` preservado. Nomes das colunas do Guilherme preservados (`Nº`, `LOCAL PESQUISA`, `ENDEREÇO DO IMÓVEL`, `BAIRRO`, `PREÇO`, `ÁREA`, `CONDOMÍNIO`, `IPTU`, `VALOR/M²`, `LINK DE ACESSO DIRETO AO IMÓVEL`), as novas entram em volta.
