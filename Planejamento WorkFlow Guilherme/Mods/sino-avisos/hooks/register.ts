import type { EngineInterface, Register } from 'claude-code'

// Dois sons:
//   decisao.wav : quando abre uma caixa de pergunta, plano ou aprovação
//   fim.wav     : quando a tarefa (o turno principal) termina
// No Windows o player embutido do Claude Code não toca nada, então o som
// sai pelo SoundPlayer do próprio Windows, via PowerShell.

const PERGUNTAS = ['AskUserQuestion', 'ExitPlanMode']

function tocar($: EngineInterface, arquivo: 'decisao' | 'fim'): void {
  const caminho = `${$.plugin.root}/sons/${arquivo}.wav`.replaceAll('/', '\\')
  const script = `(New-Object Media.SoundPlayer '${caminho.replaceAll("'", "''")}').PlaySync()`

  // Sem await: o som toca em paralelo e nunca segura o trabalho.
  $.process
    .run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script], { timeoutMs: 10_000 })
    .catch(() => undefined)
}

export const register: Register = on => {
  // Caixa de decisão aberta pelo Claude (pergunta ou aprovação de plano)
  on('tool.call', ($, e, next) => {
    if (PERGUNTAS.includes(String(e.tool))) tocar($, 'decisao')
    return next(e)
  })

  // Janela de permissão (aprovar uma ação)
  on('classic.PermissionRequest', ($, e, next) => {
    tocar($, 'decisao')
    return next(e)
  })

  // Fim da tarefa: só o turno principal, não os subagentes, e não quando interrompido
  on('turn.complete', ($, e, next) => {
    if (e.agentId === undefined && !e.isAborted) tocar($, 'fim')
    return next(e)
  })
}
