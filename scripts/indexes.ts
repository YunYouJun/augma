import fs from 'fs'
import path from 'path'
import fg from 'fast-glob'
import matter from 'gray-matter'

import type { Component, Hook, PackageIndexes } from '../meta/types'

import { DIR_SRC, hasDemo } from './utils'

export async function listComponents(dir: string, ignore: string[] = []) {
  const files = await fg('*', {
    onlyDirectories: true,
    cwd: dir,
    ignore: ['_*', 'dist', 'node_modules', ...ignore],
  })
  files.sort()
  return files
}

export async function listHooks(dir: string, ignore: string[] = []) {
  const files = await fg('*', {
    onlyDirectories: true,
    cwd: dir,
    ignore: ['_*', 'dist', 'node_modules', ...ignore],
  })
  files.sort()
  return files
}

/**
 * 读取并生成索引
 */
export async function readIndexesAndHints() {
  const indexes: PackageIndexes = {
    components: [],
    hooks: [],
  }

  const dir = path.join(DIR_SRC, 'components')
  const components = await listComponents(dir)

  const hooksDir = path.join(DIR_SRC, 'hooks')
  const hooks = await listHooks(hooksDir)

  for (const componentName of components) {
    const mdPath = path.join(dir, componentName, 'index.md')

    if (!fs.existsSync(mdPath))
      continue

    const component: Component = {
      name: componentName,
      title: '',
      category: '',
    }

    const mdRaw = fs.readFileSync(mdPath)
    const { data: frontmatter } = matter(mdRaw)
    const { category, title } = frontmatter

    component.category = category
    component.title = title

    indexes.components.push(component)
  }

  for (const hookName of hooks) {
    const mdPath = path.join(hooksDir, hookName, 'index.md')

    if (!fs.existsSync(mdPath) || !hasDemo('hooks', hookName))
      continue

    const hook: Hook = {
      name: hookName,
      title: '',
      category: '',
    }

    const mdRaw = fs.readFileSync(mdPath)
    const { data: frontmatter } = matter(mdRaw)
    Object.assign(hook, frontmatter)
    indexes.hooks.push(hook)
  }

  return {
    indexes,
  }
}
