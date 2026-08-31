---
name: "dg-leitor-notas"
description: "Etapa 1 do pipeline \"Supervisor de lançamento DG\": busca as notas fiscais, recibos e comprovantes no grupo de WhatsApp específico de cada obra DG (ou já numa pasta local) e BAIXA TUDO — JPG, PDF, prints de PIX — renomeando com prefixo da obra + número temporário sequencial, além de ler as mensagens de texto em busca de contexto (reembolsos, aportes, descontos, fotos \"Encaminhada\"). Diferente da EP, aqui os arquivos físicos precisam ser baixados e guardados. Não escreve na planilha (isso é dg-lancador-notas) nem organiza os arquivos na pasta Notas definitiva (isso é dg-organizador-notas). Só deve ser chamada pela skill supervisor-lancamento-dg, nunca diretamente a partir de um pedido genérico do usuário — pedidos genéricos continuam acionando a skill lancamento-notas-obra-dg (fluxo único já validado)."
---

---
name: "dg-leitor-notas"
description: "Etapa 1 do pipeline \"Supervisor de lançamento DG\": busca as notas fiscais, recibos e comprovantes no grupo de WhatsApp específico de cada obra DG (ou já numa pasta local) e BAIXA TUDO — JPG, PDF, prints de PIX — renomeando com prefixo da obra + número temporário sequencial, além de ler as mensagens de texto em busca de contexto (reembolsos, aportes, descontos, fotos \"Encaminhada\"). Diferente da EP, aqui os arquivos físicos precisam ser baixados e guardados. Não escreve na planilha (isso é dg-lancador-notas) nem organiza os arquivos na pasta Notas definitiva (isso é dg-organizador-notas). Só deve ser chamada pela skill supervisor-lancamento-dg, nunca diretamente a partir de um pedido genérico do usuário — pedidos genéricos continuam acionando a skill lancamento-notas-obra-dg (fluxo único já validado)."
---

## Papel nesta pipeline

Etapa 1 do fluxo `supervisor-lancamento-dg`. Busca e baixa os arquivos — não escreve na
planilha (isso é o `dg-lancador-notas`), não organiza/numera os arquivos na pasta definitiva
(isso é o `dg-organizador-notas`) e não pinta nada (isso é o `dg-pintor-notas`).

## Objetivo

Buscar as notas (no grupo de WhatsApp da obra específica, ou já numa pasta local) e **baixar
tudo** — JPG, PDF, prints de PIX — guardando os arquivos físicos, ao contrário do fluxo da EP
(que não precisa de arquivo, só de dado). Ler também as mensagens de texto em busca de contexto
(reembolsos, aportes, descontos, encaminhamentos) e produzir uma lista de arquivos baixados com
os dados já identificados, pronta para o `dg-lancador-notas` escrever na planilha.

O usuário está sempre disponível: **na dúvida, pergunte antes de decidir.**

## Pré-requisito: trabalhar sem tomar o computador do usuário

Duas ferramentas diferentes entram em jogo aqui e não são iguais:

- **Claude-in-Chrome** (abrir aba, navegar, clicar, JS na página) — controla só uma aba/janela
  do Chrome. O usuário confirmou que isso não atrapalha: se precisar do navegador, abre outra
  janela. Pode usar à vontade para o WhatsApp Web.
- **Computer-use** (mouse/teclado/tela do Windows inteiro) — toma o computador inteiro e tira
  de vista o layout normal do Claude. Evite sempre que houver alternativa.

