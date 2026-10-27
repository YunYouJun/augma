/* eslint test/no-import-node-test: off -- Maintainer tooling uses Node's standalone test runner. */
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'

const script = fileURLToPath(new URL('../../script/sign_mac_dev.sh', import.meta.url))
const development = '1111111111111111111111111111111111111111'
const other = '2222222222222222222222222222222222222222'
const distribution = '3333333333333333333333333333333333333333'

async function fixture(t) {
  const directory = await mkdtemp(join(tmpdir(), 'augma-signing-test-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  // These tests never touch the real Keychain or signing keys.
  await writeFile(join(directory, 'security'), '#!/bin/bash\nprintf "%s\\n" "$TEST_IDENTITIES"\n', { mode: 0o700 })
  await writeFile(join(directory, 'codesign'), '#!/bin/bash\nprintf "%s\\n" "$@" >> "$TEST_SIGN_LOG"\nexit "$TEST_SIGN_EXIT"\n', { mode: 0o700 })
  const config = join(directory, 'identity.local')
  const log = join(directory, 'sign.log')
  const run = (identities, extra = {}) => spawnSync('bash', [script, join(directory, 'Augma.app')], {
    encoding: 'utf8',
    timeout: 5000,
    env: {
      ...process.env,
      PATH: `${directory}:${process.env.PATH}`,
      AUGMA_CODESIGN_IDENTITY: '',
      AUGMA_CODESIGN_IDENTITY_FILE: config,
      TEST_IDENTITIES: identities,
      TEST_SIGN_LOG: log,
      TEST_SIGN_EXIT: '0',
      ...extra,
    },
  })
  return { config, log, run }
}

test('local builds pin one development certificate and keep it when more identities appear', async (t) => {
  const f = await fixture(t)
  const identities = `1) ${development} "Apple Development: Local"\n2) ${distribution} "Developer ID Application: Company"`
  const first = f.run(identities)
  assert.equal(first.status, 0, first.stderr)
  assert.equal((await readFile(f.config, 'utf8')).trim(), development)
  const second = f.run(`${identities}\n3) ${other} "Apple Development: Other"`)
  assert.equal(second.status, 0, second.stderr)
  const calls = await readFile(f.log, 'utf8')
  assert.equal(calls.match(new RegExp(development, 'g')).length, 2)
  assert.equal(calls.includes(distribution), false)
  assert.equal(calls.includes(other), false)
  assert.equal(calls.includes('--identifier\ncn.yunyoujun.augma.desktop-demo\n'), true)
  assert.equal(calls.match(/--verify\n--strict/g).length, 2)
})

test('missing, ambiguous, and stale certificates fail without silently changing identity', async (t) => {
  const f = await fixture(t)
  for (const identities of [
    '',
    `1) ${distribution} "Developer ID Application: Company"`,
    `1) ${development} "Apple Development: One"\n2) ${other} "Apple Development: Two"`,
  ]) {
    const result = f.run(identities)
    assert.equal(result.status, 1)
    assert.match(result.stderr, /stable local code-signing identity is required/)
  }
  await writeFile(f.config, development)
  const stale = f.run(`1) ${other} "Apple Development: Replacement"`)
  assert.equal(stale.status, 1)
  assert.equal(await readFile(f.config, 'utf8'), development)
  await assert.rejects(readFile(f.log), { code: 'ENOENT' })
})

test('an explicit certificate can rotate the pin, but ad-hoc and failed signing cannot', async (t) => {
  const f = await fixture(t)
  const identities = `1) ${development} "Apple Development: Local"\n2) ${other} "Augma Local Development"`
  const adhoc = f.run(identities, { AUGMA_CODESIGN_IDENTITY: '-' })
  assert.equal(adhoc.status, 1)
  const failed = f.run(identities, { TEST_SIGN_EXIT: '1' })
  assert.equal(failed.status, 1)
  await assert.rejects(readFile(f.config), { code: 'ENOENT' })
  const selected = f.run(identities, { AUGMA_CODESIGN_IDENTITY: 'Augma Local Development' })
  assert.equal(selected.status, 0, selected.stderr)
  assert.equal((await readFile(f.config, 'utf8')).trim(), other)
})
