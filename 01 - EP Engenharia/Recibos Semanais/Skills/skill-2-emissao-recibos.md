---
name: recibos-ep-emissao
description: "Segunda etapa do pipeline de Recibos Semanais da EP Engenharia: a partir do dossiê da Skill 1, gera os recibos em .docx clonando o último recibo de cada obra e trocando valor, valor por extenso, data, referência e forma de pagamento. Grava na pasta 'Recibos' da própria obra, apresenta a tabela de conferência ao Guilherme e só depois do ok dele sobrescreve arquivos existentes e converte para PDF. Acionada logo após a Skill 1 — Colheita do Fluxo de Caixa."
---

# Skill 2 — Emissão dos Recibos

Recebe o dossiê da Skill 1 e produz os documentos. **Não relê a planilha** — se algum
dado parecer estranho, volta para a Skill 1; nunca "confere direto na planilha" por
fora, porque aí passam a existir duas leituras concorrentes sem ninguém saber qual
valeu.

## REGRAS INVIOLÁVEIS

Definidas pelo Guilherme em 06/09/2026. Valem acima de qualquer outra instrução deste
arquivo.

1. **Nunca alterar, modificar, sobrescrever ou apagar um recibo que já existe.** Os
   recibos nas pastas foram feitos por ele, à mão. Esta skill **só cria arquivo novo**.
   Se o arquivo de destino já existe, **não grava** — reporta e segue.
2. **Nunca alterar as planilhas de Controle Financeiro.** Esta skill nem chega a
   abri-las: trabalha só sobre o dossiê da Skill 1.
3. **Só emitir recibo de valor apurado a partir da data de corte.** Quem filtra é a
   Skill 1; se um item anterior ao corte aparecer no dossiê, não emitir.
4. **Preservar timbre, rodapé, contatos e as assinaturas do Guilherme e do Renato**,
   exatamente como vêm do recibo anterior da obra.

Se alguma etapa deste arquivo parecer pedir o contrário, **estas regras vencem**.

## Anúncio obrigatório

**Antes de qualquer outra coisa**, imprimir na conversa, exatamente:

```
▶ recibos-ep-emissao — Etapa 2 iniciada
```

E, ao chamar o chequer:

```
▶ chequer-recibos-ep — conferência iniciada
```

Sinal mecânico de que cada etapa rodou de verdade. Se a linha do chequer não aparecer,
a tabela de conferência não foi verificada — e não deve ser tratada como confiável.

## Princípio central: o modelo é o recibo anterior da própria obra

Não existe um modelo genérico de recibo. Para cada obra, o modelo é **o último `.docx`
da pasta `Recibos` daquela obra**. Ele já traz o nome certo do cliente, o endereço, a
descrição do serviço, o timbre, o rodapé com os contatos e as assinaturas digitalizadas
do Guilherme e do Renato.

Consequência prática: **só 5 coisas mudam de um recibo para o seguinte.** Todo o resto
é clonado byte a byte. Isso elimina a classe inteira de erro "herdou dado do cliente
anterior" — aqui herdar o dado do documento anterior *é* o comportamento correto, desde
que seja o documento anterior **da mesma obra**.

Se o dossiê marcou a obra como `SEM MODELO` (nenhum recibo anterior): **parar e
perguntar** ao Guilherme o nome do cliente, o tratamento (`do Sr.` / `da Sra.` /
`da empresa`), a descrição do serviço e o endereço. Nunca montar do zero por conta
própria.

## Passo 1 — Preparar

Processar **somente** os itens marcados `NOVO` no dossiê. Itens `JÁ EMITIDO`,
`DIVERGENTE — SÓ REPORTAR` e `ANTERIOR AO CORTE` não geram documento nenhum e não são
abertos para escrita em momento algum.

1. Copiar o recibo-modelo da obra para a área de trabalho da sessão.
2. Descompactar o `.docx` (é um ZIP). Mexer **apenas** em `word/document.xml`.
   `word/header*.xml`, `word/footer1.xml`, `word/media/*` e todo o resto vão intactos.

## Passo 2 — Calcular os 5 campos

### 2.1 Valor formatado
`8177.52` → `8.177,52` (ponto no milhar, vírgula no decimal, sempre 2 casas).

### 2.2 Valor por extenso
Ver a seção **"Valor por extenso"** no fim deste arquivo. Formato conferido contra os
recibos reais da obra 848:

- `8177.52` → `oito mil, cento e setenta e sete reais e cinquenta e dois centavos`
- `12532.91` → `doze mil, quinhentos e trinta e dois reais e noventa e um centavos`

