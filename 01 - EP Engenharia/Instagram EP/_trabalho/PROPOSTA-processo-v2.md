# PROPOSTA — Processo v2 da rotina Instagram EP (06/10/2026, para aprovação do Guilherme)

Base: os 12 passos descritos pelo Guilherme em 06/10 + HANDOFF.md. O que muda em relação ao HANDOFF está marcado **[NOVO]**, **[REMOVIDO]** ou **[MUDA]**.

## A. Decisões que este documento assume
- Publicação pela **Meta Business Suite no Chrome** (opção B do HANDOFF §6). Link do Guilherme: business.facebook.com, asset 100619406302752. Agendamento nativo, insights na tela, zero configuração. Contra assumido: automação de interface quebra quando a Meta muda a tela; Chrome precisa estar aberto e logado.
- Arte final por **templates HTML + Edge headless** (testado em `_trabalho/teste-render.png`). Substitui "Claude Design" e Playwright.
- Medições por código em **PowerShell** (máquina sem Python/Node).
- Reels **fora da v1** [REMOVIDO]: exige vídeo e edição; nenhuma ferramenta da máquina produz vídeo automaticamente. Volta na v2 como "roteiro + slides animados" se fizer sentido.
- "Verificação de likes dos concorrentes" [MUDA]: não há API pública para likes de terceiros. v1 usa busca web (notícias, tendências, Google Trends) + métricas dos NOSSOS posts (Business Suite). Leitura de perfis concorrentes pelo Chrome fica como fase 2, porque é lenta e frágil.

## B. O estado vive em arquivos, não na conversa [NOVO]
As etapas acontecem em dias diferentes (pesquisa segunda, imagens quarta, agendar quinta). Um "supervisor" que roda tudo numa sessão não existe na prática. Então:
- `CALENDARIO.md` guarda o status de cada post (ideia → aprovado → textos → imagens → arte-final → agendado → publicado).
- Cada certificado dos chequers é gravado em `01-Posts/Pnn_.../00-certificados/` (ex.: `02-textos.APROVADO.md`). A etapa seguinte lê o arquivo; não confia em memória de conversa.
- A skill de entrada `ep-insta` lê o CALENDARIO, descobre em que etapa cada post está e despacha a próxima. Um comando do Guilherme ("continua") basta.

## C. Pipeline lapidado

| Etapa | Skill (executa) | Chequer (confere, não corrige) | Certificado que libera a próxima | Guilherme |
|---|---|---|---|---|
| 0 (uma vez) | montar `00-Marca/templates/` (5 tipos de slide) e validar contra P02/P04 | chequer-arte-final roda sobre P02 reconstruído: tem que sair visualmente igual | — | entrega logo PNG e manual |
| 1 | `ep-insta-1-pesquisa-temas`: web 30 dias + métricas próprias → 5 temas | `chequer-pesquisa` (abre fontes, rodízio de pilar, sem repetição) | `01-pesquisa.APROVADO` | **Decisão 1**: quais temas, que datas, e **tem foto real? onde?** [NOVO] |
| 2 | `ep-insta-2-producao-post`: pasta Pnn, brief, carrossel, legenda, stories, prompts | `chequer-texto-tecnico` (PowerShell) + `chequer-texto-conteudo` | `02-textos.APROVADO` | **Decisão 2**: aprova textos |
| 3 | `ep-insta-3-imagens`: **dois caminhos** [MUDA]. (a) tema ilustrado → prompts no ChatGPT; (b) foto real da equipe → só seleciona, recorta 4:5/9:16 e salva. O "tratamento" (véu, logo, padrão) é da etapa 4, não desta | `chequer-imagens`: arquivo por slide, proporção, sem texto/logo gerado, cena bate com o slide | `03-imagens.APROVADO` | se ChatGPT manual: cola prompts e salva em `04-imagens-brutas/` |
| 4 | `ep-insta-4-arte-final`: HTML templates + Edge → PNG 1080×1350 e 1080×1920; monta **pacote de publicação** em `03-Fila-publicacao/Pnn/` (PNGs numerados + `legenda.txt` + `agendamento.json` com data/hora/ordem) [NOVO] | `chequer-arte-final`: dimensões exatas, texto idêntico ao carrossel.md, logo sem efeito, contraste, faixa livre no story | `04-arte.APROVADO` | **Decisão 3**: vê a prévia e escreve "pode agendar" |
| 5 | `ep-insta-5-agendar`: Chrome → Business Suite → Criar publicação → Instagram → sobe PNGs na ordem → cola legenda → agenda data/hora; depois agenda o story. CALENDARIO → `agendado` | `chequer-agendamento`: abre o Planejador do Business Suite e relê: data, hora, legenda idêntica, nº e ordem das imagens, conta @engenharia.ep | `05-agendamento.APROVADO` | nada (só se o Chrome deslogar) |
| 6 (semanal) | `ep-insta-6-relatorio`: lê Insights do Business Suite → `04-Relatorios/AAAA-Snn.md` + gráficos PNG (HTML + Edge) + 3 recomendações; marca `publicado` no CALENDARIO | `chequer-dados`: cada número existe na tela/export, nada estimado | alimenta a etapa 1 da semana seguinte | lê o relatório |

