# Rotina de postagens — Instagram @engenharia.ep (v2, 07/10/2026)

Pasta raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`. Roda no Claude Code (VS Code), no computador do Guilherme, com ele presente.
Proposta completa e histórico de decisões: `_trabalho/PROPOSTA-processo-v2.md` e `HANDOFF.md` (Cowork, 04 a 06/10).

## O que o Guilherme faz (e só isso)
Uma vez: logo (feito, `00-Marca/logo/`), Chrome logado no ChatGPT e no Business Suite.
Toda semana, 4 toques:
1. **Aprova temas e datas** e diz se o post é Modo A (ilustrado) ou Modo B (foto real de obra, qual obra).
2. **Aprova textos.**
3. **Modo A**: cola os prompts no ChatGPT e salva as imagens em `04-imagens-brutas/`.
4. **Vê a prévia** da arte final e **programa no Business Suite** com o pacote de `03-Fila-publicacao/`. Responde "agendado".

Para o relatório: exporta o CSV de Insights do Business Suite para `04-Relatorios/_entrada/`.

## Dois modos de post
| Modo | Quando | Imagem | Exemplo |
|---|---|---|---|
| **A — Temático / ilustrado** | Pilares Educativo e Engajamento | Gerada no ChatGPT a partir dos prompts da skill | P01, P02, P03 |
| **B — Obra real** | Pilares Bastidores e Vendas ("andamento da obra X", "como resolvemos Y") | Fotos da equipe em `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP\<obra>\<Sxx>\Fotos\` (pasta liberada pelo Guilherme, só leitura). Alternativa: ele copia fotos para `04-imagens-brutas/candidatas/` | P04 |

Regra de marca: imagem gerada nunca é chamada de "obra nossa" na legenda ou no slide. Foto real sempre leva a marcação "Caso real · obra EP".

## Cadência
1 carrossel por semana (quinta, 18h às 20h) + 1 story de chamada no mesmo dia. Stories de obra (foto real, sem carrossel) entram na v1 como item avulso. Se rodar bem, passa a 2 posts por semana.
Rodízio de pilares: Educativo → Bastidores → Engajamento → Vendas. Reels fica fora até existir ferramenta de vídeo.

## Estrutura de pastas
```
00-Marca/            voz-e-tom.md · identidade-visual.md · logo/ (PNGs transparentes) · fontes/ · templates/ (HTML dos slides)
01-Posts/            UMA pasta por post: Pnn_AAAA-MM-DD_tema-curto/   (P01 a P04 são anteriores ao padrão; não mexer)
   _modelo-post/     00-certificados/ 01-brief/ 02-textos/ 03-prompts-imagem/ 04-imagens-brutas/ 05-arte-final/
02-Pesquisa-temas/   AAAA-Snn_temas.md (5 opções + Decisão do Guilherme)
03-Fila-publicacao/  Pnn/ = pacote pronto: PNGs numerados + legenda.txt + agendamento.md
04-Relatorios/       _entrada/ (CSV do Business Suite) · AAAA-Snn_relatorio.md + gráficos
.claude/skills/      skills executoras   ·   .claude/agents/  chequers
_trabalho/           scripts e testes    ·   _apagar/  nada é apagado, vai pra cá
CALENDARIO.md        tabela-mestra: nº, data, tema, pilar, modo, status
```

## O estado vive em arquivos
Status no `CALENDARIO.md`: `aprovado → textos → imagens → arte-final → agendado → publicado`.
Cada chequer que aprova grava um certificado em `01-Posts/Pnn_.../00-certificados/` (ex.: `02-textos.APROVADO.md`). A etapa seguinte lê o arquivo e recusa rodar sem ele. A skill de entrada `ep-insta` lê o calendário e despacha a próxima etapa de cada post.

## Pipeline
| Etapa | Skill (executa) | Chequer (confere, nunca corrige) | Libera |
|---|---|---|---|
| 1 Pesquisa | `ep-insta-1-pesquisa-temas` → 5 opções (web 30 dias + CSV de métricas se houver + fotos novas das obras para opções Modo B) | `agente-insta-chequer-pesquisa` | `01-pesquisa.APROVADO` → **Decisão 1** |
| 2 Textos | `ep-insta-2-producao-post` → pasta, brief, carrossel, legenda, stories, prompts (Modo A) ou seleção de fotos (Modo B) | `agente-insta-chequer-texto-tecnico` + `agente-insta-chequer-texto-conteudo` | `02-textos.APROVADO` → **Decisão 2** |
| 3 Imagens | `ep-insta-3-imagens` → Modo A: confere o que o Guilherme salvou; Modo B: copia e recorta as fotos escolhidas | `agente-insta-chequer-imagens` | `03-imagens.APROVADO` |
| 4 Arte final | `ep-insta-4-arte-final` → templates HTML + Edge headless → PNG 1080×1350 / 1080×1920 + pacote em `03-Fila-publicacao/Pnn/` | `agente-insta-chequer-arte-final` | `04-arte.APROVADO` → **Guilherme programa no Business Suite** e responde "agendado" |
| 5 Relatório | `ep-insta-5-relatorio` → lê `04-Relatorios/_entrada/*.csv` → relatório + gráficos + 3 recomendações; marca `publicado` | `agente-insta-chequer-dados` | alimenta a etapa 1 |

Regras gerais: toda skill e chequer se anuncia (`▶ nome iniciado`); PASS/FAIL por item com evidência citada; 2 reprovações seguidas → para e pergunta ao Guilherme; fechamento com prestação de contas (etapa por etapa, invocada ou não).

## Como disparar
- "Pesquisa de temas da semana" → etapa 1
- "Aprovado: tema 2 pra quinta 16/10, Modo A" → etapa 2
- "Continua o P05" → a skill `ep-insta` descobre a etapa pendente e roda
- "Agendado" → CALENDARIO vira `agendado`
- "Relatório da semana" → etapa 5 (depois de exportar o CSV)
