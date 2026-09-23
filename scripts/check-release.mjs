import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import process from 'node:process'
import { version } from './catalog.mjs'

for (const path of [
  'package.json',
  'packages/core/package.json',
  'packages/augma/package.json',
]) {
  const pkg = JSON.parse(await readFile(path, 'utf8'))
  assert.equal(pkg.version, version, `${path}: version mismatch`)
}
assert.equal(
  process.env.GITHUB_REF,
  `refs/tags/v${version}`,
  'Publish only a matching release tag',
)
console.log(
  `Release v${version} matches the workspace, packages and component contract.`,
)
