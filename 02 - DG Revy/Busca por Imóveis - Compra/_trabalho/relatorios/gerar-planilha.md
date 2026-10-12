# Relatório — `Skills\scripts\gerar-planilha.ps1` (11/10/2026)

Componente que transforma `base.csv` na planilha "Apartamentos Pesquisados" (xlsx) via Excel COM, com 4 abas
(IMÓVEIS, RESUMO, HISTÓRICO RODADAS, CRITÉRIOS), preservando o que o Guilherme escreve à mão.

## O que foi feito
- **`Skills\scripts\gerar-planilha.ps1`** (BOM UTF-8, comentários e log em pt-BR).
  `-Base <base.csv> -Saida <xlsx> -Rodada yyyy-MM-dd [-Modelo <xlsx>] [-ResumoRodada <json>] [-Criterios <json>] [-Ruas <csv>] [-Png <pasta>] [-Log <arquivo>]`
  - Lê a base (formato do CONTRATO, seção "Base"), descarta `dentro_area = NAO`, valida as colunas obrigatórias.
  - Se o xlsx já existe: lê de IMÓVEIS as colunas **AVALIAÇÃO (SÓCIOS)** e **OBSERVAÇÕES** casando pela **CHAVE**,
    grava `manuais-backup-<rodada>.csv` ao lado do xlsx e preserva os valores (valor da planilha vence o da base
    quando preenchido). Lê também as linhas anteriores de HISTÓRICO RODADAS.
  - Lê a planilha modelo do Guilherme **só para leitura** (rótulo "Data atualização:" e os 10 nomes de coluna dele;
    o log confirma "Todas as 10 colunas do modelo do Guilherme estão presentes").
  - Aba **IMÓVEIS**: 33 colunas na ordem pedida; linha 2 = rótulo + data da rodada + contagem; linha 3 = legenda de
    cores; cabeçalho na linha 4 (negrito, fundo azul-escuro, texto branco, quebra de linha); dados da linha 5.
    Ordenação ATIVO (bairro, depois R$/m² crescente) → FORA DOS CRITÉRIOS → REMOVIDO (cinza). NOVO em verde,
    LIMITE/A CONFIRMAR em amarelo, preço que caiu em verde-escuro, que subiu em vermelho. `VALOR/M²` e
    `CUSTO MENSAL` são fórmulas; os dois links são `=HYPERLINK(url;"site › código")` clicáveis. Painéis congelados
    abaixo do cabeçalho e à direita de ENDEREÇO, autofiltro, zoom 90, sem grade, R$ `"R$" #.##0`, datas `dd/mm/aaaa`.
    `POSSÍVEL DUPLICATA` mostra "ver nº X" apontando para o outro anúncio do grupo.
  - Aba **RESUMO**: bairro × status, por fonte, movimentos da rodada (novos, removidos, preço caiu/subiu, ativos por
    área), R$/m² mín/mediano/máx por bairro (só ATIVO em área SIM) e os 10 menores R$/m² com link.
  - Aba **HISTÓRICO RODADAS**: uma linha por rodada (data; coletados por fonte; total; novos; removidos; preço
    alterado; total ativo; observação). Linha atual vem de `-ResumoRodada <json>` ou é calculada da base; linhas
    anteriores são preservadas; a da mesma data é substituída.
  - Aba **CRITÉRIOS**: `criterios.json` achatado em tabela (49 parâmetros), polígonos (arquivo, existe?, mapa de
    origem), documentos de origem e os 78 trechos de rua de `ruas.csv`.
  - Escrita por **array 2D em um Range único** por bloco (nunca célula a célula). Excel invisível, `DisplayAlerts`
    off, `SaveAs` FileFormat 51, fechamento e liberação COM; espera a liberação do arquivo (até 20 s) antes de abrir
    e de salvar, com mensagem clara se a planilha estiver aberta em outro programa.
  - `-Png <pasta>`: exporta imagens de conferência (IMÓVEIS em duas metades, RESUMO, HISTÓRICO, CRITÉRIOS).
