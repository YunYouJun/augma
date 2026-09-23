import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import process from 'node:process'

const temp = await mkdtemp(join(tmpdir(), 'augma-packages-'))
function run(command, args, cwd = process.cwd()) {
  const r = spawnSync(command, args, { cwd, stdio: 'pipe', encoding: 'utf8' })
  if (r.status !== 0)
    throw new Error(`${command} ${args.join(' ')}\n${r.stdout}\n${r.stderr}`)
  return r.stdout
}
try {
  for (const dir of ['packages/core', 'packages/augma'])
    run('pnpm', ['--dir', dir, 'pack', '--pack-destination', temp])
  const files = await readdir(temp)
  const core = files.find(f => f.startsWith('augma-core-'))
  const vue = files.find(f => f.startsWith('augma-0'))
  assert(core && vue, 'Both publishable packages must be packed')
  await writeFile(
    join(temp, 'package.json'),
    JSON.stringify({
      private: true,
      type: 'module',
      dependencies: {
        '@augma/core': `file:${join(temp, core)}`,
        'augma': `file:${join(temp, vue)}`,
        'vue': '3.5.43',
        '@vue/server-renderer': '3.5.43',
      },
    }),
  )
  run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund'], temp)
  const corePackage = JSON.parse(
    await readFile(join(temp, 'node_modules/@augma/core/package.json'), 'utf8'),
  )
  assert(
    !corePackage.dependencies && !corePackage.peerDependencies,
    'Core must not require a framework',
  )
  await writeFile(
    join(temp, 'verify.mjs'),
    `import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import {createSSRApp,h} from 'vue';import {renderToString} from '@vue/server-renderer';import * as augma from 'augma';const html=await renderToString(createSSRApp({render:()=>h(augma.AgmPanel,{title:'Consumer'},()=>h(augma.AgmButton,null,()=> 'Ready'))}));assert(html.includes('Ready'));assert(html.includes('agm-button'));assert.equal(Object.keys(augma).filter(k=>k.startsWith('Agm')).length,12);for(const entry of ['@augma/core/tokens.css','@augma/core/style.css','augma/style.css'])assert((await readFile(new URL(import.meta.resolve(entry)),'utf8')).length>0);`,
  )
  run('node', ['verify.mjs'], temp)
  await writeFile(
    join(temp, 'consumer.ts'),
    'import { AgmButton, AgmDialog, AgmSlider } from \'augma\'\nimport { h } from \'vue\'\nh(AgmButton, { variant: \'outline\' })\nh(AgmDialog, { title: \'Settings\', description: \'Configure\' })\nh(AgmSlider, { label: \'Opacity\', modelValue: 72 })\n',
  )
  run(
    resolve('node_modules/.bin/tsc'),
    [
      '--noEmit',
      '--skipLibCheck',
      '--strict',
      '--module',
      'ESNext',
      '--moduleResolution',
      'bundler',
      '--target',
      'ES2022',
      'consumer.ts',
    ],
    temp,
  )
  console.log(
    'Passed: npm tarballs, CSS-only dependency boundary, 12 public exports, SSR rendering and consumer TypeScript.',
  )
}
finally {
  await rm(temp, { recursive: true, force: true })
}
