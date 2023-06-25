import _indexes from '../indexes.json'
import { categories } from './categories'
import type { PackageIndexes } from './types'

export * from './categories'

export const indexes = _indexes as PackageIndexes

const componentNames = indexes.components.map(component => component.name)
const hookNames = indexes.hooks.map(hook => hook.name)

export const augmaChildren = componentNames.concat(hookNames)

export async function getCategories(type: 'components' | 'hooks') {
  return categories[type]
}

/**
 * 获取组件
 * @param name
 * @returns
 */
export const getComponent = (name: string) => indexes.components.find(f => f.name === name)
