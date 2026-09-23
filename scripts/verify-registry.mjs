import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import {
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  rm,
  writeFile,
} from 'node:fs/promises'
import { createServer } from 'node:http'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'
import { chromium } from '@playwright/test'
import { preview } from 'vite'
import { components, version } from './catalog.mjs'

const exec = promisify(execFile)
const temp = await mkdtemp(join(tmpdir(), 'augma-registry-'))
const run = (cmd, args, cwd = temp) =>
  exec(cmd, args, {
    cwd,
    maxBuffer: 10 * 1024 * 1024,
    env: { ...process.env, CI: 'true' },
  })
let server
let consumerServer
let browser
try {
  await run('pnpm', [
    '--dir',
    resolve('packages/core'),
    'pack',
    '--pack-destination',
    temp,
  ])
  const archive = (await readdir(temp)).find(f => f.endsWith('.tgz'))
  const tarball = await readFile(join(temp, archive))
  const manifest = JSON.parse(
    await readFile('packages/core/package.json', 'utf8'),
  )
  let base
  server = createServer(async (req, res) => {
    try {
      const path = decodeURIComponent(new URL(req.url, base).pathname)
      if (path === '/@augma/core') {
        res.setHeader('Content-Type', 'application/json')
        res.end(
          JSON.stringify({
            'name': '@augma/core',
            'dist-tags': { latest: version },
            'versions': {
              [version]: { ...manifest, dist: { tarball: `${base}/core.tgz` } },
            },
          }),
        )
        return
      }
      if (path === '/core.tgz') {
        res.setHeader('Content-Type', 'application/octet-stream')
        res.end(tarball)
        return
      }
      const item = components.find(
        c => c.registry && path === `/r/${c.slug}.json`,
      )
      if (!item) {
        res.writeHead(404)
        res.end()
        return
      }
      res.setHeader('Content-Type', 'application/json')
      res.end(await readFile(`apps/site/public/r/${item.slug}.json`))
    }
    catch {
      res.writeHead(500)
      res.end()
    }
  })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  base = `http://127.0.0.1:${server.address().port}`
  await mkdir(join(temp, 'src'), { recursive: true })
  await writeFile(join(temp, '.npmrc'), `@augma:registry=${base}/\n`)
  await writeFile(
    join(temp, 'package.json'),
    JSON.stringify({
      name: 'augma-registry-consumer',
      private: true,
      type: 'module',
      dependencies: { vue: '3.5.43' },
      devDependencies: {
        'vite': '8.3.0',
        'typescript': '5.9.3',
        '@vitejs/plugin-vue': '6.0.9',
      },
    }),
  )
  await writeFile(
    join(temp, 'components.json'),
    JSON.stringify({
      $schema: 'https://shadcn-vue.com/schema.json',
      style: 'default',
      typescript: true,
      tailwind: {
        config: 'tailwind.config.js',
        css: 'src/style.css',
        baseColor: 'slate',
        cssVariables: true,
      },
      aliases: {
        components: '@/components',
        utils: '@/lib/utils',
        ui: '@/components/ui',
        lib: '@/lib',
        composables: '@/composables',
      },
    }),
  )
  await writeFile(
    join(temp, 'tsconfig.json'),
    JSON.stringify({
      compilerOptions: {
        target: 'ES2022',
        module: 'ESNext',
        moduleResolution: 'bundler',
        strict: true,
        skipLibCheck: true,
        baseUrl: '.',
        paths: { '@/*': ['./src/*'] },
        lib: ['ES2022', 'DOM'],
      },
      include: ['src/**/*.ts', 'src/**/*.vue'],
    }),
  )
  await writeFile(
    join(temp, 'tailwind.config.js'),
    'export default { content: [] }\n',
  )
  await writeFile(
    join(temp, 'src/style.css'),
    '@import \'@augma/core/style.css\';\n',
  )
  await writeFile(
    join(temp, 'index.html'),
    '<div id="app"></div><script type="module" src="/src/main.ts"></script>',
  )
  await writeFile(
    join(temp, 'vite.config.mjs'),
    'import {defineConfig} from \'vite\';import vue from \'@vitejs/plugin-vue\';export default defineConfig({plugins:[vue()]})',
  )
  await run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund'])
  const cli = fileURLToPath(import.meta.resolve('shadcn-vue'))
  for (const item of components.filter(c => c.registry)) {
    await run('node', [
      cli,
      'add',
      `${base}/r/${item.slug}.json`,
      '--yes',
      '--overwrite',
      '--cwd',
      temp,
    ])
  }
  const generated = []
  async function scan(dir) {
    for (const e of await readdir(dir, { withFileTypes: true })) {
      const p = join(dir, e.name)
      if (e.isDirectory())
        await scan(p)
      else if (e.name.endsWith('.vue'))
        generated.push(p)
    }
  }
  await scan(join(temp, 'src'))
  assert.equal(
    generated.length,
    6,
    'CLI must install all six complete components',
  )
  const imports = generated
    .map(
      (p, i) =>
        `import C${i} from './${p.slice(join(temp, 'src').length + 1)}'`,
    )
    .join('\n')
  await writeFile(
    join(temp, 'src/main.ts'),
    `${imports}\nimport {createApp,h} from 'vue'\nimport './style.css'\ncreateApp({render:()=>h('div',{},[${generated.map((_, i) => `h(C${i}, {label:'Consumer',title:'Panel',description:'Example'})`).join(',')}])}).mount('#app')`,
  )
  await run(resolve('node_modules/.bin/vue-tsc'), [
    '--noEmit',
    '-p',
    join(temp, 'tsconfig.json'),
  ])
  await run(join(temp, 'node_modules/.bin/vite'), ['build'])
  consumerServer = await preview({ root: temp, preview: { host: '127.0.0.1', port: 0, open: false } })
  browser = await chromium.launch()
  const page = await browser.newPage()
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto(`http://127.0.0.1:${consumerServer.httpServer.address().port}/`)
  await page.locator('.agm-button').waitFor({ state: 'visible' })
  const background = await page.locator('.agm-button').evaluate(element => getComputedStyle(element, '::before').backgroundColor)
  assert(!['rgba(0, 0, 0, 0)', 'transparent'].includes(background), 'Installed Registry source must render with Core CSS')
  await page.getByRole('textbox', { name: 'Consumer' }).fill('Editable source')
  assert.equal(await page.getByRole('textbox', { name: 'Consumer' }).inputValue(), 'Editable source')
  assert.deepEqual(errors, [])
  console.log(
    'Passed: actual shadcn-vue CLI installed all 6 Registry entries in a clean Vue project; consumer types, production build, rendered CSS and input interaction passed.',
  )
}
finally {
  await browser?.close()
  if (consumerServer)
    await new Promise(resolve => consumerServer.httpServer.close(resolve))
  if (server)
    await new Promise(resolve => server.close(resolve))
  await rm(temp, { recursive: true, force: true })
}
