> ⚠️ HISTÓRICO (Cowork, 04 a 06/10/2026). Superado em 07/10 por `ROTINA.md` e `_trabalho/PROPOSTA-processo-v2.md`: publicação manual no Business Suite, Edge headless no lugar de Playwright, PowerShell no lugar de Python, dois modos de post (ilustrado / obra real).

# HANDOFF — Rotina de postagens Instagram EP
Compilado da conversa no app Claude (04/10/2026 a 06/10/2026) para continuar o desenvolvimento no Claude Code (VS Code).
Organograma visual (mesmo conteúdo da §4): `ORGANOGRAMA.html` nesta pasta.

---

## 1. Objetivo
Rotina de postagens do Instagram @engenharia.ep com o **mínimo de ação do Guilherme**: pesquisa de temas → aprovação → textos → imagens → arte final → agendamento → relatório. Tudo organizado nesta pasta, por número de post e data.

Cadência: 1 carrossel/semana (quinta, 18h–20h) + 1 story de chamada no mesmo dia. Rodízio de pilares: Educativo → Bastidores → Engajamento → Vendas.

## 2. Decisões tomadas (não reabrir sem motivo)
| Tema | Decisão | Motivo |
|---|---|---|
| Ferramenta de agendamento | **Metricool descartado** (Guilherme). Substituto recomendado: **API oficial da Meta (Instagram Graph API)**, gratuita. Aguardando "ok" do Guilherme entre A/B/C (ver §6) | Gratuito, oficial, sem intermediário. Plano B: Meta Business Suite pelo Chrome. Plano C: Make.com free |
| Geração de imagem | **ChatGPT** (melhor qualidade), mesmo exigindo ação manual. Canva fica como alternativa de zero toque com qualidade menor | Guilherme prioriza qualidade > automação |
| Diagramação (logo + texto + véu) | No app Claude era Claude Design. **No Claude Code não existe Claude Design** → usar templates HTML 1080×1350 / 1080×1920 renderizados em PNG com Playwright/Chromium (é assim que os posts P01–P04 foram feitos originalmente) | Reprodutível, 100% automático, mantém o padrão exato dos posts existentes |
| Onde roda | No computador do Guilherme (Claude Code), ele presente. Nuvem/agendado fica pra depois | Pedido dele |
| Vocabulário | "Empresa", nunca "empreiteiro". Público alto padrão | Posicionamento de marca (decisão de julho/2026) |
| Arquitetura | Skills executam + agentes chequers conferem em contexto isolado + certificados + supervisor + prestação de contas. Mesmo padrão do `supervisor-lancamento-ep` e dos `agente-chequer-*` de orçamentos | Guilherme exigiu conferência e validação em cada etapa antes de salvar qualquer skill |
| Checkpoints do Guilherme | 3: aprova temas (etapa 1), aprova textos (etapa 2), OK pra agendar (etapa 5) | Perguntei se mantém o da etapa 2 — **sem resposta ainda** |

## 3. Estado atual desta pasta
```
Instagram EP/
├── CLAUDE.md                 ← contexto automático pro Claude Code
├── HANDOFF.md                ← este arquivo
├── ORGANOGRAMA.html          ← organograma visual (abrir no navegador)
├── ROTINA.md                 ← fluxo em texto (ainda cita Metricool/Claude Design — ATUALIZAR, ver §7)
├── CALENDARIO.md             ← tabela-mestra: P01–P04 publicados
├── 00-Marca/
│   ├── identidade-visual.md  ← cores, fontes, layouts (extraído dos posts prontos)
│   ├── voz-e-tom.md          ← regras de texto, pilares, hashtags
│   ├── logo/                 ← VAZIA — Guilherme precisa colocar o logo PNG transparente
│   └── referencias/          ← VAZIA — páginas do manual da marca (Lufdesign)
├── 01-Posts/
│   ├── _modelo-post/         ← esqueleto: 01-brief/ 02-textos/ 03-prompts-imagem/ 04-imagens-brutas/ 05-arte-final/
│   ├── P01_2026-07-01_antes-da-obra/            (7 slides + story + legenda.txt)
│   ├── P02_2026-07-02_sinais-estruturais/       (7 slides + story + legenda.txt)
│   ├── P03_2026-07-02_empresa-sumiu_campanha-paga/ (9 slides + fotos campanha)
│   └── P04_2026-07-16_obra-limpa-obra-seria/    (6 slides)
├── 02-Pesquisa-temas/        ← vazia (recebe AAAA-Snn_temas.md)
├── 03-Fila-publicacao/       ← vazia (pacote pronto pra publicar)
├── 04-Relatorios/            ← vazia
├── .claude/
│   ├── skills/ep-insta-1-pesquisa-temas/SKILL.md     ← ESCRITA, não testada
│   ├── skills/ep-insta-2-producao-post/SKILL.md      ← ESCRITA, não testada
│   ├── agents/agente-insta-chequer-pesquisa.md       ← ESCRITO, não testado
│   ├── agents/agente-insta-chequer-texto-tecnico.md  ← ESCRITO, não testado
│   └── agents/agente-insta-chequer-texto-conteudo.md ← ESCRITO, não testado
└── _skills_old_pode_apagar/  ← cópias antigas, pode apagar
```
Nada foi salvo na conta do Claude (app) como skill. Tudo vive em arquivos aqui.

