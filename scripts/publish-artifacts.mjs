import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { resolve } from 'node:path'
import process from 'node:process'
import { pathToFileURL } from 'node:url'
import { fetchRegistryMetadata } from './check-published.mjs'
import { currentCommit, verifyArtifacts } from './release-artifacts.mjs'

// npm never lets a version be replaced, so a re-run (or a package whose first version was
// published by hand) must skip what is already public — but only when the public tarball is
// exactly the verified artifact. Anything else stops the release before a single publish.
export function publishAction(metadata, pkg) {
  const published = metadata.versions?.[pkg.version]
  if (!published)
    return 'publish'
  assert.equal(
    published.dist?.integrity,
    pkg.integrity,
    `${pkg.name}@${pkg.version} is already public with a different tarball; do not republish this version`,
  )
  return 'skip'
}

function npmPublish(file) {
  execFileSync('npm', ['publish', file, '--access', 'public', '--provenance'], { stdio: 'inherit' })
}

export async function publishArtifacts(directory, commit, { fetchMetadata = fetchRegistryMetadata, publish = npmPublish, log = console.log } = {}) {
  const manifest = await verifyArtifacts(directory, commit)
  // Decide for every package first, so a mismatch on Vue cannot follow a fresh Core publish.
  const plan = []
  for (const pkg of manifest.packages)
    plan.push({ pkg, action: publishAction(await fetchMetadata(pkg.name), pkg) })
  for (const { pkg, action } of plan) {
    if (action === 'publish')
      publish(resolve(directory, pkg.filename))
    log(`${action === 'publish' ? 'Published' : 'Skipped (already public, integrity matches)'} ${pkg.name}@${pkg.version}`)
  }
  return plan.map(({ pkg, action }) => ({ name: pkg.name, action }))
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  assert.equal(process.argv.length, 2, 'Usage: node scripts/publish-artifacts.mjs')
  await publishArtifacts(resolve('release-artifacts'), currentCommit())
}
