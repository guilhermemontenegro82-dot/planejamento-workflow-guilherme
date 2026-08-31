# Skills — Lançamento de Notas DG Revy

Backup local e **fonte da verdade** das skills do fluxo de lançamento de notas do DG
Revy. Trazidas do Claude Cowork em 30/08/2026.

## Como trabalhar com esta pasta

1. **Alterar/melhorar** → o Claude edita o arquivo `.md` aqui.
2. **Levar para o Cowork** → o Guilherme copia o texto do `.md` e atualiza a skill lá.
3. **Nunca editar direto no Cowork** — senão a cópia daqui envelhece e vira armadilha:
   uma sessão futura lê esta versão achando que é a atual e trabalha em cima de algo
   velho. Se por algum motivo editar lá, traga o texto de volta para cá na mesma hora.
4. Cada alteração é commitada e enviada ao Git automaticamente.

## Inventário — pipeline modular (piloto), 6 etapas + fechamento

| Arquivo | Papel no pipeline |
|---|---|
| `supervisor-lancamento-dg.md` | Orquestra as 6 etapas + fechamento + checkpoint da etapa condicional |
| `dg-leitor-notas.md` | Etapa 1 — busca no grupo de WhatsApp da obra, baixa tudo (JPG, PDF, prints de PIX) |
| `dg-chequer-leitura.md` | Etapa 2 — relê o grupo do zero e confere cobertura da leitura |
| `dg-lancador-notas.md` | Etapa 3 — escreve na aba LANÇAMENTO, resolve multi-comprovante |
| `dg-organizador-notas.md` | Etapa 4 — move e numera arquivos em Notas/Numeradas |
| `dg-conferidor-notas.md` | Etapa 5 — confere o resultado |
| `dg-pintor-notas.md` | Etapa 6 — pinta as linhas |
| `dg-limpador-notas.md` | Fechamento — organiza a pasta Downloads e encerra o ciclo |
| `skill-notas-fiscais-ml.md` | Etapa **condicional** — busca a NF-e oficial do Mercado Livre. Roda a cada 2-3 ciclos, não em todo lançamento |

**Por que `notas-fiscais-ml` é do DG e não da EP**: aqui o número oficial da nota é
obrigatório (vai para o imposto de renda do Diogo). No fluxo EP, compra do Mercado
Livre só precisa de data e valor — por isso essa skill foi removida do pipeline da EP
em 05/08/2026.

## `_pacotes-originais-cowork/`

Os `.skill` exportados do Cowork são pacotes ZIP com o `SKILL.md` dentro. Ficam
guardados nessa subpasta como snapshot autêntico do que estava instalado em
30/08/2026, mas **não são a fonte de trabalho** — o Git não consegue mostrar o que
mudou dentro de um ZIP. Todo trabalho acontece nos `.md`.

## Ainda falta trazer do Cowork

- **`lancamento-notas-obra-dg`** — a skill antiga de fluxo único, que ainda responde a
  pedidos genéricos ("lança as notas de hoje") enquanto este piloto não é validado.
  Mesmo padrão da EP: as duas convivem até o teste real aprovar a nova.
- **Controle financeiro das 4 obras DG** — marcado como "rodando, com erros pequenos"
  no mapa mental.
