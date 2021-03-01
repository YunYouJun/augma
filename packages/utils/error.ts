class AugmaError extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = "AugmaError";
  }
}

export default (scope: string, msg: string) => {
  throw new AugmaError(`[${scope}] ${msg}`);
};
