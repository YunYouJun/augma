export const efforts = ['low', 'medium', 'high', 'xhigh', 'max']

export function onRequest(body, ctx) {
  if (ctx.agent !== 'augma' || !body || typeof body !== 'object')
    return body
  const effort = ctx.options?.effort ?? 'medium'
  if (!efforts.includes(effort)) {
    ctx.reject(400, 'Invalid Augma reasoning setting. Save a supported effort in the Augma plugin.')
    return body
  }
  if (ctx.protocol === 'chat')
    return { ...body, reasoning_effort: effort }
  if (ctx.protocol === 'responses')
    return { ...body, reasoning: { ...body.reasoning, effort } }
  return body
}
