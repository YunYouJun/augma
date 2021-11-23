/**
 * 是否是有效的尺寸
 * @param val
 */
export const isValidComponentSize = (val: string) =>
  ['', 'large', 'medium', 'small', 'mini'].includes(val)
