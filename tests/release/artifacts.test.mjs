/* eslint test/no-import-node-test: off -- Release tooling is verified with Node's standalone test runner. */
import assert from 'node:assert/strict'
import { Buffer } from 'node:buffer'
import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import process from 'node:process'
import { test } from 'node:test'
import { version } from '../../scripts/catalog.mjs'
import { verifyPublishedMetadata } from '../../scripts/check-published.mjs'
import { releasePackages, verifyArtifacts } from '../../scripts/release-artifacts.mjs'

const commit = 'a'.repeat(40)
async function fixture(t) {
  const directory = await mkdtemp(join(tmpdir(), 'augma-release-test-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const packages = []
  for (const pkg of releasePackages) {
    const data = Buffer.from(`tarball fixture: ${pkg.name}`)
    await writeFile(join(directory, pkg.filename), data)
    packages.push({ name: pkg.name, version, filename: pkg.filename, integrity: `sha512-${createHash('sha512').update(data).digest('base64')}` })
  }
  const manifest = { schemaVersion: 1, version, commit, packages }
  await writeFile(join(directory, 'manifest.json'), JSON.stringify(manifest))
  return { directory, manifest }
}

test('verified artifacts reject a different commit, changed bytes and extra tarballs', async (t) => {
  const { directory, manifest } = await fixture(t)
  assert.deepEqual(await verifyArtifacts(directory, commit), manifest)
  await assert.rejects(verifyArtifacts(directory, 'b'.repeat(40)), /checked-out commit/)
  await writeFile(join(directory, 'unexpected.tgz'), 'extra')
  await assert.rejects(verifyArtifacts(directory, commit), /two expected tarballs/)
  await rm(join(directory, 'unexpected.tgz'))
  await writeFile(join(directory, manifest.packages[0].filename), 'modified')
  await assert.rejects(verifyArtifacts(directory, commit), /checksum mismatch/)
})

test('manifest rejects missing packages and unexpected filenames', async (t) => {
  const { directory, manifest } = await fixture(t)
  manifest.packages[0].filename = '../foreign.tgz'
  await writeFile(join(directory, 'manifest.json'), JSON.stringify(manifest))
  await assert.rejects(verifyArtifacts(directory, commit), /Unexpected package filename/)
  manifest.packages.pop()
  await writeFile(join(directory, 'manifest.json'), JSON.stringify(manifest))
  await assert.rejects(verifyArtifacts(directory, commit), /Both packages/)
})

test('public verification rejects missing versions, incorrect dist-tags and different tarballs', async (t) => {
  const { manifest } = await fixture(t)
  const pkg = manifest.packages[0]
  assert.throws(() => verifyPublishedMetadata({}, pkg), /not publicly available/)
  const metadata = { 'versions': { [version]: { name: pkg.name, version, dist: { integrity: pkg.integrity } } }, 'dist-tags': { latest: version } }
  verifyPublishedMetadata(metadata, pkg)
  metadata['dist-tags'].latest = '0.1.1'
  assert.throws(() => verifyPublishedMetadata(metadata, pkg), /latest/)
  metadata['dist-tags'].latest = version
  metadata.versions[version].dist.integrity = 'sha512-different'
  assert.throws(() => verifyPublishedMetadata(metadata, pkg), /differs/)
})

test('prepare mode permits branches but publishing requires the exact version tag', () => {
  const run = (ref, args = []) => spawnSync(process.execPath, ['scripts/check-release.mjs', ...args], { env: { ...process.env, GITHUB_REF: ref }, encoding: 'utf8' })
  assert.equal(run('refs/heads/dev', ['--prepare']).status, 0)
  assert.equal(run(`refs/tags/v${version}`).status, 0)
  assert.notEqual(run('refs/heads/dev').status, 0)
  assert.notEqual(run('refs/tags/v9.9.9').status, 0)
  assert.notEqual(run('refs/heads/dev', ['--unknown']).status, 0)
})
