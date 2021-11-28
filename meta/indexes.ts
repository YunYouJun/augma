import _indexes from './indexes.json'
import type { PackageIndexes } from './types'

const indexes = _indexes as PackageIndexes
export default indexes

const componentNames = indexes.components.map(component => component.name)
const hookNames = indexes.hooks.map(hook => hook.name)

export const augmaChildren = componentNames.concat(hookNames)

export async function getCategories(type: 'components' | 'hooks') {
  const categories = await import('./categories.json')
  return categories.default[type]
}

/**
 * 获取组件
 * @param name
 * @returns
 */
export const getComponent = (name: string) => indexes.components.find(f => f.name === name)
