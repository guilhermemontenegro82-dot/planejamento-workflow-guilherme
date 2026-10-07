# Espaço de trabalho do Guilherme — `D:\12- Claude - works`

## As três regras do Guilherme (07/10/2026, palavras dele)
1. **Nunca mexa ou entre com arquivos no OneDrive. NUNCA.** Nada de criar, copiar, mover, renomear, alterar ou apagar qualquer coisa em `C:\Users\gamon\OneDrive\`, em nenhuma subpasta, por nenhum motivo. Ler a pasta de fotos que ele liberou é a única exceção, e é só leitura.
2. **Não se esqueça da primeira regra.**
3. **O espaço de trabalho é `D:\12- Claude - works`.**

## Regra de acesso (detalhamento, vale para toda sessão)
- **Dentro desta pasta: autonomia total.** Criar, renomear, mover, reorganizar e apagar arquivos e pastas, sem perguntar. É o espaço livre de trabalho para desenvolver e entregar resultados.
- **Fora desta pasta, duas situações.** (1) O Guilherme libera uma pasta **apresentando o caminho durante a explicação da tarefa**: essa pasta está liberada para a tarefa, sem precisar perguntar de novo. (2) Qualquer outra pasta, inclusive caminhos conhecidos de outras sessões ou da memória: ler, listar, copiar, mover ou alterar exige pedir acesso e esperar o "sim".
- Pastas liberadas de forma permanente (por ordem dele) ficam em `C:\Users\gamon\.claude\hooks\caminhos-liberados.txt` e em `permissions.additionalDirectories` do `settings.json`. Hoje: `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP` (fotos das obras EP, usar só leitura).
- Exceções técnicas (não são dados dele): a configuração do próprio Claude Code em `C:\Users\gamon\.claude\` (memória, skills, hooks) e o diretório temporário da sessão.
- Enforço técnico: `blockReadsOutsideWorkingDirectories`, regras `deny` para Documentos/Desktop/Downloads/Imagens e escrita no OneDrive, e o hook `C:\Users\gamon\.claude\hooks\guarda-caminhos.ps1`, que faz o Claude Code **perguntar** antes de qualquer comando de shell que cite caminho fora daqui e fora das pastas liberadas.

## Como o Guilherme trabalha
- Português do Brasil. Respostas curtas, resultado primeiro. Explicar simples, sem jargão.
- Scripts, testes e arquivos temporários ficam dentro do workspace (`_trabalho/` do projeto), nunca no diretório temporário da sessão. Assim ele e eu podemos abrir, inspecionar e apagar.
- **Apagar é livre dentro do workspace** (decisão de 07/10/2026): arquivos temporários, de estudo, prints, renders de prova e scripts obsoletos, apago sem perguntar quando deixarem de servir. Conteúdo produzido por ele ou já entregue (posts publicados, planilhas e documentos de origem) só apago quando a tarefa pedir; `_apagar/` fica como opção de segurança, não obrigação.
- Instalar programas na máquina segue os critérios do modo Auto do Claude Code.
- **Git**: autorizado (07/10/2026) a fazer commit e push sozinho ao fechar cada etapa, com mensagem clara. O `.gitignore` é uma lista de permissão: entram definições, documentos, textos, scripts e templates; planilhas, PDFs, mídia e dados de clientes ficam fora (peso e sigilo). Antes de liberar um tipo novo no `.gitignore`, conferir tamanho e sensibilidade.
- Pipelines de skills seguem o padrão: skill executa, chequer confere em contexto isolado, certificado em arquivo libera a etapa seguinte, prestação de contas no fim.

## Mapa
- `01 - EP Engenharia/` — EP Engenharia e Projetos (orçamentos, notas, recibos, Instagram, …). Cada tema tem o próprio `CLAUDE.md` ou `ROTINA.md`.
- `02 - DG Revy/` — DG Revy (base de dados financeiros, físico x financeiro).
