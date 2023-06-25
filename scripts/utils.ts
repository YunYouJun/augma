import fs from 'node:fs'
import path from 'node:path'

// const DOCS_URL = "https://docs.augma.elpsy.cn";
export const DIR_SRC = path.resolve(__dirname, '../packages')

export function hasDemo(pkg: string, name: string) {
  return fs.existsSync(path.join(DIR_SRC, pkg, name, 'demo.vue'))
}

// filter can not use async
export const targets = fs.readdirSync('packages').filter((f) => {
  if (
    f.endsWith('.ts')
    || f.endsWith('.md')
    || f.startsWith('.')
    || !fs.statSync(`packages/${f}`).isDirectory()
    || !fs.existsSync(path.resolve(`packages/${f}`, 'package.json'))
  )
    return false

  const pkg = JSON.parse(
    fs.readFileSync(`packages/${f}/package.json`, 'utf-8'),
  )
  if (pkg.private)
    return false

  return true
})