### 2.3 Data
`DD/MM/AAAA` no corpo (`04/09/2026`) e por extenso no fecho
(`Rio de Janeiro, 04 de setembro de 2026.`). **As duas datas são a mesma** — a data do
pagamento da planilha, não a data de hoje. Nos dois recibos reais da obra 848 elas
coincidem.

Meses em minúscula: janeiro, fevereiro, março, abril, maio, junho, julho, agosto,
setembro, outubro, novembro, dezembro. Dia com zero à esquerda (`04`).

A cidade do fecho vem do recibo-modelo da obra — **não** assumir "Rio de Janeiro" para
uma obra nova sem conferir.

### 2.4 Forma de pagamento
Tradução definida pelo Guilherme em 06/09/2026:

| Na planilha (normalizado)             | No recibo                  |
|---------------------------------------|----------------------------|
| `PIX`, `TED`, `DOC`                   | `transferência bancária`   |
| `Em dinheiro`, `Dinheiro`, `Espécie`  | `pagamento em espécie`     |

A frase montada fica: `, através de {FORMA}, referentes à `
→ `, através de transferência bancária, referentes à `
→ `, através de pagamento em espécie, referentes à `

> **Ponto aberto, sinalizado ao Guilherme.** Ele escreveu a forma em espécie como
> "Pagamento em espécie" (com maiúscula, como frase solta). Encaixada na frase do
> recibo, virou `através de pagamento em espécie` para não quebrar a gramática do
> parágrafo. Se ele preferir outra construção (ex.: `, em espécie, referentes à`),
> **é só trocar aqui** — não improvisar caso a caso.

Forma de pagamento que não esteja na tabela → **parar e perguntar**. Não traduzir por
semelhança.

### 2.5 Referência
Regra definida pelo Guilherme em 06/09/2026:

- `M` seguido de número (`M01`, `M02`, `M10`) → `Medição 01`, `Medição 02`, `Medição 10`
  (preservando os dois dígitos)
- Qualquer outro texto (`Sinal`, `Aporte`, `Aditivo`…) → **literal**, exatamente como
  está escrito na planilha

Código que não case com `M\d+` e que também não seja um texto legível → parar e
perguntar.

## Passo 3 — Reescrever o parágrafo do corpo

O parágrafo do recibo está fragmentado em ~21 `<w:r>` no modelo, porque o Word quebra
runs conforme o histórico de edição: `Milton`, ` Salgado`, ` Rangel `, `Neto` estão em
runs separados. **Não tentar regex sobre o texto** — ele não existe contíguo em lugar
nenhum do XML.

A abordagem correta é **reconstruir a lista de runs do parágrafo inteira**, preservando
o `<w:pPr>` original e as propriedades de run do modelo.

### Extrair do modelo, antes de reescrever

Localizar o parágrafo cujo texto concatenado começa com `Declaro para devidos fins`.
Dele, extrair três coisas:

1. **`<w:pPr>` completo** — copiar literalmente.
2. **Bloco do cliente** — o texto concatenado entre `que recebemos ` e `, o valor de `
   (ex.: `do Sr. Milton Salgado Rangel Neto`).
3. **Cauda** — todo o texto dos runs que vêm **depois** do run sublinhado, incluindo o
   ponto final (ex.: `, para serviços de reforma e criação do quarto do Francisco, na
   Rua João de Barros, 22, apartamento 601 – Leblon – Rio de Janeiro.`).

> **O sublinhado é o marcador estrutural.** A referência (`Medição 01`) é o único run
> do parágrafo com `<w:u w:val="single"/>`. Isso permite achar o fim da parte variável
> sem depender de pontuação ou de contar vírgulas — que quebraria se o endereço
> contivesse uma vírgula, como de fato contém.

Se o parágrafo não tiver exatamente um run sublinhado, **parar e avisar**: o modelo
daquela obra tem formatação diferente da esperada e precisa de conferência humana.

### Propriedades de run

Três variantes, extraídas do modelo real:

- **Normal** — a `rPr` do primeiro run do parágrafo.
- **Negrito** — a mesma, com `<w:b/>` acrescentado. Usada em `R$ ` e no valor.
- **Sublinhado** — a mesma, com `<w:u w:val="single"/>`. Usada na referência.

Descartar os `<w:lang w:val="ia-Latn-001"/>` que aparecem em alguns runs do modelo:
são resíduo da detecção automática de idioma do Word e não afetam a aparência.

### Os 5 runs novos

Substituir todos os runs do parágrafo por exatamente estes cinco:

