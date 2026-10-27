/* eslint test/no-import-node-test: off -- Maintainer tooling uses Node's standalone test runner. */
import assert from 'node:assert/strict'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { applicationManifest, readClientID, setupApplication, verifyApplication } from '../../scripts/microsoft-todo.mjs'

const id = '12345678-1234-1234-1234-123456789abc'

async function fixture(t, saved = '') {
  const directory = await mkdtemp(join(tmpdir(), 'augma-microsoft-test-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const config = join(directory, 'microsoft-todo.json')
  await writeFile(config, JSON.stringify({ clientId: saved }))
  return config
}

test('a fresh checkout and empty CI variable use the shared app ID', async (t) => {
  const config = await fixture(t, id)
  assert.equal(await readClientID({ config, env: {} }), id)
  assert.equal(await readClientID({ config, env: { AUGMA_MICROSOFT_CLIENT_ID: '' } }), id)
  const override = 'ABCDEF12-1234-1234-1234-123456789ABC'
  assert.equal(await readClientID({ config, env: { AUGMA_MICROSOFT_CLIENT_ID: ` ${override} ` } }), override.toLowerCase())
})

test('publishing rejects missing IDs and malformed overrides; Notes-only development stays available', async (t) => {
  const config = await fixture(t)
  await assert.rejects(readClientID({ config, env: {} }), /no shared application ID/)
  assert.equal(await readClientID({ config, env: {}, required: false }), '')
  await assert.rejects(readClientID({ config, env: { AUGMA_MICROSOFT_CLIENT_ID: 'not-an-id' }, required: false }), /Invalid/)
  await assert.rejects(readClientID({ config, env: { AUGMA_MICROSOFT_CLIENT_ID: '00000000-0000-0000-0000-000000000000' } }), /Invalid/)
})

test('configuration refuses credential fields instead of bundling them', async (t) => {
  const config = await fixture(t, id)
  await writeFile(config, JSON.stringify({ clientId: id, clientSecret: 'test-fixture' }))
  await assert.rejects(readClientID({ config, env: {} }), /only the public clientId/)
})

test('setup creates once, persists only its public ID, and verifies on rerun', async (t) => {
  const config = await fixture(t)
  const app = { appId: id, ...applicationManifest() }
  const calls = []
  const run = (args) => {
    calls.push(args)
    if (args.includes('list'))
      return []
    return app
  }
  assert.equal(await setupApplication({ config, run }), id)
  assert.deepEqual(JSON.parse(await readFile(config, 'utf8')), { clientId: id })
  const creation = calls.find(args => args.includes('POST'))
  const body = JSON.parse(creation[creation.indexOf('--body') + 1])
  assert.equal(body.requiredResourceAccess[0].resourceAccess.every(scope => scope.type === 'Scope'), true)
  assert.equal('passwordCredentials' in body, false)
  calls.length = 0
  assert.equal(await setupApplication({ config, run }), id)
  assert.deepEqual(calls, [['ad', 'app', 'show', '--id', id]])
})

test('setup recovers a prior creation and never guesses between duplicate registrations', async (t) => {
  const config = await fixture(t)
  const app = { appId: id, ...applicationManifest() }
  assert.equal(await setupApplication({ config, run: () => [app] }), id)
  await writeFile(config, JSON.stringify({ clientId: '' }))
  await assert.rejects(setupApplication({ config, run: () => [app, app] }), /Multiple owned/)
})

test('an incompatible registration is rejected without changing the saved ID', async (t) => {
  const config = await fixture(t)
  const app = { appId: id, ...applicationManifest() }
  assert.throws(() => verifyApplication({ ...app, publicClient: { redirectUris: [] } }), /redirect URI/)
  assert.throws(() => verifyApplication({ ...app, requiredResourceAccess: [] }), /delegated permission/)
  await assert.rejects(setupApplication({ id, config, run: () => ({ ...app, signInAudience: 'AzureADMyOrg' }) }), /personal Microsoft accounts/)
  assert.deepEqual(JSON.parse(await readFile(config, 'utf8')), { clientId: '' })
})

test('a portal manifest can be imported without CLI authentication or persisting its other fields', async (t) => {
  const config = await fixture(t)
  const manifest = { appId: id, ...applicationManifest(), passwordCredentials: [{ secretText: 'fixture-only' }] }
  assert.equal(await setupApplication({ config, manifest, run: () => assert.fail('Manifest import must not call Azure CLI') }), id)
  assert.deepEqual(JSON.parse(await readFile(config, 'utf8')), { clientId: id })
})
