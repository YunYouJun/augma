/* eslint no-control-regex: off -- Reject control characters in untrusted package paths and metadata. */
import assert from 'node:assert/strict'
import { Buffer } from 'node:buffer'
import { createHash } from 'node:crypto'
import { lstat, mkdir, readdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const extensions = new Set(['json', 'html', 'css', 'js', 'svg', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'woff', 'woff2', 'txt'])
export const MAX_ARCHIVE_BYTES = 12 * 1024 * 1024

export function validPluginPath(path) {
  return typeof path === 'string' && path.length > 0 && path.length <= 512
    && !/[\\%:?#\u0000-\u001F\u007F]/.test(path)
    && path.split('/').every(part => part && part !== '.' && part !== '..')
    && path.split('/').length <= 8
}

export async function packPlugin(project) {
  const pkg = JSON.parse(await readFile(join(project, 'package.json'), 'utf8'))
  const source = pkg.augmaPlugin?.source
  assert(validPluginPath(source), 'Invalid augmaPlugin.source')
  const folder = join(project, source)
  assert((await lstat(folder)).isDirectory(), 'Plugin source must be a directory')
  const files = []
  const names = new Set()
  let total = 0
  let entries = 0
  async function walk(relative = '') {
    for (const name of (await readdir(join(folder, relative))).sort()) {
      const path = relative ? `${relative}/${name}` : name
      assert(validPluginPath(path), `Invalid plugin path: ${path}`)
      const info = await lstat(join(folder, path))
      assert(++entries <= 512, 'Too many package entries')
      if (info.isDirectory()) {
        await walk(path)
        continue
      }
      assert(info.isFile() && info.nlink === 1, `Links and special files are not allowed: ${path}`)
      assert(extensions.has(path.split('.').at(-1).toLowerCase()), `Unsupported file: ${path}`)
      assert(info.size <= 2 * 1024 * 1024 && files.length < 256, 'Plugin file limit exceeded')
      total += info.size
      assert(total <= 8 * 1024 * 1024, 'Plugin size limit exceeded')
      const identity = path.normalize('NFC').toLowerCase()
      assert(!names.has(identity), `Ambiguous plugin path: ${path}`)
      names.add(identity)
      files.push({ path, data: (await readFile(join(folder, path))).toString('base64') })
    }
  }
  await walk()
  const manifestFile = files.find(file => file.path === 'augma-plugin.json')
  assert(manifestFile, 'Missing augma-plugin.json')
  const manifestData = Buffer.from(manifestFile.data, 'base64')
  assert(manifestData.length <= 32 * 1024, 'Manifest is too large')
  const manifest = JSON.parse(manifestData.toString('utf8'))
  assert(manifest.schemaVersion === 1, 'Unsupported plugin schema')
  assert(typeof manifest.id === 'string' && manifest.id.length <= 160 && /^[a-z0-9]+(?:[.-][a-z0-9]+)+$/.test(manifest.id), 'Invalid plugin ID')
  assert(/^\d{1,4}\.\d{1,4}\.\d{1,4}$/.test(manifest.version) && pkg.version === manifest.version, 'Workspace and manifest versions must agree')
  for (const [key, limit] of [['name', 60], ['author', 80], ['summary', 240], ['symbol', 80]]) {
    assert(typeof manifest[key] === 'string' && (key === 'summary' || manifest[key].length > 0)
      && [...manifest[key]].length <= limit && !/[\u0000-\u001F\u007F]/.test(manifest[key]), `Invalid ${key}`)
  }
  assert(Array.isArray(manifest.permissions) && manifest.permissions.length === 0, 'Native permissions are not supported')
  assert(validPluginPath(manifest.entry) && manifest.entry.endsWith('.html') && files.some(file => file.path === manifest.entry), 'Missing or invalid entry')
  const archive = Buffer.from(`${JSON.stringify({ format: 'augma-web-plugin', schemaVersion: 1, files })}\n`)
  assert(archive.length <= MAX_ARCHIVE_BYTES, 'Archive is too large')
  return { manifest, archive, sha256: createHash('sha256').update(archive).digest('hex') }
}

export async function buildPluginCatalog({ pluginsRoot = join(root, 'plugins'), output = join(root, 'apps/site/public/plugins') } = {}) {
  const plugins = []
  for (const entry of (await readdir(pluginsRoot, { withFileTypes: true })).sort((a, b) => a.name < b.name ? -1 : 1)) {
    if (!entry.isDirectory())
      continue
    const { manifest, archive, sha256 } = await packPlugin(join(pluginsRoot, entry.name))
    assert(!plugins.some(plugin => plugin.manifest.id === manifest.id), `Duplicate plugin ID: ${manifest.id}`)
    const packageURL = `packages/${manifest.id}/${manifest.version}/${sha256}.augmaplugin.json`
    await mkdir(dirname(join(output, packageURL)), { recursive: true })
    // Content-addressed files are append-only; rerunning a build preserves existing versions.
    await writeFile(join(output, packageURL), archive)
    plugins.push({ manifest, packageURL, size: archive.length, sha256 })
  }
  assert(plugins.length <= 128, 'Catalog limit exceeded')
  const catalog = `${JSON.stringify({ schemaVersion: 1, plugins }, null, 2)}\n`
  assert(Buffer.byteLength(catalog) <= 512 * 1024, 'Catalog is too large')
  await mkdir(output, { recursive: true })
  await writeFile(join(output, 'catalog.json'), catalog)
  return { plugins, output }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const result = await buildPluginCatalog()
  console.log(`Built ${result.plugins.length} Augma Link plugins in ${result.output}`)
}