| # | Formatação | Texto |
|---|------------|-------|
| 1 | normal     | `Declaro para devidos fins, que recebemos {CLIENTE}, o valor de ` |
| 2 | **negrito**| `R$ {VALOR}` |
| 3 | normal     | ` ({EXTENSO}) pagos no dia {DATA}, através de {FORMA}, referentes à ` |
| 4 | _sublinhado_ | `{REFERENCIA}` |
| 5 | normal     | `{CAUDA}` |

Onde `{CLIENTE}` e `{CAUDA}` vêm do modelo sem nenhuma alteração.

Todo run com espaço no início ou no fim precisa de `xml:space="preserve"` no `<w:t>`.
Os runs 1, 3 e 5 sempre precisam. Esquecer isso cola as palavras
("...o valor deR$ 8.177,52").

Escapar `&`, `<` e `>` no texto antes de inserir no XML.

Gabarito de um run (o `{RPR}` é a variante da tabela acima):

```xml
<w:r><w:rPr>{RPR}</w:rPr><w:t xml:space="preserve">{TEXTO}</w:t></w:r>
```

### Armadilha de regex herdada da Skill 6 de Orçamentos

Se for usar regex em qualquer ponto do XML: `<w:t[^>]*>` **também casa com `<w:tc>`**
(célula de tabela), porque as duas começam com `<w:t`. Usar sempre
`<w:t(?:\s[^>]*)?>`, que exige espaço ou fechamento logo depois do `t`. Esse bug já
destruiu silenciosamente a estrutura de um documento neste mesmo repositório.

Se gerar `w14:paraId` novo: o valor hexadecimal precisa ficar **abaixo de
`0x80000000`** (`random.randint(0, 0x7FFFFFFF)`), senão o Word rejeita o arquivo. Neste
caso o mais seguro é **não gerar** — reaproveitar o `paraId` do parágrafo original, já
que ele está sendo reescrito e não duplicado.

## Passo 4 — Reescrever o parágrafo da data

Mesmo método. Localizar o parágrafo centralizado (`<w:jc w:val="center"/>`) cujo texto
comece com o nome da cidade seguido de vírgula. Ele também está fragmentado
(`Rio de Janeiro, ` / `04` / ` de ` / `setembro` / ` de 202` / `6` / `.` — repare que
até o ano está partido).

Substituir todos os runs dele por **um único run normal**:

```
{CIDADE}, {DD} de {mês por extenso} de {AAAA}.
```

## Passo 5 — Remontar e nomear

Recompactar o `.docx`. Conferir que o pacote final tem **o mesmo número de arquivos**
que o modelo (27 no recibo da obra 848) — se perdeu arquivo, perdeu o timbre, o rodapé
ou as assinaturas.

Nome do arquivo: o padrão do recibo anterior da obra, com o token da referência
trocado. `MS - Recibo - M01 - Obra Quarto Francisco- Leblon.docx` com referência `M02`
vira `MS - Recibo - M02 - Obra Quarto Francisco- Leblon.docx`. **Preservar o resto
literalmente**, inclusive o espaçamento irregular do original.

## Passo 6 — Gravar

**Checagem obrigatória imediatamente antes de cada gravação**, mesmo que o dossiê já
tenha dito que o item é `NOVO`: verificar de novo, no disco, se o arquivo de destino
existe.

- **Não existe** → gravar.
- **Existe** → **não gravar.** Reportar como `EXISTENTE — NÃO TOCADO` e seguir.

A recheca é deliberadamente redundante com o Passo 8 da Skill 1. Entre a colheita e a
gravação o Guilherme pode ter criado o recibo à mão, e o dossiê estaria desatualizado.
Sobrescrever um recibo dele é o único erro deste pipeline que destrói trabalho — vale
uma checagem barata a mais.

Checar também se existe `~$<nome>.docx` na pasta `Recibos` (documento aberto no Word).
Se existir, não gravar: avisar e deixar o item pendente.

A pasta `Recibos` é sincronizada com o OneDrive e às vezes bloqueia substituição. Se a
gravação falhar, **não forçar** — reportar o item como falho, com o erro.

## Passo 7 — Tabela de conferência (o gate do Guilherme)

Apresentar na conversa, agrupado por obra:

