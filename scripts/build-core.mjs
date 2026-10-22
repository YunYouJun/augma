import { spawnSync } from 'node:child_process'
import { copyFile, mkdir } from 'node:fs/promises'
import process from 'node:process'

await mkdir('dist', { recursive: true })
for (const file of ['tokens.css', 'style.css'])
  await copyFile(`src/${file}`, `dist/${file}`)
// The framework-free effects compile to plain ES modules with declarations.
const tsc = spawnSync('tsc', ['-p', 'tsconfig.build.json'], { stdio: 'inherit', shell: process.platform === 'win32' })
if (tsc.status !== 0)
  process.exit(tsc.status ?? 1)
