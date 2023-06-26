class AugmaError extends Error {
  constructor(msg: string) {
    super(msg)
    this.name = 'AugmaError'
  }
}

export function throwAugmaError(scope: string, msg: string) {
  throw new AugmaError(`[${scope}] ${msg}`)
}