- **`_trabalho\testes-planilha\gerar-base-teste.ps1`**: base sintética `[TESTE]` determinística (45 linhas; 3 fontes;
  Ipanema/Leblon/Copacabana; ATIVO/REMOVIDO/FORA; SIM/LIMITE/A CONFIRMAR; preco_anterior; 2 grupos de duplicata;
  campos vazios; acentos; aspas no título; links longos). `-Variante 2` simula a rodada seguinte (48 linhas:
  3 novos, 2 removidos a mais, 3 mudanças de preço).
- **`_trabalho\testes-planilha\teste-manuais.ps1`**: `-Modo escrever` preenche 4 chaves via COM como se fosse o
  Guilherme; `-Modo conferir` confere chave a chave depois da regeneração e lista o HISTÓRICO.

## Como testar
```powershell
$t = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\_trabalho\testes-planilha"
$p = "D:\12- Claude - works\02 - DG Revy\Busca por Imóveis - Compra\Skills\scripts\gerar-planilha.ps1"
$x = "$t\saida\Apartamentos Pesquisados - TESTE.xlsx"
powershell -ExecutionPolicy Bypass -File $p -Base "$t\base-teste.csv"    -Saida $x -Rodada 2026-10-11 -Png "$t\png-r1"
powershell -ExecutionPolicy Bypass -File "$t\teste-manuais.ps1" -Modo escrever -Xlsx $x
powershell -ExecutionPolicy Bypass -File $p -Base "$t\base-teste-r2.csv" -Saida $x -Rodada 2026-10-18 -Png "$t\png-r2"
powershell -ExecutionPolicy Bypass -File "$t\teste-manuais.ps1" -Modo conferir -Xlsx $x   # espera "0 falhas"
```
Para a planilha viva: `-Base "_dados\base.csv" -Saida "Planilha de Apartamentos Pesquisados\Apartamentos Pesquisados - Ipanema e Leblon.xlsx" -Rodada <hoje>`.

## Contagens obtidas (teste real, 11/10/2026 12:07)
| | Rodada 1 (2026-10-11) | Rodada 2 (2026-10-18) |
|---|---|---|
| Linhas na base → na planilha | 45 → 45 (0 descartadas NAO) | 48 → 48 |
| ATIVO / NOVOS / FORA / REMOVIDO | 36 / 13 / 4 / 5 | 37 / 3 / 4 / 7 |
| Destaques: LIMITE+A CONFIRMAR / caiu / subiu | 20 / 4 / 2 | 22 / 6 / 3 |
| HISTÓRICO (linhas) | 1 | 2 (11/10 preservada + 18/10) |
| Colunas manuais lidas da planilha anterior | — | 45 chaves, 5 com valor, backup com 5 linhas |
| Conferência das 4 chaves editadas à mão | — | **4/4 OK (0 falhas)**, inclusive a que virou REMOVIDO |
| CRITÉRIOS | 49 parâmetros + 78 trechos de rua | idem |
| Tempo (script, do início ao fim, com 5 PNGs) | 15,4 s (planilha salva aos 9,0 s) | 14,8 s (salva aos 8,5 s) |

Linha do HISTÓRICO calculada da base: `11/10/2026 | 18 | 11 | 11 | 40 | 13 | 2 | 5 | 36` e `18/10/2026 | 18 | 11 | 12 | 41 | 3 | 4 | 8 | 37`.

