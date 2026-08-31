---
name: "dg-conferidor-notas"
description: "Etapa 4 do pipeline \"Supervisor de lançamento DG\": depois que os arquivos já estão organizados e numerados pelo dg-organizador-notas, relê todos os arquivos da pasta Notas/Numeradas (não só os desta sessão) e valida a sequência numérica contra a coluna E da planilha, reportando lacunas ou divergências antes da pintura final. Não escreve nem organiza arquivo nenhum — só confere. Só deve ser chamada pela skill supervisor-lancamento-dg, depois do dg-organizador-notas."
---

## Papel nesta pipeline

Etapa 4 do fluxo `supervisor-lancamento-dg`. Última checagem antes da pintura final
(`dg-pintor-notas`): confirma que a numeração dos arquivos físicos bate com a planilha, pra
nunca deixar passar uma nota esquecida ou uma sequência baguncada — importante porque o
contador usa esse pacote pra fazer o imposto de renda do Diogo.

## Passo a passo

1. Releia, um por um, **todos** os arquivos de nota já organizados na pasta Notas/Numeradas —
   não só os organizados nesta sessão pelo `dg-organizador-notas`. Vale a pena conferir também
   os anteriores se nunca foram revisados.
2. Para cada um, confira se o número impresso no cupom (quando existir, mesmo critério do
   `dg-lancador-notas` pra decidir a coluna E) bate exatamente com o que está na coluna E da
   linha correspondente na planilha.
3. Rode uma checagem de sequência numérica na pasta (do 1 até o maior número) e reporte
   lacunas — lacunas antigas (de antes desta sessão) não são um problema novo, só confirme que
   nenhuma lacuna nova apareceu no intervalo que acabou de ser organizado.
4. Para itens multi-comprovante (orçamento/pix/nf), confirme que os sufixos existem conforme
   esperado e que nenhum arquivo ficou com nome genérico ou sem sufixo.

## Se encontrar divergência

**Não corrija sozinho.** Reporte ao Supervisor qual foi a divergência e qual etapa
provavelmente precisa ser revisitada:

- Número errado ou faltando na planilha → aponte de volta para o `dg-lancador-notas`.
- Arquivo com nome errado, duplicado ou faltando na pasta → aponte de volta para o
  `dg-organizador-notas`.
- Nenhuma correção deve ser feita nesta etapa nem pulada — o Supervisor decide se revisita a
  etapa anterior antes de seguir para o `dg-pintor-notas`.

Essa passada pega erros que passam despercebidos na leitura corrida das etapas anteriores — já
aconteceu de um número estar visível no cupom mas não ter sido capturado na primeira leitura.

## Entregar para a próxima etapa

Se tudo bateu: confirme ao Supervisor que a numeração está limpa (zero lacunas novas, zero
divergências) e libere o `dg-pintor-notas` para rodar.

