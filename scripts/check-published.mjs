import assert from 'node:assert/strict'
import { resolve } from 'node:path'
import process from 'node:process'
import { setTimeout } from 'node:timers/promises'
import { pathToFileURL } from 'node:url'
import { currentCommit, verifyArtifacts } from './release-artifacts.mjs'

export function verifyPublishedMetadata(metadata, pkg) {
  const published = metadata.versions?.[pkg.version]
  assert(published, `${pkg.name}@${pkg.version} is not publicly available`)
  assert.equal(published.name, pkg.name)
  assert.equal(published.version, pkg.version)
  assert.equal(published.dist?.integrity, pkg.integrity, `${pkg.name}: public tarball differs from the verified artifact`)
  assert.equal(metadata['dist-tags']?.latest, pkg.version, `${pkg.name}: latest does not point to the release`)
}

/** Public registry metadata for a package; an unpublished package reads as `{}`. */
export async function fetchRegistryMetadata(name) {
  const response = await fetch(`https://registry.npmjs.org/${encodeURIComponent(name)}`, {
    signal: AbortSignal.timeout(15000),
    headers: { 'Cache-Control': 'no-cache' },
  })
  assert(response.ok || response.status === 404, `${name}: registry returned HTTP ${response.status}`)
  return response.ok ? response.json() : {}
}

// npm can take several minutes before a fresh version (or a brand-new package) is
// readable, so poll for up to ten minutes before treating it as missing.
const POLL_ATTEMPTS = 40
const POLL_INTERVAL = 15_000

async function check() {
  const manifest = await verifyArtifacts(resolve('release-artifacts'), currentCommit())
  for (const pkg of manifest.packages) {
    for (let attempt = 1; ; attempt++) {
      const metadata = await fetchRegistryMetadata(pkg.name)
      const visible = metadata.versions?.[pkg.version] && metadata['dist-tags']?.latest === pkg.version
      if (visible || attempt === POLL_ATTEMPTS) {
        verifyPublishedMetadata(metadata, pkg)
        break
      }
      await setTimeout(POLL_INTERVAL)
    }
    console.log(`Verified ${pkg.name}@${pkg.version}: public version, latest tag and artifact integrity.`)
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  await check()
