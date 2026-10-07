# Instagram EP — contexto do projeto (lido automaticamente pelo Claude Code)

Rotina semi-automática de postagens do Instagram @engenharia.ep (EP Engenharia e Projetos, Rio de Janeiro).
Dono: Guilherme (diretor financeiro/comercial, iniciante em IA — explique simples, sem jargão).

**Leia primeiro:** `HANDOFF.md` (histórico, decisões, o que falta). Depois `ROTINA.md`, `00-Marca/voz-e-tom.md`, `00-Marca/identidade-visual.md`, `CALENDARIO.md`.

## Regras do projeto
- Idioma: português do Brasil. Respostas curtas, bottom-line primeiro.
- "Empresa", nunca "empreiteiro". Público alto padrão. Texto técnico sem jargão de canteiro.
- Skills executam (`.claude/skills/`). Agentes só conferem (`.claude/agents/`), nunca corrigem.
- Toda skill/agente se anuncia ao começar ("▶ … iniciado"). Veredito é PASS/FAIL por item com evidência citada.
- Etapa seguinte recusa iniciar sem o certificado da anterior. Publicação só com OK escrito do Guilherme.
- Fechamento sempre com prestação de contas (etapa por etapa: invocada ou NÃO invocada).
- Nunca altere posts já publicados em `01-Posts/`. Nunca apague arquivos; mova para `_apagar/`.
- Pasta de post: `01-Posts/Pnn_AAAA-MM-DD_tema-curto/` copiada de `01-Posts/_modelo-post/`.
- Scripts e arquivos de apoio ficam em `_trabalho/` dentro desta pasta, nunca no diretório temporário da sessão.

## Ferramentas disponíveis no computador (verificado em 06/10/2026)
- Windows 10, PowerShell 5.1, Git, winget. **Sem Python, sem Node, sem Playwright, sem ImageMagick.**
- Chrome em `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`.
- Edge em `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`.
- **Render HTML → PNG**: Edge headless, testado em `_trabalho/teste-render.html` → `teste-render.png` (1080×1350, ~8 s):
  `msedge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1080,1350 --screenshot=<png> file:///<html>`
- **Medições por código** (contagem de caracteres, hashtags, regex, dimensões de PNG): PowerShell + .NET (`System.Drawing`), não python3.
- Sem Metricool (decisão do Guilherme). Publicação: decisão pendente, ver HANDOFF §6.