## 4. Arquitetura (organograma em texto)
**Nível 0 — Guilherme**: dispara com 1 comando; decide 3 vezes (temas, textos, OK pra agendar).
**Nível 1 — `ep-insta-supervisor`** (A CONSTRUIR): chama as skills em ordem, dispara os agentes, monta certificados só quando aprovam, manda corrigir quando reprovam (máx. 2 rodadas, depois pergunta), para nos checkpoints, fecha com prestação de contas.

| Etapa | Skill (executa) | Agente(s) (confere) | Certificado | Status |
|---|---|---|---|---|
| 1 | `ep-insta-1-pesquisa-temas`: 6+ buscas web (30 dias), concorrentes, referências, métricas dos nossos posts → 5 temas com pilar/fonte/gancho/nota → `02-Pesquisa-temas/AAAA-Snn_temas.md` | `agente-insta-chequer-pesquisa`: abre cada fonte, atualidade ≤60 dias, não repete CALENDARIO, pilar do rodízio, palavras proibidas, título ≤8 palavras, 2 buscas próprias de cobertura | Certificado de Pesquisa → **checkpoint: Guilherme aprova temas + datas** | escrito |
| 2 | `ep-insta-2-producao-post`: recusa sem certificado + decisão; cria pasta Pnn; brief; carrossel.md (6–9 slides); legenda.txt (padrão dos posts antigos); stories.txt; prompts.md (inglês, 4:5/9:16, no text/no logo, área livre pra texto) | `agente-insta-chequer-texto-tecnico` (16 itens por código: regex da pasta, arquivos, placeholders, limites de caracteres, 18–24 hashtags, contato, ≤2.200 chars, prompts) + `agente-insta-chequer-texto-conteudo` (12 itens por leitura: fidelidade ao tema, veracidade técnica afirmação por afirmação, números sem fonte, promessas, honestidade das imagens geradas, tom, arco, coerência, dados da marca) | Certificado de Textos → **checkpoint: Guilherme aprova textos** | escrito |
| 3 | `ep-insta-3-imagens`: gera imagens no ChatGPT a partir de `03-prompts-imagem/prompts.md` → `04-imagens-brutas/` | `agente-insta-chequer-imagens`: arquivos existem, proporção, sem texto/logo gerado, cena bate com prompt/slide, área livre, paleta fria | Certificado de Imagens | a construir |
| 4 | `ep-insta-4-arte-final`: template HTML por tipo de slide (capa / interno com foto / interno fundo claro / CTA / story) + Playwright → PNG 1080×1350 e 1080×1920 em `05-arte-final/`; copia pacote pra `03-Fila-publicacao/` | `agente-insta-chequer-arte-final`: dimensões exatas, ordem, texto idêntico ao carrossel.md, logo presente sem efeito, contraste, faixa livre no story | Certificado de Arte → **checkpoint: Guilherme vê prévia e diz "pode agendar"** | a construir |
| 5 | `ep-insta-5-agendar`: recusa sem Certificado de Arte + OK escrito; publica/agenda (ver §6); CALENDARIO → `agendado` | `agente-insta-chequer-agendamento`: relê da plataforma: data/hora, legenda idêntica, nº e ordem das imagens, conta certa | Certificado de Agendamento | a construir |
| 6 | `ep-insta-6-relatorio` (semanal): alcance, salvamentos, compartilhamentos, cliques, melhor horário/pilar → gráficos + 3 recomendações → `04-Relatorios/` | `agente-insta-chequer-dados`: cada número = dado bruto da API, nada estimado, gráfico em escala | alimenta a etapa 1 seguinte | a construir |

