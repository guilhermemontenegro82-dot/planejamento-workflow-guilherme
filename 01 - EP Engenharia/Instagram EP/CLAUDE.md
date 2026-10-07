# Instagram EP — contexto do projeto (lido automaticamente pelo Claude Code)

Rotina semi-automática de postagens do Instagram @engenharia.ep (EP Engenharia e Projetos, Rio de Janeiro).
Dono: Guilherme (diretor financeiro/comercial, iniciante em IA — explique simples, sem jargão).

**Leia primeiro:** `ROTINA.md` (fluxo vigente, v2). Depois `00-Marca/voz-e-tom.md`, `00-Marca/identidade-visual.md`, `CALENDARIO.md`. Histórico: `HANDOFF.md` (Cowork, 04 a 06/10) e `_trabalho/PROPOSTA-processo-v2.md`.

## Escopo de acesso (regra do Guilherme, fechada em 07/10/2026)
- Dentro de `D:\12- Claude - works` (esta pasta inclusa): autonomia total, sem perguntar.
- **Pasta de fotos das obras, liberada por ele para este projeto, só leitura:**
  `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP\<obra>\<Sxx>\Fotos\`
  (cada semana tem `Fotos\` com JPEGs e o PDF do relatório ao cliente). Listar e abrir fotos ali não exige pergunta.
- **Regra 1 do Guilherme: NUNCA mexer ou entrar com arquivos no OneDrive.** Nenhuma escrita, cópia para lá, criação de pasta, renomeação ou exclusão em qualquer caminho do OneDrive. Copiar fotos DE lá PARA dentro do post (etapa 3) é permitido; o sentido inverso, nunca. O hook do Claude Code nega comandos de escrita que citem o OneDrive.
- Qualquer outro caminho fora do workspace: pedir acesso antes.

## Regras do projeto
- Idioma: português do Brasil. Respostas curtas, bottom-line primeiro.
- "Empresa", nunca "empreiteiro". Público alto padrão. Texto técnico sem jargão de canteiro.
- Skills executam (`.claude/skills/`). Agentes só conferem (`.claude/agents/`), nunca corrigem.
- Toda skill/agente se anuncia ao começar ("▶ … iniciado"). Veredito é PASS/FAIL por item com evidência citada.
- Etapa seguinte recusa iniciar sem o certificado da anterior, gravado em `01-Posts/Pnn_.../00-certificados/`.
- Fechamento sempre com prestação de contas (etapa por etapa: invocada ou NÃO invocada).
- Nunca altere P01 a P04 em `01-Posts/` (anteriores ao padrão; referência visual). Arquivos temporários e de teste meus: apagar livremente. Conteúdo do Guilherme: só quando a tarefa pedir (`_apagar/` é opção, não obrigação).
- Pasta de post: `01-Posts/Pnn_AAAA-MM-DD_tema-curto/` copiada de `01-Posts/_modelo-post/`.
- Scripts e arquivos de apoio ficam em `_trabalho/`, nunca no diretório temporário da sessão.
- Imagem gerada nunca é chamada de "obra nossa". Modo B (foto real) é obrigatório em Bastidores e Vendas.

## O que o Guilherme faz à mão (decidido em 07/10/2026)
Colar prompts no ChatGPT e salvar em `04-imagens-brutas/`; programar no Business Suite a partir de `03-Fila-publicacao/`; exportar o CSV de Insights para `04-Relatorios/_entrada/`. Todo o resto é automático.

## Ferramentas disponíveis no computador (verificado em 06/10/2026)
- Windows 10, PowerShell 5.1, Git, curl, winget. **Sem Python, sem Node, sem Playwright, sem ImageMagick, sem pdftoppm.**
- Chrome em `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`. Edge em `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`.
- **Render HTML → PNG**: Edge headless (testado em `_trabalho/teste-render.png`, 1080×1350, ~8 s):
  `msedge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1080,1350 --screenshot=<png> file:///<html>`
- **Medições por código** (caracteres, hashtags, regex, dimensões de PNG): PowerShell + .NET (`System.Drawing`). Script de exemplo: `_trabalho/gerar-logos-transparentes.ps1`.
- Fontes Saira / IBM Plex Sans não instaladas no Windows: usar os arquivos em `00-Marca/fontes/` via `@font-face`.
