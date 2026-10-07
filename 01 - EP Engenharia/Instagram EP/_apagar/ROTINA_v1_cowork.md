# Rotina de postagens — Instagram EP Engenharia

> ⚠️ Este arquivo está desatualizado em 2 pontos: Metricool foi descartado (ver HANDOFF.md §6) e Claude Design vira templates HTML + Playwright no Claude Code (HANDOFF.md §7). Reescrever na próxima sessão.

Pasta raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`
Tudo roda no app Claude (desktop), com esta pasta conectada. Claude Code / VS Code serve só pra editar os arquivos de `_skills/` se quiser.

## Estrutura de pastas
```
00-Marca/              identidade visual, voz e tom, logo, manual
01-Posts/              UMA pasta por post:  Pnn_AAAA-MM-DD_tema-curto/
   _modelo-post/       modelo vazio (copiado automaticamente a cada post novo)
02-Pesquisa-temas/     pesquisa semanal: AAAA-Snn_temas.md (lista pra aprovação + decisão)
03-Fila-publicacao/    só o que está PRONTO pra agendar (atalho de conferência)
04-Relatorios/         métricas semanais/mensais com gráficos
.claude/skills/        skills (lidas pelo Claude Code)
.claude/agents/        agentes chequers (lidos pelo Claude Code)
CALENDARIO.md          tabela-mestra: nº, data, tema, pilar, status, link publicado
```

## Dentro de cada post
```
01-brief/           brief.md  (tema aprovado, pilar, objetivo, público, fontes da pesquisa)
02-textos/          carrossel.md (slide a slide) · legenda.txt · stories.txt
03-prompts-imagem/  prompts.md (1 prompt por slide + 1 por story, prontos pra colar no ChatGPT)
04-imagens-brutas/  o que o ChatGPT gerou (você salva aqui: slide-01.png, story-01.png…)
05-arte-final/      exportado 1080×1350 e 1080×1920 com logo/texto — vai pro agendamento
```

## O fluxo (1 comando seu + 2 respostas)
| Etapa | Quem faz | Skill |
|---|---|---|
| 1. Pesquisa de temas em alta (web, concorrentes, perfis de referência, métricas dos nossos posts) | automático | `ep-insta-1-pesquisa-temas` |
| 2. Lista de 5 temas → **você aprova** (responde "1 e 3", ou ajusta) | você | — |
| 3. Cria pasta do post, brief, textos (carrossel/reels, legenda, stories) e prompts de imagem | automático | `ep-insta-2-producao-post` |
| 4. Gerar imagens: Claude abre o ChatGPT no Chrome, cola prompt, baixa → `04-imagens-brutas/` | semi-automático (pode pedir sua ajuda se o ChatGPT travar) | `ep-insta-3-imagens` *(próxima)* |
| 5. Diagramação com logo/texto no padrão EP → `05-arte-final/` | automático (Claude Design) | `ep-insta-4-arte-final` *(próxima)* |
| 6. Agendar no Metricool (→ Instagram) na data do CALENDARIO | automático, **pede seu OK antes** | `ep-insta-5-agendar` *(próxima)* |
| 7. Relatório semanal: alcance, salvamentos, compartilhamentos, melhor horário | automático | `ep-insta-6-relatorio` *(próxima)* |

## Como você dispara
- "Roda a pesquisa de temas da semana" → etapa 1 → lista pra aprovar
- "Aprovado: tema 2 pra quinta e tema 4 pra semana que vem" → etapas 3 em diante
- "Relatório da semana" → etapa 7

## Cadência atual
- 1 carrossel por semana (quinta-feira, 18h–20h) + 1 story de chamada no mesmo dia
- Rodízio de pilares: Educativo → Bastidores → Engajamento → Vendas → repete
- Campanha paga: tratar como post normal com sufixo `_campanha-paga`

## Pré-requisitos (uma vez só)
- [ ] Logo EP em PNG transparente (branco e azul) em `00-Marca/logo/`
- [ ] Páginas do manual da marca (Lufdesign) em `00-Marca/referencias/`
- [ ] Conectar o Metricool (plano gratuito) no app Claude e ligar o Instagram @engenharia.ep nele
- [ ] Conta do ChatGPT logada no Chrome (pra geração de imagens)
