# Como instalar as skills da EP no Cowork

Gerado em 30/08/2026, a partir dos arquivos da pasta acima.

## O que tem aqui

Cada skill vem em **dois formatos** — use o que a interface do Cowork aceitar:

| Formato | Quando usar |
|---|---|
| `nome.skill` | Se existir opção de **importar/enviar arquivo** de skill |
| `nome.md` | Se a instalação for **colando o texto** num campo |

O conteúdo é idêntico nos dois. O `.skill` é um ZIP com `nome/SKILL.md` dentro — mesmo
formato dos pacotes que você exportou do Cowork (conferido contra o
`supervisor-lancamento-dg.skill`).

**O changelog foi removido destes arquivos de propósito.** Ele é histórico nosso, não
instrução — pesaria em toda execução da skill sem ajudar em nada. O changelog completo
continua nos arquivos da pasta acima, que são a fonte da verdade.

## Ordem de instalação

A ordem importa: o Supervisor referencia os outros pelo nome, então ele vai por último.

| # | Skill | Tipo | O que faz |
|---|---|---|---|
| 1 | `agente-chequer-classificacao` | agente | Confere se obra/fornecedor/quem gastou batem com a mensagem |
| 2 | `agente-chequer-leitura` | agente | Confere se alguma mensagem ficou de fora |
| 3 | `ep-leitor-notas` | skill | Etapa 1 — colhe, inventaria e lê as notas |
| 4 | `ep-lancador-notas` | skill | Etapa 2 — escreve na aba LANÇAMENTO |
| 5 | `ep-pintor-notas` | skill | Etapa 3 — pinta, confere e devolve a planilha |
| 6 | `supervisor-lancamento-ep` | skill | Orquestra tudo — **por último** |

Os dois primeiros são **agentes**, não skills. Se a interface separar as duas coisas,
crie-os na seção de agentes. Se não separar, crie como skill mesmo — o conteúdo
funciona igual; o que muda é o modo de invocação (o Supervisor chama os chequers via
ferramenta de agente/Task).

## Como saber se deu certo — teste sem lançar nada

Depois de instalar, peça no Cowork:

> Supervisor de lançamento EP, vamos começar

Você deve ver, **antes de qualquer coisa acontecer**, a linha de anúncio da Etapa 1:

```
▶ ep-leitor-notas — Etapa 1 iniciada
```

Se essa linha não aparecer, o Supervisor não está invocando a skill certa — pare e me
traga o que apareceu.

## O que observar durante o lançamento real

1. **As linhas `▶`** — uma por etapa. Faltou alguma? A etapa foi pulada.
2. **A prestação de contas**, no fechamento: lista etapa por etapa `invocada / NÃO invocada`.
3. **A lista de dúvidas** — agora mostra quais itens foram resolvidos por *inferência*
   (final do cartão ou regra do remetente). São os que mais erram. Um reply seu naquela
   nota resolve de vez.

## Se o Lançador recusar escrever

Se aparecer algo como *"Não recebi o Certificado de Verificação"*, **isso é a trava
funcionando**, não um bug: significa que algum chequer não rodou ou não aprovou. O que
fazer é voltar e rodar a etapa que faltou — não contornar.

## Se algo der errado

Traga de volta pra pasta de origem (não conserte no Cowork): qual etapa estava rodando, o
que você esperava, o que aconteceu. Eu corrijo o arquivo lá e gero um pacote novo aqui.