```
848 - MS - Quarto Francisco - Leblon
  M02  R$  9.430,00  11/09/2026  transf. bancária      PREVISTO  ✓ gravado

851 - AB - Cobertura Ipanema
  Sinal R$ 24.000,00 09/09/2026  pagamento em espécie  PAGO      ✓ gravado

Não emitidos (nenhum arquivo foi tocado):
  848/M01   — recibo já existe e a data da planilha mudou (04/09 → 15/09).
              Nada foi alterado. Se quiser o recibo revisado, me avise.
  853/Sinal — SEM MODELO: obra sem recibo anterior. Preciso do nome do cliente,
              tratamento, descrição do serviço e endereço.

Total emitido: 2 recibos, R$ 33.430,00
```

A seção **"Não emitidos"** é obrigatória mesmo quando vazia — é ela que dá ao Guilherme
a certeza de que nada foi tocado sem ele saber.

Antes de mostrar a tabela, rodar o **Agente Chequer — Recibos** sobre os `.docx`
gerados. A tabela só vai ao Guilherme depois que o chequer passar, ou com as falhas do
chequer explicitamente listadas nela.

Depois disso, **parar e esperar**. Silêncio não é aprovação.

## Passo 8 — Depois do ok

1. Converter os recibos aprovados para PDF, com o processo que o Guilherme
   usa: *salvar como → manter o nome do arquivo exatamente igual ao `.docx` → escolher
   a extensão `.pdf`*. Ou seja: mesmo nome-base, mesma pasta `Recibos`, só muda a
   extensão.

   `MS - Recibo - M02 - Obra Quarto Francisco- Leblon.docx`
   → `MS - Recibo - M02 - Obra Quarto Francisco- Leblon.pdf`

   Ferramenta, na ordem de preferência do que estiver disponível no ambiente:
   `soffice --headless --convert-to pdf`, ou o Word via automação
   (`Documents.Open` → `ExportAsFixedFormat`, `wdExportFormatPDF`), ou o conversor de
   PDF do próprio ambiente.

   **Se nenhuma estiver disponível, não travar a entrega**: entregar os `.docx` e
   avisar explicitamente que o PDF precisa ser exportado à mão. Nunca entregar em
   silêncio sem o PDF que ele pediu.

   Vale aqui a mesma regra do `.docx`: **se o `.pdf` de destino já existe, não
   sobrescrever.** Reportar e seguir.

2. Confirmar, arquivo por arquivo, que `.docx` e `.pdf` existem na pasta `Recibos` de
   cada obra.

## Autoverificação — rodar antes de mostrar a tabela

- [ ] Todo item `NOVO` do dossiê virou um `.docx`, ou está listado em "Não emitidos"
      com motivo.
- [ ] **Nenhum arquivo pré-existente foi alterado, sobrescrito ou apagado.** Conferir
      pela data de modificação dos recibos que já estavam na pasta antes da rodada:
      todas têm que estar inalteradas.
- [ ] Nenhum item `JÁ EMITIDO`, `DIVERGENTE` ou `ANTERIOR AO CORTE` gerou arquivo.
- [ ] Todo item colhido com data anterior à data de corte ficou de fora da emissão.
- [ ] Cada `.docx` gerado tem o mesmo nº de arquivos internos que o modelo da obra.
- [ ] O texto extraído de cada `.docx` contém o valor formatado, a data, a referência
      expandida e a forma de pagamento traduzida — conferido por extração de texto, não
      por leitura visual.
- [ ] O nome do cliente em cada recibo é **idêntico** ao do recibo anterior da mesma
      obra (comparação literal de string).
- [ ] A cauda (serviço + endereço) é idêntica à do recibo anterior da mesma obra.
- [ ] Nenhum recibo saiu com nome de cliente ou endereço de **outra obra**.
- [ ] A data do corpo e a data do fecho são a mesma.
- [ ] Nenhum arquivo foi criado fora da pasta `Recibos` das obras.

---

# Valor por extenso

Implementação de referência. Conferida contra os dois recibos reais da obra 848.

