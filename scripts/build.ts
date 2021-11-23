import fs from 'fs'
import path from 'path'
import os from 'os'
import { execa } from 'execa'
import { logger, targets } from './utils'

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
  logger.info(`Build [${target}]`)
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
