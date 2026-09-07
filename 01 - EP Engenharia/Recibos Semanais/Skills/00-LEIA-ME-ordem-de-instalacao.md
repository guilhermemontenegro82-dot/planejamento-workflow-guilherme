# Recibos Semanais EP — ordem de instalação no Cowork

Pipeline de 2 skills + 1 agente chequer. Construído em 06/09/2026 a partir dos
artefatos reais da obra `848 - MS - Quarto Francisco - Leblon`.

## Ordem

| # | Arquivo | Nome da skill no Cowork |
|---|---------|--------------------------|
| 1 | `skill-1-colheita-fluxo-de-caixa.md` | `recibos-ep-colheita-fluxo-de-caixa` |
| 2 | `skill-2-emissao-recibos.md`         | `recibos-ep-emissao` |
| 3 | `agente-chequer-recibos.md`          | `chequer-recibos-ep` |

Instalar nesta ordem. A Skill 2 depende do dossiê da Skill 1; o chequer roda entre a
Skill 2 e o gate do Guilherme.

## Como o pipeline roda

```
"gerar os recibos da semana"
        │
        ▼
  Skill 1 — Colheita            varre TODAS as obras, lê FLUXO DE CAIXA,
  (leitura pura)                colhe as linhas "ok" a partir da data
        │                       de corte → dossiê
        │
        ├──> emite CERTIFICADO DE COLHEITA (selo mecânico)
        │    e invoca a Etapa 2 obrigatoriamente
        ▼
  Skill 2 — Emissão             🔒 recusa rodar sem o selo da colheita
                                clona o último recibo de cada obra,
        │                       troca valor/extenso/data/referência/forma
        │                       SÓ itens NOVO. Já existe → não toca.
        │
        ├──> invoca o Chequer obrigatoriamente
        ▼
  Chequer                       🔒 recusa conferir sem o selo da colheita
        │                       docx × dossiê × planilha × modelo
        │                       + prova que nada preexistente mudou
        ├──> emite CERTIFICADO DE CONFERÊNCIA
        ▼
  ┌─ TABELA DE CONFERÊNCIA ─┐   ← Guilherme revisa. Silêncio ≠ aprovação.
  └─────────┬───────────────┘
            ▼
  Skill 2 (continuação)         🔒 sem certificado do chequer, nenhum PDF sai
                                gera os PDFs
```

## Como as 3 skills ficam amarradas

Cada etapa emite um **certificado com selo mecânico** e a seguinte **se recusa a rodar
sem ele**:

| Trava | Efeito |
|---|---|
| Skill 2 sem Certificado de Colheita | Para, avisa e invoca a Skill 1 |
| Selo recalculado não bate com o recebido | Para — o dossiê foi editado ou é de outra rodada |
| Chequer sem Certificado de Colheita | Não confere e não certifica |
| Skill 2 sem Certificado de Conferência | Não apresenta tabela como pronta, não gera PDF |
| Qualquer bloco do chequer em FAIL | Laudo de Reprovação — nunca certificado "com ressalvas" |

A ida também é obrigatória: a Skill 1 termina **invocando** a Skill 2 (não pergunta se
deve), e a Skill 2 **invoca** o chequer antes da tabela.

**Por que travas em vez de um agente orquestrador:** um orquestrador é mais uma coisa
que pode "decidir" não invocar alguém. Uma trava dentro da skill de baixo não tem essa
margem — ela não roda, ponto. E o pipeline fecha com uma **prestação de contas** que
lista as três etapas como `invocada` / `NÃO invocada`, para não depender de ninguém
lembrar de conferir.

## Por que 2 skills e não 1

Os erros que mais doeram no histórico da EP foram de **cobertura de leitura** — nota
ignorada, linha pulada, obra que sumiu da varredura — e não de formatação do documento.
Misturar a leitura das planilhas com a montagem do Word esconde esses erros no meio do
trabalho de XML, exatamente como aconteceu no pipeline de Lançamento de Notas antes do
desmembramento.

Separadas, a colheita produz um artefato conferível (o dossiê) que o Guilherme e o
chequer conseguem ler antes de qualquer documento existir.

Não há orquestrador: com duas etapas em sequência linear e um gate humano no meio, um
agente orquestrador só somaria uma camada sem decisão nenhuma para tomar.

## Regras invioláveis (06/09/2026)