## Imagens de conferência (olhadas uma a uma)
- `_trabalho\testes-planilha\png-r1\` e `png-r2\`: `imoveis-A-P.png`, `imoveis-Q-AG.png`, `resumo.png`, `historico.png`, `criterios.png`.
- Correções feitas a partir das imagens: larguras de DESTAQUES (38→46), ANUNCIANTE (26→32), CHAVE (22→26),
  OBSERVAÇÕES (34→40); RESUMO coluna A (32→44) e B (15→22, cabia "Copacabana (Arpoador)"); VALOR dos critérios
  em formato Geral para número não virar "texto" com triângulo verde.

## Armadilhas novas desta máquina (além do catálogo da memória)
1. **"Histórico" é nome reservado de aba no Excel pt-BR** (`Histórico é um nome reservado`). A aba chama-se
   `HISTÓRICO RODADAS`; o leitor aceita qualquer aba que comece com "HISTÓRICO".
2. **Função PowerShell que devolve array 2D precisa de `return ,$arr`**; sem a vírgula o array é desenrolado e o
   chamador recebe lista plana (os índices `[i, j]` passam a selecionar 2 elementos e tudo sai vazio, sem erro).
   E o contrário: **`@(função)` embrulha** o array devolvido num elemento só — usar `$x = função` direto.
3. **Valor vindo de pipeline (`Sort-Object`, `Select-Object -Unique`) chega embrulhado em PSObject** e o COM falha
   com `0x800A03EC` sem explicação (`GetType()` não mostra o embrulho). Desembrulhar com `.PSObject.BaseObject`
   antes de pôr no array 2D (helper `Bruto`).
4. **`CopyPicture` com `ScreenUpdating = $false` gera PNG em branco (2,7 KB) e não dá erro.** Ligar
   `ScreenUpdating` antes de exportar; mesmo assim a 5ª exportação seguida saiu em branco uma vez — agora há pausa de
   0,3 s e até 3 tentativas (aceita só PNG > 10 KB).
5. **Arquivo recém-gravado fica travado por alguns segundos** (Excel anterior fechando / antivírus). Abrir ou salvar
   logo em seguida falha com "Não é possível acessar" e, se o script morre no meio, a instância invisível do Excel
   fica órfã segurando o arquivo. Os scripts agora esperam a liberação (até 20 s) e o SaveAs tenta 3 vezes.

## Premissas adotadas (sem confirmar com o Guilherme)
- Colunas começam em **A** (no modelo começam em B); rótulo "Data atualização:" em A2 e a data em D2.
- **BAIRRO** mostra o bairro como o site informa, normalizado: Ipanema, Leblon e "Copacabana (Arpoador)"; a decisão
  de área fica na coluna ÁREA DE INTERESSE.
- **STATUS** mostra "NOVO" (no lugar de ATIVO) quando `primeira_captura = rodada`.
- **Links** aparecem como texto curto clicável "site › código" (ex.: `vivareal.com.br › 2915533435`), não a URL
  inteira (URLs de 150 caracteres estouravam a coluna).
- **FORA DOS CRITÉRIOS** ganhou um destaque próprio (laranja-claro na coluna STATUS, fonte cinza-escura) — o pedido
  só especificava cores para NOVO, LIMITE/A CONFIRMAR, REMOVIDO e preço.
- Destaques por linha (NOVO, LIMITE, preço) são formatação estática célula a célula, não formatação condicional
  (poucas centenas de células; a condicional via COM depende da célula ativa, que não existe com Excel invisível).
- Valor manual: o da **planilha vence** o da base quando preenchido; vazio na planilha mantém o da base.
  O script **não grava de volta em base.csv** — deixa o `manuais-backup-<rodada>.csv` para o consolidador fazer isso.
- "Coletados por fonte" no HISTÓRICO (quando calculado da base) = anúncios com `ultima_verificacao = rodada` e
  status ≠ REMOVIDO; "removidos" = `removido_em = rodada`; "preço alterado" = `preco_alterado_em = rodada`.
- 10 menores R$/m² consideram todo ATIVO (SIM, LIMITE e A CONFIRMAR), mostrando a coluna de área de interesse;
  as estatísticas por bairro usam só ATIVO em área SIM, como pedido.
- Formato do JSON `-ResumoRodada`: `{"coletados":{"VIVAREAL":n,"QUINTOANDAR":n,"CHAVESNAMAO":n},"novos":n,"removidos":n,"preco_alterado":n,"total_ativo":n,"observacao":"..."}` (chaves ausentes caem no cálculo da base).

## Pendências
- Testado só com base sintética (45–48 linhas). Com algumas centenas de linhas o tempo deve subir pouco (a escrita é
  por array; o que cresce é o laço de destaques, 1 chamada COM por célula destacada).
- O log fica ao lado do xlsx (`gerar-planilha.log`); o orquestrador pode passar `-Log "_dados\<data>\gerar-planilha.log"`.
- Não fiz commit (componente de um workflow com outros em andamento; fica para o orquestrador).
- Arquivo de lock `~$...xlsx` órfão de um Excel morto não é removido pelo script (o Excel ignora quando o dono já não existe).
