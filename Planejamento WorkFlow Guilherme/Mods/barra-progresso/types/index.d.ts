export type Andamento = {
  /** O que a barra mostra agora (múltiplo de 5); anda até o alvo de 5 em 5 */
  percentual: number
  /** Até onde a barra deve chegar (múltiplo de 5), informado pelo Claude */
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
