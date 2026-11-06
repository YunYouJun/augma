/* eslint test/no-import-node-test: off -- Distribution tooling uses Node's standalone test runner. */
import assert from 'node:assert/strict'
import { Buffer } from 'node:buffer'
import { createHash } from 'node:crypto'
import { cp, mkdtemp, readdir, readFile, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { buildPluginCatalog, packPlugin, validPluginPath } from '../../scripts/build-plugin-catalog.mjs'

async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'augma-catalog-test-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  const project = join(root, 'plugins/breathing-orbit')
  await cp(new URL('../../plugins/breathing-orbit', import.meta.url), project, { recursive: true })
  return { root, project, pluginsRoot: join(root, 'plugins'), output: join(root, 'public/plugins') }
}

test('catalog and portable plugin packages are reproducible and content addressed', async (t) => {
  const f = await fixture(t)
  const first = await buildPluginCatalog(f)
  const catalog = await readFile(join(f.output, 'catalog.json'))
  await buildPluginCatalog(f)
  assert.deepEqual(await readFile(join(f.output, 'catalog.json')), catalog)
  assert.equal(first.plugins.length, 1)
  const entry = first.plugins[0]
  const archive = await readFile(join(f.output, entry.packageURL))
  assert.equal(entry.size, archive.length)
  assert.equal(entry.sha256, createHash('sha256').update(archive).digest('hex'))
  assert.match(entry.packageURL, new RegExp(`/${entry.manifest.version.replaceAll('.', '\\.')}/${entry.sha256}\\.augmaplugin\\.json$`))
  const decoded = JSON.parse(archive)
  assert.equal(decoded.format, 'augma-web-plugin')
  assert.equal(decoded.schemaVersion, 1)
  assert.equal(decoded.files.length, 4)
  const manifest = JSON.parse(Buffer.from(decoded.files.find(file => file.path === 'augma-plugin.json').data, 'base64'))
  assert.deepEqual(manifest, entry.manifest)
  assert.match(Buffer.from(decoded.files.find(file => file.path === 'main.js').data, 'base64').toString(), /requestAnimationFrame/)
})

test('workspace and manifest versions must agree and native permissions are rejected', async (t) => {
  const f = await fixture(t)
  const manifestPath = join(f.project, 'BreathingOrbit.augmaplugin/augma-plugin.json')
  const original = JSON.parse(await readFile(manifestPath))
  await writeFile(manifestPath, JSON.stringify({ ...original, version: '2.0.0' }))
  await assert.rejects(packPlugin(f.project), /versions must agree/)
  await writeFile(manifestPath, JSON.stringify({ ...original, permissions: ['shell'] }))
  await assert.rejects(packPlugin(f.project), /permissions/)
})

test('localized catalog metadata is bounded and validates display text', async (t) => {
  const f = await fixture(t)
  const path = join(f.project, 'BreathingOrbit.augmaplugin/augma-plugin.json')
  const original = JSON.parse(await readFile(path))
  assert.equal((await packPlugin(f.project)).manifest.localizations['en-US'].name, 'Breathing Orbit')
  await writeFile(path, JSON.stringify({ ...original, localizations: { 'en-US': { name: '', summary: 'Summary' } } }))
  await assert.rejects(packPlugin(f.project), /localized name/)
  await writeFile(path, JSON.stringify({ ...original, localizations: { fr: { name: 'Example', summary: '' } } }))
  await assert.rejects(packPlugin(f.project), /Unsupported metadata language/)
})

test('links and paths that escape a package are rejected', async (t) => {
  const f = await fixture(t)
  for (const path of ['../file.js', '/file.js', 'x//file.js', 'x/./file.js', 'file.js?x', 'x\\file.js', '%2e%2e/file.js'])
    assert.equal(validPluginPath(path), false, path)
  await symlink(join(f.project, 'package.json'), join(f.project, 'BreathingOrbit.augmaplugin/link.json'))
  await assert.rejects(packPlugin(f.project), /Links/)
})

test('case collisions are rejected on case-sensitive filesystems', async (t) => {
  const f = await fixture(t)
  await writeFile(join(f.project, 'BreathingOrbit.augmaplugin/MAIN.js'), 'duplicate')
  const names = await readdir(join(f.project, 'BreathingOrbit.augmaplugin'))
  if (!names.includes('MAIN.js'))
    return t.skip('The filesystem aliases MAIN.js to main.js')
  await assert.rejects(packPlugin(f.project), /Ambiguous/)
})

test('changed content gets a new immutable URL and existing artifacts stay available', async (t) => {
  const f = await fixture(t)
  const first = (await buildPluginCatalog(f)).plugins[0]
  await writeFile(join(f.project, 'BreathingOrbit.augmaplugin/main.js'), 'console.log("new package")')
  const next = (await buildPluginCatalog(f)).plugins[0]
  assert.notEqual(next.packageURL, first.packageURL)
  assert.equal(createHash('sha256').update(await readFile(join(f.output, first.packageURL))).digest('hex'), first.sha256)
  assert.equal(createHash('sha256').update(await readFile(join(f.output, next.packageURL))).digest('hex'), next.sha256)
})