**No início do fluxo, se ainda não tiver sido feito nesta conta, chame
`mcp__cowork__request_cowork_directory(path="~/Downloads")`** para conectar a pasta Downloads
real do usuário. Depois de conectada, fica disponível em sessões futuras também — tanto pelas
ferramentas de arquivo (`Read`/`Write`/`Edit`, caminho `C:\Users\<usuario>\Downloads\`) quanto
pelo shell (`mcp__workspace__bash`, caminho `/sessions/<sessão>/mnt/Downloads/`). Com isso, o
fluxo inteiro roda só com Claude-in-Chrome + bash, sem computer-use.

Se a pasta Downloads não puder ser conectada, caia pro método antigo com computer-use (ver
Troubleshooting) — trate como exceção, não como padrão.

## Quem gastou na DG (elenco fixo)

Ao contrário da EP (vários técnicos e caixas), a DG normalmente só tem **duas pessoas fixas**:

- **Guilherme** — o próprio usuário.
- **Mestre** (apelido "Bruno") — o mestre de obras.

Algumas obras têm um **terceiro pagador eventual** (ex.: **Diogo**, sócio/investidor da obra)
— quando isso acontecer, pergunte ao usuário a regra de cor/identificação (na obra Gustavo
Sampaio - Leme, Diogo foi identificado por mensagens/fotos enviadas diretamente por ele ou
encaminhando o comprovante) e anote o padrão confirmado para reportar ao Supervisor.

Um técnico específico (ex.: **Tiago**) pode aparecer pagando do próprio bolso e sendo
reembolsado depois por PIX — confirme pelo comprovante de reembolso ("Reembolso [nome] [item]")
antes de decidir quem gastou. **Atenção: o reembolso não muda quem gastou.** Se o Guilherme
reembolsou o técnico, quem efetivamente pagou (e vai na coluna "Quem gastou") é o Guilherme —
o comprovante de reembolso só serve pra confirmar QUAL item já processado (ou a processar) foi
o que o técnico adiantou, não vira item novo.

Gastos em **dinheiro em espécie** têm uma convenção separada (colunas M4="Espécie" e
M5="$Mestre"), mas é caso raro — **não tente adivinhar a regra**, pergunte ao usuário como
lançar e documente o que for confirmado.

**Não existem Jonathan, Matheus, Cabelinho, Anderson ou Renato nas obras DG** — isso é elenco
da EP, não misture.

### Fotos/comprovantes "Encaminhada" — critério principal

**Critério principal, confirmado pelo usuário**: a tag "Encaminhada" no cabeçalho da mensagem é
o que decide quem gastou num comprovante de Pix, não o nome impresso no campo "Origem" do
próprio comprovante (esse nome pode ser de uma conta compartilhada/da empresa que às vezes
representa o Guilherme, às vezes o Mestre — não é confiável sozinho):

- **Mensagem marcada "Encaminhada"** → o Mestre pagou do bolso/conta dele e mandou o
  comprovante pro Guilherme, que só repassou (encaminhou) pro grupo. Quem gastou = **Mestre**.
- **Mensagem enviada direto por "Você" (Guilherme), SEM a tag "Encaminhada"** → foi o próprio
  Guilherme quem fez o Pix e está compartilhando o comprovante dele mesmo, na hora, sem
  repassar nada de ninguém. Quem gastou = **Guilherme**.

Se por algum motivo a tag "Encaminhada" não aparecer com clareza na mensagem (ex.: print
recortado, mensagem antiga sem esse recurso), aí sim recorra ao padrão histórico do fornecedor
nos itens já lançados daquela obra como segunda pista — mas **confirme com o usuário antes de
gravar**, é uma hipótese, não uma certeza.

**Cuidado ao compilar a lista final**: numa mesma leitura é comum ver vários comprovantes de Pix
seguidos, com o mesmo layout e às vezes nomes de origem parecidos (ex.: duas contas de "pessoa
física" diferentes usadas pela obra). Ao escrever a tabela final para o Supervisor/usuário,
**releia o comprovante específico daquele item de novo antes de preencher fornecedor/quem
gastou** — não confie na memória do que foi visto em mensagens anteriores da mesma leitura. Foi
exatamente assim que um erro real aconteceu numa obra: os dados (Origem, Destino) de um
comprovante foram atribuídos ao item errado porque dois comprovantes parecidos foram
confundidos na hora de montar a tabela final.

## Passo a passo

### 1. Identificar a obra e o grupo

Cada obra DG tem **seu próprio grupo de WhatsApp** (diferente da EP, que usa um grupo único
para todas as obras). Confirme com o usuário qual obra/grupo processar antes de começar.

### 2. Achar o ponto de corte

Abra o WhatsApp Web (via Claude-in-Chrome) e localize o grupo da obra. Procure a última
mensagem **"Atualizado até aqui"** (ou equivalente) — só as notas enviadas depois dela ainda
não foram lançadas. Não achou essa marcação? Pergunte ao usuário onde ela costuma ficar.

### 3. Varrer tudo sem pular nada

Use os dois métodos, não só um:

- **Lightbox** (abrir uma imagem e usar as setas do rodapé) — bom pra ver comprovante por
  comprovante em tela cheia e pegar a legenda de cada um.
- **Rolagem normal do chat** (scroll, sem abrir o lightbox) — mais confiável pra não pular
  nada, mostra o texto de contexto ao redor (quem pediu o quê, se é reembolso, se é orçamento
  sendo discutido antes da compra). **Depois de uma passada pelo lightbox, role o chat inteiro
  de novo em modo normal como conferência** — mensagens muito próximas em horário (ex.: três
  comprovantes seguidos às 16:49) são fáceis de pular no lightbox.
- Use "mais zoom" sempre que um número/texto estiver difícil de ler — não adivinhe e não marque
  "sem número" (SN) sem antes ter dado zoom. Se não resolver, baixe a imagem e leia pelo arquivo
  salvo.

### 4. Identificar quem gastou em cada nota

Aplique o critério principal da seção "Fotos/comprovantes 'Encaminhada'" acima: tag
"Encaminhada" presente = Mestre; mensagem enviada direto por "Você" sem essa tag = Guilherme.
Não deu pra confirmar com segurança (tag não aparece clara)? Pergunte — não guie pelo primeiro
palpite nem pelo nome impresso no comprovante. Comprovante de reembolso a um técnico → o "quem
gastou" do item comprado é de quem reembolsou (normalmente Guilherme), não do técnico.

### 5. Baixar cada nota/comprovante para a pasta Downloads

Método padrão — dispare o download via JavaScript no contexto da página (ferramenta de
execução de JS do Claude-in-Chrome), sem depender de clicar em nada na tela do usuário:

```javascript
const imgs = Array.from(document.querySelectorAll('img'))
  .filter(i => i.offsetWidth > 300 && i.offsetHeight > 300 && i.src.startsWith('blob:'));
const img = imgs.sort((a,b) => (b.offsetWidth*b.offsetHeight)-(a.offsetWidth*a.offsetHeight))[0];
const a = document.createElement('a');
a.href = img.src;
a.download = 'nome-desejado.jpg';
document.body.appendChild(a);
a.click();
a.remove();
```

Isso pega o `<img>` grande do lightbox e salva na pasta Downloads real do usuário (desde que
conectada). Não tente extrair os bytes da imagem pela resposta da ferramenta de JS — conteúdo
binário/base64 é bloqueado.

Para **PDFs** abertos no visualizador do WhatsApp Web (ficam num `<iframe>` cross-origin), use
o ícone de download (seta pra baixo) na barra de ferramentas do próprio visualizador.

Se um `screenshot` do Claude-in-Chrome der timeout depois de navegar no lightbox, a página
geralmente continua respondendo a JS normalmente — espere e tente de novo, ou siga só com JS
(baixar + ler o arquivo salvo) sem depender de screenshot.

### 6. Renomear com prefixo temporário

Renomeie cada arquivo com um prefixo da obra + número temporário sequencial (ex.:
`rainha_92.jpg`, `rainha_93.jpg`) enquanto ainda não sabe o número final da planilha — o número
definitivo só é decidido depois, na Etapa 2/3.

### 7. Ler o arquivo já pela pasta Downloads

Depois de baixar, leia o arquivo direto pela pasta Downloads conectada (`Read` no caminho
`C:\Users\<usuario>\Downloads\<nome>.jpg`) para extrair valor, data e demais dados — sem
precisar voltar pra tela do WhatsApp. **Ao montar a tabela final, releia o arquivo específico
de cada item de novo** (não confie na memória de ter visto o comprovante antes) — ver aviso na
seção "Fotos/comprovantes 'Encaminhada'" acima.

### 8. Notar contexto de múltiplos comprovantes da mesma compra

Fique atento a mensagens que parecem se referir à **mesma compra**: um orçamento enviado
primeiro, depois um comprovante de pagamento (às vezes com desconto em relação ao orçamento), e
a nota fiscal chegando dias depois. **Não ignore mensagens digitadas** — elas costumam
explicar esse tipo de desconto/contexto. Anote essa relação (ex.: "orçamento enviado dia X,
pix enviado dia Y, possível desconto, NF ainda não chegou") junto do item, para o
`dg-lancador-notas` decidir como tratar (uma linha só, com os arquivos relacionados). Na dúvida
se dois valores parecidos são a mesma compra, pergunte ao usuário.

### 9. Conferir antes de fechar a Etapa 1

- O número de notas baixadas bate com o que você viu entre o corte e o fim do grupo? Nenhuma
  deve ficar pra trás — cuidado especial com comprovantes seguidos no mesmo minuto.
- Se a última mensagem do grupo for um comprovante de reembolso, isso costuma marcar o fim do
  lote — confirme lendo o texto das últimas linhas do chat que não há nada depois dela.

## Formato de saída (entregar ao Supervisor / dg-lancador-notas)

Para cada arquivo baixado: nome temporário, obra, quem gastou (com nota se foi por
suposição/regra), valor aproximado, data, e observações (é reembolso? é aporte/espécie? faz
parte de uma compra com múltiplos comprovantes — e quais outros arquivos pertencem a ela?).
Mais uma lista de dúvidas a confirmar com o usuário antes do Supervisor acionar o
`dg-lancador-notas`.

## Troubleshooting

| Problema | Solução |
|---|---|
| Imagem não carregou no WhatsApp Web | Pedir ao usuário para rolar mais o histórico (pré-carrega as mídias) |
| Não sabe se é Guilherme, Mestre ou terceiro pagador | Checar a tag "Encaminhada" (ver critério principal) — só perguntar ao usuário se a tag não estiver clara |
| Dois comprovantes parecidos na mesma leitura | Releia cada um individualmente antes de montar a tabela final — não confie na memória (ver aviso na seção "Encaminhada") |
| Download bloqueado ou não dispara pelo clique normal | Usar o truque de link de download via JavaScript acima |
| PDF não dá pra baixar por JS (iframe cross-origin) | Usar o ícone de download nativo do visualizador de PDF do WhatsApp Web |
| A pasta Downloads do usuário ainda não foi conectada | Chamar `mcp__cowork__request_cowork_directory(path="~/Downloads")` antes de começar |
| Screenshot do Claude-in-Chrome trava com timeout | A página costuma continuar respondendo — espere e tente de novo; se persistir, siga só com JS |
| Aba/grupo do Claude-in-Chrome sumiu ("No tab group exists") | Chamar `navigate` para a URL de novo (web.whatsapp.com) |
| **(fallback só se Downloads não puder ser conectada)** | Pedir acesso ao app "Executar" via computer-use e rodar `cmd /c "move ..."` um arquivo por vez — tratar como exceção |