Regras gerais (valem pra todos): anunciar-se ao iniciar; agente nunca corrige; PASS/FAIL por item com evidência; certificado só se o agente rodou e aprovou; 2 reprovações seguidas → supervisor para e pergunta; publicação só com OK escrito; prestação de contas no fechamento (trabalho "à mão" sem invocar a skill = NÃO invocada).

## 5. Identidade visual e voz (resumo; detalhe em 00-Marca/)
- Cores: azul-marinho #0B1F33→#1B3A5C (fundo), ciano #00A3E0 (acento), branco gelo #F4F7FA (slides claros). Campanha "dor real": preto + laranja #E8521C.
- Tipografia: títulos sans bold condensada (Saira/Rajdhani); corpo IBM Plex Sans. Palavra-chave do título em ciano.
- Capa: foto real + véu azul ~75%, logo branco topo-esquerda, 4 quadradinhos topo-direita, pílula do pilar, título grande, `@ENGENHARIA.EP` + `arraste →`. Filete ciano 1px no topo de todo slide.
- Story: mesmo fundo, "Expliquei tudo **no feed**" + círculo ciano com mão + "ARRASTE P/ CIMA"; faixa inferior ~250px livre pro sticker.
- Legenda: gancho → contexto → lista 1️⃣…5️⃣ → posicionamento EP → CTA `(21) 98355-0728 · epengenharia.eng.br` → 18–24 hashtags.
- Proibido no logo: contorno, sombra, efeito, fundo que reduza contraste.

## 6. Publicação sem Metricool — opções (DECISÃO PENDENTE do Guilherme)
**A — API oficial da Meta (Instagram Graph API), recomendada.**
- Gratuita. Publica carrossel, reels e stories; lê insights (alcance, salvamentos, compartilhamentos, views).
- Requisitos: @engenharia.ep conta profissional vinculada a uma Página do Facebook (ele já roda campanha paga, provavelmente já está); app gratuito em developers.facebook.com em modo desenvolvimento (sem App Review pra conta própria); token de longa duração (60 dias, renovar automaticamente); permissões `instagram_basic`, `instagram_content_publish`, `pages_read_engagement` (+ `instagram_manage_insights` pra métricas).
- Limite: 25 publicações/24h. Testei em 04/10: o container do app Claude alcança graph.facebook.com; no Claude Code roda do computador dele.
- **Não tem agendamento nativo.** Fluxo: container → publish. Pra "agendar": (i) publicar na hora do OK, ou (ii) script Python disparado pelo Agendador de Tarefas do Windows na data/hora do CALENDARIO (PC precisa estar ligado), ou (iii) tarefa agendada no app Claude (nuvem) — fora do Claude Code.
- **Imagens precisam de URL pública** pra API buscar. Proposta: repositório público gratuito no GitHub só com as artes finais (vão ficar públicas no Instagram de qualquer jeito). Alternativas: Cloudinary free. Guilherme ainda não opinou.
- Fontes: https://www.outstand.so/blog/instagram-api-pricing · https://zernio.com/blog/instagram-graph-api

**B — Meta Business Suite pelo Chrome** (automação de interface, Claude in Chrome / Playwright com perfil logado). Zero configuração, agendamento nativo, métricas na tela. Contra: quebra quando o site muda; Chrome aberto na hora de agendar.

**C — Make.com** (plano gratuito, 1.000 ops/mês, módulo Instagram for Business). Volta a ter intermediário.

Recomendação registrada: A como principal, B como contingência dentro das skills 5 e 6.

