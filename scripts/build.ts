import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { execa } from 'execa'
import consola from 'consola'
import { targets } from './utils'

async function buildAll(targets: string[]) {
  await runParallel(os.cpus().length, targets, build)
}

async function runParallel(
  maxConcurrency: number,
  source: string[],
  iteratorFn: Function,
) {
  const ret = []
  const executing = []
  for (const item of source) {
    const p = Promise.resolve().then(() => iteratorFn(item, source))
    ret.push(p)

    if (maxConcurrency <= source.length) {
      const e = p.then(() => executing.splice(executing.indexOf(e), 1))
      executing.push(e)
      if (executing.length >= maxConcurrency)
        await Promise.race(executing)
    }
  }
  return Promise.all(ret)
}

/**
 * Build Task
 * @param target packageName
 */
async function build(target: string) {
  consola.info(`Build [${target}]`)
  const pkgDir = path.resolve(`packages/${target}`)

  const distDir = `${pkgDir}/dist`
  if (fs.existsSync(distDir))
    fs.rmSync(distDir, { recursive: true })

  await execa('pnpm', ['build'], { cwd: pkgDir, stdio: 'inherit' })
}

async function main() {
  await buildAll(targets)
}

main().catch((e) => {
  console.log(e)
})