```python
from decimal import Decimal, ROUND_HALF_UP

UNI = ['', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove']
DEZ = ['dez', 'onze', 'doze', 'treze', 'catorze', 'quinze', 'dezesseis',
       'dezessete', 'dezoito', 'dezenove']
DEZENAS = ['', '', 'vinte', 'trinta', 'quarenta', 'cinquenta', 'sessenta',
           'setenta', 'oitenta', 'noventa']
CENTENAS = ['', 'cento', 'duzentos', 'trezentos', 'quatrocentos', 'quinhentos',
            'seiscentos', 'setecentos', 'oitocentos', 'novecentos']


def _ate_999(n):
    if n == 0:
        return ''
    if n == 100:
        return 'cem'
    partes = []
    c, r = divmod(n, 100)
    if c:
        partes.append(CENTENAS[c])
    if r < 10:
        if r:
            partes.append(UNI[r])
    elif r < 20:
        partes.append(DEZ[r - 10])
    else:
        d, u = divmod(r, 10)
        partes.append(DEZENAS[d] + (' e ' + UNI[u] if u else ''))
    return ' e '.join(partes)


def _inteiro_extenso(n):
    if n == 0:
        return 'zero'
    grupos, resto = [], n          # cada item: (texto, valor daquele grupo)
    for base, sing, plur in ((10**9, 'bilhão', 'bilhões'),
                             (10**6, 'milhão', 'milhões'),
                             (1000, None, None)):
        q, resto = divmod(resto, base)
        if not q:
            continue
        if base == 1000:
            grupos.append(('mil' if q == 1 else _ate_999(q) + ' mil', q))
        else:
            grupos.append((_ate_999(q) + ' ' + (sing if q == 1 else plur), q))
    if resto:
        grupos.append((_ate_999(resto), resto))
    if len(grupos) == 1:
        return grupos[0][0]
    # Regra do português: liga o ÚLTIMO grupo com " e " quando o valor desse grupo
    # é menor que 100 ou é centena redonda; caso contrário, separa com vírgula.
    # O critério é o valor do próprio grupo — usar "n % 1000" erra na faixa do
    # milhão ("um milhão, duzentos mil" em vez de "um milhão e duzentos mil").
    ultimo = grupos[-1][1]
    lig = ' e ' if (ultimo < 100 or ultimo % 100 == 0) else ', '
    return ', '.join(t for t, _ in grupos[:-1]) + lig + grupos[-1][0]


def valor_por_extenso(valor):
    """Recebe um número; devolve o extenso em reais."""
    v = Decimal(str(valor)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    inteiro, centavos = int(v), int((v - int(v)) * 100)
    # "dois milhões DE reais", mas "um milhão e duzentos mil reais":
    # o "de" só entra quando o valor é milhão/bilhão exato, sem grupos abaixo.
    reais = 'real' if inteiro == 1 else 'reais'
    if inteiro >= 10**6 and inteiro % 10**6 == 0:
        reais = 'de reais'
    if inteiro and centavos:
        return (f"{_inteiro_extenso(inteiro)} {reais} e "
                f"{_inteiro_extenso(centavos)} "
                f"{'centavo' if centavos == 1 else 'centavos'}")
    if inteiro:
        return f"{_inteiro_extenso(inteiro)} {reais}"
    return (f"{_inteiro_extenso(centavos)} "
            f"{'centavo' if centavos == 1 else 'centavos'}")
```

## Casos de teste — rodar antes de confiar na função

| Entrada             | Saída esperada |
|---------------------|----------------|
| `8177.5170749999997`| `oito mil, cento e setenta e sete reais e cinquenta e dois centavos` |
| `12532.91`          | `doze mil, quinhentos e trinta e dois reais e noventa e um centavos` |
| `1200.00`           | `mil e duzentos reais` |
| `1050.00`           | `mil e cinquenta reais` |
| `100.00`            | `cem reais` |
| `1.00`              | `um real` |
| `0.01`              | `um centavo` |
| `2000.00`           | `dois mil reais` |
| `15000.00`          | `quinze mil reais` |
| `101101.10`         | `cento e um mil, cento e um reais e dez centavos` |
| `1200000.00`        | `um milhão e duzentos mil reais` |
| `1000500.00`        | `um milhão e quinhentos reais` |
| `2000000.00`        | `dois milhões de reais` |

As duas primeiras linhas são os valores reais dos recibos da obra 848 — se elas não
baterem exatamente, a função está errada e o recibo sairia com o extenso divergente do
número, que é o defeito mais grave possível num recibo.

As três últimas cobrem as duas regras que uma implementação ingênua erra: a ligação
` e ` na faixa do milhão, e o `de reais` em milhão/bilhão exato.

**Estes 13 casos foram executados e passaram em 06/09/2026** — numa transcrição do
algoritmo para PowerShell (`_trabalho\testar-extenso.ps1`), porque a máquina do
Guilherme não tem Python instalado. Isso valida a **lógica**, não o código Python
acima. Ao instalar no Cowork, rodar a tabela contra a função Python de verdade antes de
emitir o primeiro recibo.

## Log de mudanças

- **06/09/2026** — Versão inicial. Gabarito do XML extraído de
  `MS - Recibo - M01 - Obra Quarto Francisco- Leblon.docx`; extenso conferido contra os
  dois recibos reais da obra 848.
