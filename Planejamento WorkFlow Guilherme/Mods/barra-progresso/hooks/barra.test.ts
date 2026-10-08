import { expect, test } from 'claude-code/testing'

const FERRAMENTA = 'mcp__barra-progresso__progresso'

// O teste lê o percentual pela resposta da ferramenta ("Barra em N%.")
test('a barra vai de 0 ao avanço informado, nunca volta e fecha em 100%', async ($, on) => {
  on('prompt.submit', ($, e) => ({ text: (e as { text: string }).text }) as never)
  on('turn.complete', () => ({ text: 'ok' }) as never)

  const informa = async (percentual: number) =>
    (await $.tool.call({ tool: FERRAMENTA, percentual, etapa: 'teste' } as never)) as { result?: unknown }

  await $.prompt.submit({ text: 'faça a tarefa' } as never)
  expect((await informa(0)).result).toBe('Barra em 0%.')
  expect((await informa(40)).result).toBe('Barra em 40%.')
  expect((await informa(20)).result).toBe('Barra em 40%.')

  await $.turn.complete({ answer: 'ok', durationMs: 1000, isAborted: false, turnId: 't1', reason: 'completed' } as never)
  expect((await informa(10)).result).toBe('Barra em 100%.')

  await $.prompt.submit({ text: 'nova tarefa' } as never)
  expect((await informa(5)).result).toBe('Barra em 5%.')
  expect((await informa(37)).result).toBe('Barra em 35%.')
})
