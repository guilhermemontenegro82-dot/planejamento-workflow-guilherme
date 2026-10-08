import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Andamento } from '../types'

// A barra começa em 0% quando você manda a tarefa, o Claude informa o avanço
// pela ferramenta "progresso" a cada etapa, e ela fecha em 100% quando o turno termina.
// A barra não salta: anda de 5 em 5% até o valor informado, um degrau a cada PASSO_MS.

const andamento = atom({ plugin: 'barra-progresso', key: 'andamento' } as const, null)

const FERRAMENTA = 'mcp__barra-progresso__progresso'
const VERDE = '#22c55e'
const PRETO = '#000000'
const DEGRAU = 5
const PASSO_MS = 200

const INSTRUCAO = [
  'Barra de andamento (mod barra-progresso): em toda tarefa com mais de um passo, chame a ferramenta',
  `${FERRAMENTA} logo no início (percentual baixo, etapa = o que vai fazer) e de novo a cada avanço relevante,`,
  'com o percentual estimado do trabalho já concluído (0 a 100) e a etapa atual em poucas palavras, em português.',
  'Seja realista e nunca volte o percentual. Não é preciso chamar em respostas curtas de uma só etapa;',
  'ao fim do turno a barra vai a 100% sozinha.',
].join(' ')

/** Arredonda para baixo no múltiplo de 5, entre 0 e 100 */
function emDegraus(n: number): number {
  const limitado = Math.max(0, Math.min(100, n))
  return Math.floor(limitado / DEGRAU) * DEGRAU
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'progresso',
      description:
        'Atualiza a barra de andamento que o Guilherme vê acima da caixa de texto. ' +
        'percentual: quanto da tarefa já foi concluído (0 a 100). etapa: o que está sendo feito agora, em poucas palavras.',
      inputSchema: {
        type: 'object',
        properties: {
          percentual: { type: 'number', minimum: 0, maximum: 100 },
          etapa: { type: 'string' },
        },
        required: ['percentual'],
      },
      isDeferred: false,
    })

    // Animação: a cada PASSO_MS, se a barra está abaixo do alvo, sobe um degrau de 5%
    $.clock.every(PASSO_MS, async () => {
      const a = await read($, andamento)
      if (a === null || a.percentual >= a.alvo) return
      await update($, andamento, (atual): Andamento | null =>
        atual === null ? null : { ...atual, percentual: Math.min(atual.alvo, atual.percentual + DEGRAU) },
      )
    })

    return next(e)
  })

  on('prompt.compose', async ($, e, next) => {
    const composto = await next(e)
    return {
      sections: [
        ...composto.sections,
        { id: 'barra-progresso:instrucao', text: INSTRUCAO, scope: 'session' },
      ],
    }
  })

  // Nova tarefa: zera a barra
  on('prompt.submit', async ($, e, next) => {
    await update($, andamento, (): Andamento => ({ percentual: 0, alvo: 0, etapa: 'iniciando', situacao: 'andando' }))
    return next(e)
  })

  // O Claude informa o avanço: vira o novo alvo (nunca volta)
  on('tool.call', { tool: FERRAMENTA }, async ($, e) => {
    // Os argumentos chegam soltos em e (e.percentual, e.etapa)
    const entrada = e as { percentual?: unknown; etapa?: unknown }
    const pedido = typeof entrada.percentual === 'number' ? emDegraus(entrada.percentual) : 0
    const etapa = typeof entrada.etapa === 'string' ? entrada.etapa.slice(0, 120) : undefined

    const atual = await update($, andamento, (a): Andamento => ({
      percentual: a?.percentual ?? 0,
      alvo: Math.max(a?.alvo ?? 0, pedido),
      etapa: etapa ?? a?.etapa ?? '',
      situacao: 'andando',
    }))
    return { result: `Barra em ${atual.alvo}%.` }
  })

  // Fim do turno principal: alvo 100% (a barra sobe até lá de 5 em 5) ou marca interrompida
  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      await update($, andamento, (a): Andamento | null =>
        a === null
          ? null
          : e.isAborted
            ? { ...a, situacao: 'interrompida' }
            : { ...a, alvo: 100, etapa: 'concluída', situacao: 'concluida' },
      )
    }
    return next(e)
  })

  // Desenho: uma linha só, barra + percentual
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const a = await read($, andamento)
    if (a === null || e.props.hasSurvey) return next(e)

    const { Box, Text } = $.ui.resolve(e)

    const pct = `${String(a.percentual).padStart(3)}%`
    // No app desktop o meio bloco é mais largo que a célula medida,
    // então a barra usa 80% da largura para não quebrar linha.
    const colunas = e.props.bodyColumns - pct.length - 1
    const largura = Math.max(10, Math.floor(e.surface === 'desktop' ? colunas * 0.8 : colunas))
    const cheio = Math.round((largura * a.percentual) / 100)
    const corPct = a.percentual === 100 ? VERDE : undefined

    return (
      <Box flexDirection="row">
        {/* Meio bloco (▄): barra com metade da altura de uma linha */}
        <Text color={VERDE} wrap="truncate-end">
          {'▄'.repeat(cheio)}
        </Text>
        <Text color={PRETO} wrap="truncate-end">
          {'▄'.repeat(largura - cheio)}
        </Text>
        <Text bold color={corPct} wrap="truncate-end">
          {' '}
          {a.situacao === 'interrompida' ? `${pct} interrompida` : pct}
        </Text>
      </Box>
    )
  })
}
