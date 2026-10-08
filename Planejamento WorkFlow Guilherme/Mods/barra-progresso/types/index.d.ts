export type Andamento = {
  /** O que a barra mostra agora (inteiro); anda até o alvo de 1 em 1 */
  percentual: number
  /** Até onde a barra deve chegar (inteiro), informado pelo Claude */
  alvo: number
  /** O que o Claude está fazendo agora, em poucas palavras */
  etapa: string
  situacao: 'andando' | 'concluida' | 'interrompida'
}

declare module 'claude-code' {
  interface PluginState {
    'barra-progresso': { andamento: Andamento | null }
  }
}
