---
name: ep-insta-1-pesquisa-temas
description: Etapa 1 da rotina Instagram EP. Pesquisa semanal de temas (web últimos 30 dias, métricas próprias se houver, fotos novas das obras) e entrega 5 opções com Modo A/B para o Guilherme aprovar; depois registra a decisão dele no arquivo e no CALENDARIO. Use quando ele pedir "pesquisa de temas", "temas da semana", "o que postar", ou quando responder a aprovação ("aprovado tema 2 pra quinta").
---

# Etapa 1 — Pesquisa de temas · Instagram EP

Anuncie-se: `▶ ep-insta-1-pesquisa-temas — Etapa 1 iniciada`.
Raiz: `D:\12- Claude - works\01 - EP Engenharia\Instagram EP`. Leia antes `ROTINA.md`, `00-Marca/voz-e-tom.md`, `CALENDARIO.md`.

Esta skill tem duas partes. **Parte A** roda quando ele pede a pesquisa. **Parte B** roda quando ele responde a aprovação.

## Parte A — Pesquisar e propor

### A1. Sinais (faça tudo, sem perguntar)
1. **Rodízio**: no `CALENDARIO.md`, pegue o último post `publicado`/`agendado`/`aprovado` e deduza o pilar da vez (Educativo → Bastidores → Engajamento → Vendas).
2. **Web** (WebSearch, modo extended se vier fraco). Mínimo 6 buscas em português do Brasil, últimos 30 dias:
   - Notícias: "reforma apartamento" / "reforço estrutural" / "desabamento" / "laudo estrutural" / "obra condomínio" + mês atual ou ano
   - Tendências: "tendências reforma", "o que está em alta arquitetura interiores", "custo da obra m² RJ"
   - Dor do cliente: "problema com empresa de reforma", "obra atrasada o que fazer", "reclame aqui reforma"
   - Datas e ganchos do mês: feriados, eventos (Casa Cor, Expo Revestir), chuva (infiltração), virada de ano (planejamento)
   - Referências: carrosséis de engenharia/arquitetura com boa resposta recente (busque "carrossel instagram engenharia civil", canais de patologia das construções)
   Tendência é **termômetro**, não regra: o Guilherme decide.
3. **Métricas próprias**: se existir arquivo em `04-Relatorios/` (relatório da etapa 5), leia o mais recente e use "melhor pilar / melhor formato / melhor horário". Se não existir, escreva 1 linha: "Sem relatório de métricas ainda" e siga.
4. **Fotos novas das obras (Modo B)**. Pasta liberada pelo Guilherme, **só leitura**:
   `C:\Users\gamon\OneDrive\Pasta compartilhada ADM\Relatórios Fotográficos Obras EP\<obra>\<Sxx>\Fotos\`
   Via PowerShell, liste as pastas `Fotos` com arquivos modificados nos últimos 21 dias e quantas fotos têm. Abra (Read) até 6 fotos da semana mais recente de cada obra para saber o que mostram. Ignore `Finalizadas\` a menos que não haja obra ativa com foto nova. Nunca copie, mova ou altere nada nessa pasta.

### A2. Montar 5 opções
Cada opção, exatamente com estes campos:
- **Título provisório** (como ficaria na capa, máx. 8 palavras)
- **Pilar** (Educativo / Bastidores / Engajamento / Vendas)
- **Modo**: `A` (ilustrado, imagem gerada no ChatGPT) ou `B` (foto real; informar `obra / Sxx`, nº de fotos úteis e o que elas mostram)
- **Por que agora** (1 frase: notícia, estação, tendência, ou "fotos novas da obra X mostram Y")
- **Formato** (carrossel n slides) e **gancho do story**
- **Fonte** (link da web; para Modo B, o caminho da pasta de fotos)
- **Nota de potencial** 1 a 5 (alcance esperado × aderência ao público alto padrão)

Regras obrigatórias:
- Pelo menos 1 opção do pilar da vez. Pelo menos 1 opção Modo B se houver foto nova em alguma obra (Bastidores e Vendas **são sempre Modo B**; Educativo e Engajamento são Modo A, salvo foto real que ilustre bem).
- Nada que repita tema do `CALENDARIO.md` (sentido, não só palavras).
- Linguagem de `voz-e-tom.md`: "empresa", nunca "empreiteiro"; público alto padrão; sem "barato".
- Modo A: nada que exija provar "obra nossa", porque a imagem será gerada.

### A3. Salvar
Arquivo `02-Pesquisa-temas/AAAA-Snn_temas.md` (semana ISO, ex.: `2026-S41_temas.md`). Estrutura:
```
# Pesquisa de temas — semana AAAA-Snn (data)
Pilar da vez: <pilar>  ·  Último post: Pnn <tema>  ·  Métricas: <resumo ou "sem relatório ainda">
Fotos novas: <obra/Sxx: n fotos — o que mostram> | nenhuma

## Opção 1 — <título>
- Pilar: … · Modo: … · Nota: …
- Por que agora: …
- Formato: … · Story: …
- Fonte: …
(… até Opção 5)

## Buscas feitas
<lista das consultas e o que achou, 1 linha cada>

## Decisão do Guilherme
(em branco)
```

### A4. Conferência (obrigatória antes de mostrar a ele)
Invoque pela ferramenta Agent o agente `agente-insta-chequer-pesquisa`, passando: caminho do arquivo de temas, `CALENDARIO.md`, `00-Marca/voz-e-tom.md`.
- O agente grava `02-Pesquisa-temas/AAAA-Snn_temas.certificado.md` com `VEREDITO: APROVADO|REPROVADO`.
- REPROVADO → corrija **só** o apontado, no arquivo de temas, e invoque de novo. Máximo 2 rodadas; na terceira reprovação, pare e mostre ao Guilherme o que o chequer apontou.
- Não mostre a lista a ele sem certificado APROVADO.

### A5. Apresentar
No chat: tabela curta (nº · título · pilar · modo · por que agora · nota) + 1 linha "Certificado de pesquisa: APROVADO (rodada n)". Pergunte: **"Quais aprovamos, pra que data, e confirma o modo?"**

## Parte B — Registrar a decisão
Quando ele responder (ex.: "tema 2 pra quinta 16/10, modo A"):
1. Escreva na seção `## Decisão do Guilherme` do arquivo de temas: data da resposta, opções escolhidas, datas de publicação, modo, obra (se B), ajustes que ele pediu, texto literal da resposta.
2. Adicione a linha no `CALENDARIO.md`: próximo `Pnn`, data, tema, pilar, modo, formato, status `aprovado`, pasta ainda em branco.
3. Diga: "Próximo passo: `ep-insta-2-producao-post` para o Pnn." Não a execute sem ele pedir.

## Prestação de contas (fim de cada parte)
```
=== ETAPA 1 — PRESTAÇÃO DE CONTAS ===
Buscas web: n · Fotos de obra lidas: n (obras: …) · Métricas: lidas | sem relatório
Arquivo: 02-Pesquisa-temas/… · Chequer de pesquisa: INVOCADO rodada n → APROVADO | NÃO INVOCADO (motivo)
Decisão registrada: sim (Pnn, data, modo) | aguardando
=== FIM ===
```

## Não faça
- Não invente métricas, likes ou "viral". Sem dado, diga que não tem.
- Não crie pasta de post, textos ou prompts (etapa 2).
- Não copie, mova nem altere fotos das obras. Só leia.
- Não leia nada fora da raiz do projeto e da pasta de fotos liberada. Outro caminho → peça acesso antes.
