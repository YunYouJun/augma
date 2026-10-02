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

async function check() {
  const manifest = await verifyArtifacts(resolve('release-artifacts'), currentCommit())
  for (const pkg of manifest.packages) {
    for (let attempt = 0; ; attempt++) {
      const response = await fetch(`https://registry.npmjs.org/${encodeURIComponent(pkg.name)}`, {
        signal: AbortSignal.timeout(15000),
        headers: { 'Cache-Control': 'no-cache' },
      })
      assert(response.ok || response.status === 404, `${pkg.name}: registry returned HTTP ${response.status}`)
      const metadata = response.ok ? await response.json() : {}
      if (metadata.versions?.[pkg.version] || attempt === 5) {
        verifyPublishedMetadata(metadata, pkg)
        break
      }
      await setTimeout(3000)
    }
    console.log(`Verified ${pkg.name}@${pkg.version}: public version, latest tag and artifact integrity.`)
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  await check()