## 7. Adaptações necessárias ao sair do app Claude pro Claude Code
1. `ROTINA.md` ainda cita Metricool e Claude Design → reescrever conforme §2 e §6.
2. As skills 1 e 2 citam "Metricool" (etapa 1, métricas) e "pasta conectada" → trocar por: métricas via Graph API (ou "sem métricas até a etapa 6 existir") e caminho local `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`.
3. Agentes usam `device_bash`/`WebFetch` → no Claude Code é `Bash`/`WebFetch` (já ajustado no frontmatter `tools`).
4. Etapa 3 (ChatGPT): no Claude Code, opções: (a) Claude in Chrome (`claude --chrome`) operando chatgpt.com no Chrome do Guilherme; (b) Playwright com perfil logado; (c) manual: Guilherme cola os prompts e salva em `04-imagens-brutas/` — ele aceitou isso em nome da qualidade.
5. Etapa 4: criar `00-Marca/templates/` com HTML dos 5 tipos de slide, parametrizados por JSON (título, corpo, badge, imagem de fundo, nº do slide). Renderizar com Playwright (Chromium) em 1080×1350 / 1080×1920, deviceScaleFactor 1. Validar comparando visualmente com P02/P04.
6. Supervisor: no Claude Code, skill que invoca as outras skills (Skill tool) e os agentes (Task/Agent tool com `subagent_type` = nome do arquivo em `.claude/agents/`).

## 8. Pré-requisitos do Guilherme (uma vez só)
- [ ] Logo EP PNG transparente (branco e azul) em `00-Marca/logo/`
- [ ] Páginas do manual da marca (Lufdesign) em `00-Marca/referencias/`
- [ ] Decidir §6 (A/B/C) e, se A: criar app na Meta (guiado), conta GitHub ou alternativa pra hospedar imagens
- [ ] Conta ChatGPT logada no Chrome
- [ ] Responder: mantém o checkpoint de textos (etapa 2) ou só aprova no final?
- [ ] Responder: chequer de imagens reprova qualquer texto/logo gerado (mais rodadas no ChatGPT) ou só avisa?
- [ ] Indicar onde ficam as fotos reais de obras (pra posts de bastidores/antes-depois)

## 9. Próximos passos sugeridos, nesta ordem
1. Guilherme responde os pendentes da §8 (pelo menos §6 e os 2 checkpoints).
2. Reescrever `ROTINA.md` e ajustar skills 1–2 (item §7.1–7.2).
3. Escrever `.claude/skills/ep-insta-supervisor/SKILL.md` (modelo: skill `supervisor-lancamento-ep` da conta do Guilherme — certificado, checkpoint, prestação de contas).
4. **Testar etapas 1–2 de ponta a ponta** com um tema real: supervisor → skill 1 → chequer pesquisa → aprovação → skill 2 → 2 chequers → aprovação. Ajustar o que falhar.
5. Etapa 4 (arte final) antes da 3: templates HTML + Playwright, testando com as imagens já existentes de P02. É a etapa com mais valor e sem dependência externa.
6. Etapa 3 (imagens via ChatGPT) + chequer.
7. Etapa 5 (publicação, §6) + chequer. Primeiro teste com um story (menor risco).
8. Etapa 6 (relatório) + chequer.
9. Só depois: tarefa agendada/nuvem, se quiser rodar sem o PC.

## 10. Histórico resumido da conversa (pra contexto)
- 04/10 12:22 — Guilherme descreve a rotina desejada (13 etapas, Claude Code + Claude Design + ChatGPT pra imagens + agente postando + relatórios).
- 04/10 — Propus Metricool (agendar + métricas) e Canva. Guilherme: gratuito só; qualidade > automação (ChatGPT); roda no PC dele; perguntou como Claude Code conversa com Claude Design → expliquei que são ambientes separados e recomendei rodar no app. Ele depois pediu pra seguir no Claude Code (daí este handoff).
- 04/10 — Pasta `Instagram EP` conectada. Li legendas e slides dos 4 posts existentes; extraí identidade visual e voz; criei estrutura, modelo de post, ROTINA, CALENDARIO; escrevi skills 1–2.
- 04/10 16:22 — Guilherme: "antes de salvar qualquer skill, quero agentes de checagem em cada etapa, com validações". Li `supervisor-lancamento-ep` e `agente-chequer-conteudo` dele e repliquei o padrão: 3 agentes escritos (pesquisa, texto técnico, texto conteúdo). Guilherme pediu organograma e aprovação antes de continuar → organograma publicado e aprovado ("excelente").
- 04/10 16:42 — Perguntou onde precisa atuar → listei (uma vez só: salvar skills, logo, Metricool, ChatGPT logado; toda semana: 1 comando + 3 respostas). Em seguida: "Não vamos usar o Metricool" → levantei A/B/C (§6). Sem resposta ainda.
- 06/10 21:04 — Pediu este compilado pra continuar no Claude Code.
