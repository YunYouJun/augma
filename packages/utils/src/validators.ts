/**
 * 是否是有效的尺寸
 * @param val
 */
export function isValidComponentSize(val: string) {
  return ['', 'large', 'medium', 'small', 'mini'].includes(val)
}
