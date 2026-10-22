// usage: node scripts/sync-app-icon.mjs [--check] [--source /path/to/YunLeFun/icons]
// assets/brand keeps a pinned copy of YunLeFun/icons assets/apps/augma/v1, so
// builds never read another checkout. --check verifies the local copy (and,
// with --source, that it matches the canonical manifest); without --check the
// canonical files are verified first and then copied over the local copy.
import { createHash } from 'node:crypto'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const snapshotRoot = path.join(root, 'assets/brand')
const canonicalPath = 'assets/apps/augma/v1'
const expectedFiles = new Set([
  'augma-app-icon.svg',
  'augma-mark.svg',
  'Augma.icon/icon.json',
  'Augma.icon/Assets/arcs.svg',
  'Augma.icon/Assets/letter.svg',
  'Augma.icon/Assets/ring.svg',
])

function readInputs(directory) {
  const manifestBytes = readFileSync(path.join(directory, 'manifest.json'))
  const manifest = JSON.parse(manifestBytes.toString('utf8'))
  if (manifest.schemaVersion !== 1 || manifest.product !== 'augma' || manifest.version !== 'v1'
    || manifest.canonical?.repository !== 'YunLeFun/icons' || manifest.canonical?.path !== canonicalPath) {
    throw new Error(`Unexpected app-icon manifest in ${directory}; this consumer is pinned to augma/v1.`)
  }
  const entries = Object.entries(manifest.files ?? {})
  if (entries.length !== expectedFiles.size || entries.some(([name]) => !expectedFiles.has(name)))
    throw new Error(`The app-icon manifest must list exactly: ${[...expectedFiles].join(', ')}.`)
  const files = entries.map(([name, hash]) => {
    if (typeof hash !== 'string' || !/^[a-f0-9]{64}$/.test(hash))
      throw new Error(`Invalid SHA-256 for ${name}.`)
    const bytes = readFileSync(path.join(directory, name))
    if (createHash('sha256').update(bytes).digest('hex') !== hash)
      throw new Error(`App-icon checksum mismatch: ${path.join(directory, name)}. Update the canonical artwork and manifest, then run pnpm icons:sync.`)
    return { name, bytes }
  })
  return { manifestBytes, files }
}

function main() {
  let check = false
  let sourceRoot
  const args = process.argv.slice(2)
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index]
    // pnpm may forward its separator to scripts.
    if (argument === '--')
      continue
    if (argument === '--check') {
      check = true
    }
    else if (argument === '--source') {
      const value = args[++index]
      if (!value || value.startsWith('--'))
        throw new Error('--source requires the path to a local YunLeFun/icons checkout.')
      sourceRoot = path.resolve(value)
    }
    else {
      throw new Error(`Unknown argument: ${argument}. Use --check and/or --source /path/to/icons.`)
    }
  }

  if (check) {
    const snapshot = readInputs(snapshotRoot)
    if (sourceRoot) {
      const canonical = readInputs(path.join(sourceRoot, canonicalPath))
      if (!snapshot.manifestBytes.equals(canonical.manifestBytes))
        throw new Error('assets/brand differs from YunLeFun/icons. Run pnpm icons:sync with the same --source.')
    }
    process.stdout.write(`Verified augma/v1 app-icon inputs${sourceRoot ? ' against YunLeFun/icons' : ' locally'}.\n`)
    return
  }

  // Sibling checkouts: ~/repos/github.com/YunYouJun/augma and .../YunLeFun/icons.
  sourceRoot ??= path.resolve(root, '../../YunLeFun/icons')
  // Validate and read every input before writing the local copy.
  const canonical = readInputs(path.join(sourceRoot, canonicalPath))
  for (const { name, bytes } of canonical.files) {
    const destination = path.join(snapshotRoot, name)
    mkdirSync(path.dirname(destination), { recursive: true })
    writeFileSync(destination, bytes)
  }
  writeFileSync(path.join(snapshotRoot, 'manifest.json'), canonical.manifestBytes)
  process.stdout.write('Synced augma/v1 from YunLeFun/icons into assets/brand.\n')
}

try {
  main()
}
catch (error) {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
}
