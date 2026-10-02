import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import process from 'node:process'
import { pathToFileURL } from 'node:url'
import { version } from './catalog.mjs'

export const releasePackages = [
  { name: '@augma/core', directory: 'packages/core', filename: `augma-core-${version}.tgz` },
  { name: 'augma', directory: 'packages/augma', filename: `augma-${version}.tgz` },
]

const integrity = data => `sha512-${createHash('sha512').update(data).digest('base64')}`
export const currentCommit = () => execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()

export async function verifyArtifacts(directory, commit) {
  const manifest = JSON.parse(await readFile(resolve(directory, 'manifest.json'), 'utf8'))
  assert.equal(manifest.schemaVersion, 1, 'Unsupported release manifest')
  assert.equal(manifest.version, version, 'Artifact version must match the checkout')
  assert.equal(manifest.commit, commit, 'Artifacts must come from the checked-out commit')
  assert.equal(manifest.packages?.length, releasePackages.length, 'Both packages must be present')
  assert.deepEqual(
    (await readdir(directory)).sort(),
    ['manifest.json', ...releasePackages.map(pkg => pkg.filename)].sort(),
    'Artifact directory must contain only the manifest and the two expected tarballs',
  )
  for (const [index, pkg] of releasePackages.entries()) {
    const entry = manifest.packages[index]
    assert.equal(entry.name, pkg.name, 'Publish Core before Vue')
    assert.equal(entry.version, version)
    assert.equal(entry.filename, pkg.filename, 'Unexpected package filename')
    assert.equal(entry.integrity, integrity(await readFile(resolve(directory, pkg.filename))), `${pkg.name}: checksum mismatch`)
  }
  return manifest
}

async function pack() {
  assert.equal(
    execFileSync('git', ['status', '--porcelain'], { encoding: 'utf8' }).trim(),
    '',
    'Commit source changes before preparing release artifacts',
  )
  const directory = resolve('release-artifacts')
  await mkdir(directory, { recursive: true })
  const packages = []
  for (const pkg of releasePackages) {
    execFileSync('pnpm', ['--dir', pkg.directory, 'pack', '--pack-destination', directory], { stdio: 'inherit' })
    packages.push({
      name: pkg.name,
      version,
      filename: pkg.filename,
      integrity: integrity(await readFile(resolve(directory, pkg.filename))),
    })
  }
  const manifest = { schemaVersion: 1, version, commit: currentCommit(), packages }
  await writeFile(resolve(directory, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`)
  await verifyArtifacts(directory, manifest.commit)
  console.log(`Prepared and verified Augma ${version} from ${manifest.commit}. No packages were published.`)
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [command, ...extra] = process.argv.slice(2)
  assert.equal(extra.length, 0, 'Unexpected release artifact arguments')
  if (command === 'pack') {
    await pack()
  }
  else if (command === 'verify') {
    await verifyArtifacts(resolve('release-artifacts'), currentCommit())
    console.log('Release tarball names, version, commit and SHA-512 checksums verified.')
  }
  else {
    throw new Error('Usage: node scripts/release-artifacts.mjs pack|verify')
  }
}
