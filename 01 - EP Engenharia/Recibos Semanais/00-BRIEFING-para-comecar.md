# Recibos Semanais — briefing para a sessão que vai construir esta skill

Criado em 30/08/2026, no fim da sessão de Lançamento de Notas, para a **próxima sessão do
Claude Code** começar orientada.

## O que o Guilherme quer

Uma skill que:

1. **Leia as planilhas** onde ele lança os valores apurados de pagamento de cliente da
   semana.
2. **Gere os recibos em Word** a partir desses valores.
3. **Converta para PDF**.

## O que a sessão nova precisa perguntar antes de escrever qualquer coisa

Não comece a redigir a skill sem isso — foi o que funcionou em Orçamentos e Lançamento de
Notas: partir dos artefatos reais, nunca da descrição.

- **A planilha de origem real** — onde ficam esses valores, qual aba, quais colunas.
  Uma planilha de verdade, não um exemplo inventado.
- **O modelo de recibo atual** (`.docx`), se já existir um. Se ele já faz isso à mão, o
  arquivo que ele usa hoje é a fonte da verdade do formato.
- **Um ou dois recibos já emitidos**, como referência do resultado esperado.
- **Um recibo por cliente ou um por semana?** Como ele nomeia e onde arquiva.
- **Que dados entram no recibo**: cliente, obra, período, valor, forma de pagamento,
  assinatura?

## Estrutura da pasta (já criada)

```
Recibos Semanais\
├── Skills\               ← a skill vai aqui (fonte da verdade, versionada)
├── Modelos\              ← modelo .docx do recibo
├── Planilhas (origem)\   ← planilhas de onde saem os valores
└── Recibos gerados\      ← saída (.docx e .pdf)
```

## Contexto que já existe e vale reaproveitar

- **`CLAUDE.md`** (em `Planejamento WorkFlow Guilherme\`) — protocolo de trabalho, regra de
  nunca editar direto no Cowork, tratamento de skills empacotadas.
- **Skill de proposta comercial** (`01 - EP Engenharia\Orçamentos\Skills\skill-6-proposta-comercial.md`)
  — já resolve geração de `.docx` a partir de dados de planilha, incluindo as armadilhas:
  o bug de regex `<w:t[^>]*>` que casa com `<w:tc>` e destrói a tabela, a contagem de
  `<w:tc>`, o `paraId` aleatório precisando ficar abaixo de `0x80000000`, e a conferência
  do conteúdo por `pandoc` em vez de leitura visual. **Ler isso antes de escrever a parte
  de Word economiza descobrir tudo de novo.**
- **Lições de arquitetura** — ver a memória do projeto: chequer que compara contra memória
  é eco; mandar invocar não garante que invocou; sinal mecânico vence inferência.

## Uma pergunta de desenho que vale fazer cedo

Recibo é documento que vai para o cliente e envolve dinheiro. Vale perguntar ao Guilherme
se quer **gate humano antes de emitir** (ele revisa os valores antes de virar PDF), como
existe no pipeline de Orçamentos antes da proposta. A resposta muda a arquitetura.