Estão escritas no topo das duas skills e são verificadas pelo Bloco D do chequer:

1. **Nunca alterar, modificar, sobrescrever ou apagar recibo que já existe.** Os
   recibos nas pastas foram feitos pelo Guilherme, à mão. O pipeline **só cria arquivo
   novo**.
2. **Nunca alterar as planilhas de Controle Financeiro.** Leitura apenas.
3. **Só emitir recibo de valor apurado a partir da data de corte** — desta semana em
   diante. Lançamento antigo já tem o recibo dele.
4. **Preservar marca d'água, logo, rodapé e as assinaturas** do Guilherme e do Renato,
   herdados do recibo anterior da obra. A skill clona o `.docx` e edita só o
   `word/document.xml` — nunca reconstrói o arquivo, porque a marca d'água (uma VML no
   cabeçalho) some sem aviso nesse caminho.
5. **Todo recibo é redigido como pagamento já efetuado**, independente da cor. A palavra
   "previsto" nunca aparece — nem no texto, nem no nome do arquivo.

## Decisões do Guilherme registradas nas skills (06/09/2026)

| Tema | Decisão |
|---|---|
| Gatilho | Toda linha com `ok` = valor apurado (medição, aporte, aditivo ou desconto) |
| Data de corte | Só linhas desta semana em diante; a data é perguntada na 1ª execução |
| Cor | Verde = já pagou · Laranja = ainda não pagou. **Só afeta a tabela final**, nunca o documento |
| Fluxo real | Quinta/sexta ele lança tudo laranja (nada recebido). A skill deixa **todos os recibos prontos, redigidos como pagos**. Conforme cada cliente paga, ele pinta de verde e envia o recibo que já estava feito |
| Tabela final | `pode enviar` (verde) × `aguardando pgto` (laranja) — lembrete do trabalho dele na semana |
| Gate | `.docx` sai antes; tabela de conferência; PDF só depois do ok |
| Forma de pgto | PIX/TED/DOC → `transferência bancária` · Dinheiro/Espécie → `pagamento em espécie` |
| Referência | `M0x` → `Medição 0x` · resto literal |
| Arquivo existente | **Nunca tocar.** Se a linha divergir do recibo já emitido, a skill relata e para |
| PDF | Mesmo nome-base do `.docx`, mesma pasta, extensão `.pdf` |
| Cliente | Sempre o do recibo anterior da obra, salvo aviso em contrário |

## Pontos abertos

1. **"Pagamento em espécie" na frase.** O Guilherme escreveu a forma como
   "Pagamento em espécie". Encaixada na frase do recibo virou
   `através de pagamento em espécie`, para não quebrar a gramática. Se ele preferir
   outra construção, trocar na Skill 2, seção 2.4 — não improvisar caso a caso.
2. **Cor laranja.** Nenhum arquivo lido tinha célula laranja (a obra 848 só tem verde
   `FF00B050`). A classificação é por faixa de matiz, não por código exato, então deve
   funcionar — mas vale confirmar na primeira rodada real que uma linha prevista foi
   classificada como LARANJA (e apareça como `aguardando pgto` na tabela).
3. **Tratamento do cliente.** O modelo diz "do Sr.". Para cliente mulher, casal ou
   empresa, a Skill 2 herda o tratamento do recibo anterior da obra; em obra sem recibo
   anterior, ela para e pergunta.
4. **Ferramenta de PDF.** Não confirmada no ambiente do Cowork. A Skill 2 tenta
   LibreOffice → Word → conversor do ambiente, e degrada para "só `.docx` + aviso" se
   nenhuma existir.

## Fonte da verdade

Estes `.md` são a fonte da verdade. **Nunca editar direto no Cowork** — se algo quebrar
lá, o erro volta para cá, é corrigido aqui e recolado. Ver `CLAUDE.md` em
`Planejamento WorkFlow Guilherme\`.

## Material de referência usado na construção

Em `01 - EP Engenharia\Recibos Semanais\`:

- `Modelos\` e `Recibos gerados\` — os dois recibos reais da obra 848 (`.docx` + `.pdf`)
- `Planilhas (origem)\Controle Financeiro\` — a planilha real da obra 848
- `_trabalho\` — dumps de XML da análise (descartável)

Amostras para entender o padrão. A skill roda direto nas pastas de cada obra em
`EP - Obras em Andamento`.
