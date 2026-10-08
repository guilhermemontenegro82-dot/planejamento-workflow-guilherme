# Espaço de trabalho do Guilherme — `D:\12- Claude - works`

## As três regras do Guilherme (07/10/2026, palavras dele)
1. **Nunca mexa ou entre com arquivos no OneDrive. NUNCA.** Nada de criar, copiar, mover, renomear, alterar ou apagar qualquer coisa em `C:\Users\gamon\OneDrive\`, em nenhuma subpasta, por nenhum motivo. Ler a pasta de fotos que ele liberou é a única exceção, e é só leitura.
2. **Não se esqueça da primeira regra.**
3. **O espaço de trabalho é `D:\12- Claude - works`.**

## Regra de acesso (detalhamento, vale para toda sessão)
- **Dentro desta pasta: autonomia total.** Criar, renomear, mover, reorganizar e apagar arquivos e pastas, sem perguntar. É o espaço livre de trabalho para desenvolver e entregar resultados.
- **Fora desta pasta, duas situações.** (1) O Guilherme libera uma pasta **apresentando o caminho durante a explicação da tarefa**: essa pasta está liberada para a tarefa, sem precisar perguntar de novo. (2) Qualquer outra pasta, inclusive caminhos conhecidos de outras sessões ou da memória: ler, listar, copiar, mover ou alterar exige pedir acesso e esperar o "sim".
- Pasta liberada de forma permanente (por ordem dele): `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP` (fotos das obras EP, só leitura).
- Exceções técnicas (não são dados dele): a configuração do próprio Claude Code em `C:\Users\gamon\.claude\` (memória, skills) e o diretório temporário da sessão.
- **Sem trava técnica** (decisão dele em 08/10/2026): a configuração do Claude Code voltou ao original porque hook e regras de permissão geravam caixas demais. As regras acima valem como disciplina minha, e eu as sigo sem exceção. O guarda antigo está guardado em `_claude-temp/hooks-desativados-08-10/` caso ele queira reativar um dia.

## Como o Guilherme trabalha
- Português do Brasil. Respostas curtas, resultado primeiro. Explicar simples, sem jargão.
- **Perguntas de conceito: poucas e agrupadas.** Ele trabalha em outras coisas enquanto o Claude roda; cada interrupção custa caro aos dois. Perguntar só quando a resposta muda materialmente o trabalho. Juntar as dúvidas numa única rodada (uma caixa com até 4 perguntas, com a opção recomendada primeiro), nunca uma pergunta por vez ao longo da tarefa. Decisão rotineira: tomar, registrar a premissa adotada e seguir; ele corrige depois se discordar.
- Scripts, testes e arquivos temporários ficam dentro do workspace (`_trabalho/` do projeto), nunca no diretório temporário da sessão. Assim ele e eu podemos abrir, inspecionar e apagar.
- **Apagar é livre dentro do workspace** (decisão de 07/10/2026): arquivos temporários, de estudo, prints, renders de prova e scripts obsoletos, apago sem perguntar quando deixarem de servir. Conteúdo produzido por ele ou já entregue (posts publicados, planilhas e documentos de origem) só apago quando a tarefa pedir; `_apagar/` fica como opção de segurança, não obrigação.
- **Zero caixas de permissão dentro do autódromo** é o objetivo dele. As caixas vêm do sistema de permissões do Claude Code (modo da sessão), não do meu julgamento. As únicas perguntas que ele quer receber são **sobre conceito e direcionamento do trabalho** (temas, textos, decisões), nunca sobre permissão. Instalar programas e enviar e-mail ou mensagem a alguém: avisar antes no chat.
- **Git**: autorizado (07/10/2026) a fazer commit e push sozinho ao fechar cada etapa, com mensagem clara. O `.gitignore` é uma lista de permissão: entram definições, documentos, textos, scripts e templates; planilhas, PDFs, mídia e dados de clientes ficam fora (peso e sigilo). Antes de liberar um tipo novo no `.gitignore`, conferir tamanho e sensibilidade.
- Pipelines de skills seguem o padrão: skill executa, chequer confere em contexto isolado, certificado em arquivo libera a etapa seguinte, prestação de contas no fim.

## Mapa
- `01 - EP Engenharia/` — EP Engenharia e Projetos (orçamentos, notas, recibos, Instagram, …). Cada tema tem o próprio `CLAUDE.md` ou `ROTINA.md`.
- `02 - DG Revy/` — DG Revy (base de dados financeiros, físico x financeiro).