Regra nova de marca [NOVO]: posts dos pilares **Bastidores** e **Vendas/Antes & Depois** exigem foto real. Imagem gerada só em **Educativo** e **Engajamento**, e a legenda nunca pode chamar de "obra nossa". O chequer-conteúdo já tem esse item; vira regra explícita no `voz-e-tom.md`.

## D. Onde o Guilherme atua
Uma vez: logo PNG transparente em `00-Marca/logo/`; páginas do manual Lufdesign em `00-Marca/referencias/`; Chrome logado no Business Suite e no ChatGPT; indicar a pasta das fotos de obra.
Toda semana: Decisão 1 (temas + datas + fotos), Decisão 2 (textos), imagens no ChatGPT se o caminho for manual, Decisão 3 ("pode agendar"). Quatro toques, nenhum deles técnico.

## E. Organograma de agentes
- Nível 0: Guilherme (3 decisões + 1 insumo de fotos).
- Nível 1: `ep-insta` (despachante): lê CALENDARIO e certificados, chama a etapa certa, recusa pular etapa, fecha com prestação de contas (invocada / NÃO invocada, por etapa).
- Nível 2: 6 skills executoras (etapas 1 a 6).
- Nível 3: 7 chequers em contexto isolado (pesquisa, texto-técnico, texto-conteúdo, imagens, arte-final, agendamento, dados). PASS/FAIL por item com evidência citada. Duas reprovações seguidas → despachante para e pergunta ao Guilherme.

## F. Ordem de construção sugerida
1. Ajustar skills 1–2 e os 3 chequers à máquina real (PowerShell, caminhos, sem Metricool). Migrar P01–P04 ao padrão de pastas sem alterar conteúdo.
2. Etapa 0 + 4: templates e render. Reconstruir o P02 a partir dos textos e comparar com o publicado. É o teste mais honesto do padrão visual.
3. Despachante `ep-insta` + certificados em arquivo.
4. Teste de ponta a ponta das etapas 1–2 com tema real.
5. Etapa 3 (imagens, dois caminhos) + chequer.
6. Etapa 5 (Business Suite) + chequer. Primeiro teste com um story.
7. Etapa 6 (relatório) + chequer.

## G. Respostas do Guilherme em 07/10/2026 (fecham pontos da proposta)
- Reels fora da v1. Quando houver ferramenta ou ele aprender a editar, cria-se uma sequência própria para vídeo.
- "Likes/trends" = termômetro para escolher tema, nunca diretriz imutável. A skill 1 usa busca web + métricas próprias como sinal, e o Guilherme decide.
- **Duas ações manuais aceitas por ele**: (1) mandar os prompts ao ChatGPT e salvar as imagens; (2) programar as postagens no Business Suite. Todo o resto deve ser automático. Consequência: a etapa 5 vira "pacote pronto + roteiro de agendamento" e o chequer de agendamento é substituído pela confirmação escrita dele ("agendado") que muda o CALENDARIO.
- **Dois modos de post aprovados**: Modo A = temático/ilustrado com imagem gerada (como P01–P03); Modo B = andamento de obra ou "como resolvemos X", com fotos reais tiradas pela equipe. Ele tem pastas de obras com as melhores fotos selecionadas toda semana para o relatório ao cliente e vai compartilhar.
- Posts P01–P04 estão encerrados: não serão repostados nem alterados. O teste de templates que "reconstrói o P02" renderiza em `_trabalho/`, nunca dentro de `01-Posts/`.
- Ordem de construção aprovada, condicionada a eu confirmar o entendimento do objetivo e perguntar antes de executar.
- Logo: ele entrega quando eu indicar a pasta e o nome de arquivo.

## H. Correção de escopo (07/10/2026)
O Guilherme reafirmou que a autorização de leitura é **só** a pasta do Instagram EP. Mencionar onde ficam as fotos não autorizou a leitura da pasta do OneDrive. Consequência no processo: Modo B passa a ter duas origens de foto, (a) ele copia as candidatas para `04-imagens-brutas/candidatas/` do post, ou (b) a skill pergunta e só lê o OneDrive com "sim" explícito registrado no brief. Chequers marcam NÃO VERIFICÁVEL sem isso.

## I. Regra de acesso final (07/10/2026, última palavra do Guilherme)
Dentro de `D:\12- Claude - works`, qualquer subpasta: sem perguntar. Fora: pasta que ele apresenta durante a explicação da tarefa está liberada (caso da pasta de fotos no OneDrive, só leitura); qualquer outra, pedir acesso. A seção H fica como histórico; as skills voltaram a ler a pasta de fotos diretamente.
