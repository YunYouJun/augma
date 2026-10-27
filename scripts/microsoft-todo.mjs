// Maintainer setup: pnpm mac:setup-todo [--client-id <registered app ID>]
// Azure CLI keeps authentication in its own local cache; only the public app ID is saved here.
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath, pathToFileURL } from 'node:url'

const configURL = new URL('../apps/mac/Config/microsoft-todo.json', import.meta.url)
const graphAppID = '00000003-0000-0000-c000-000000000000'
const tasksScopeID = '2219042f-cab5-40cc-b0d2-16b1540b4c5f'
const offlineScopeID = '7427e0e9-2fba-42fe-b0c0-848c9e6a8182'
export const redirectURI = 'msauth.cn.yunyoujun.augma.desktop-demo://auth'
const missingConfiguration = 'Microsoft To Do has no shared application ID. Run pnpm mac:setup-todo after signing in with az login --allow-no-subscriptions, or provide AUGMA_MICROSOFT_CLIENT_ID.'

export function clientID(value, { required = true } = {}) {
  assert(typeof value === 'string', 'Microsoft clientId must be a string')
  const normalized = value.trim().toLowerCase()
  if (!normalized && !required)
    return ''
  assert(normalized, missingConfiguration)
  assert(/^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/.test(normalized)
    && normalized !== '00000000-0000-0000-0000-000000000000', 'Invalid Microsoft Application (Client) ID')
  return normalized
}

export async function readClientID({ env = process.env, config = configURL, required = true } = {}) {
  // An empty CI variable must not hide the shared repository configuration.
  const override = env.AUGMA_MICROSOFT_CLIENT_ID?.trim()
  if (override)
    return clientID(override)
  const saved = JSON.parse(await readFile(config, 'utf8'))
  assert.deepEqual(Object.keys(saved), ['clientId'], 'Microsoft configuration must contain only the public clientId')
  return clientID(saved.clientId, { required })
}

export function applicationManifest() {
  return {
    displayName: 'Augma',
    signInAudience: 'AzureADandPersonalMicrosoftAccount',
    api: { requestedAccessTokenVersion: 2 },
    publicClient: { redirectUris: [redirectURI] },
    requiredResourceAccess: [{
      resourceAppId: graphAppID,
      resourceAccess: [tasksScopeID, offlineScopeID].map(id => ({ id, type: 'Scope' })),
    }],
  }
}

export function verifyApplication(app) {
  const id = clientID(app.appId)
  assert.equal(app.signInAudience, 'AzureADandPersonalMicrosoftAccount', 'The app must support both organizational and personal Microsoft accounts')
  assert(app.publicClient?.redirectUris?.includes(redirectURI), 'The app must register the Augma redirect URI under a mobile/desktop public-client platform')
  const graphAccess = app.requiredResourceAccess?.filter(resource => resource.resourceAppId === graphAppID)
    .flatMap(resource => resource.resourceAccess ?? []) ?? []
  assert(graphAccess.some(scope => scope.id === tasksScopeID && scope.type === 'Scope'), 'The app needs Microsoft Graph Tasks.ReadWrite delegated permission')
  return id
}

function azure(args) {
  try {
    const output = execFileSync('az', [...args, '--only-show-errors', '--output', 'json'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    return output.trim() ? JSON.parse(output) : undefined
  }
  catch (error) {
    if (error.code === 'ENOENT')
      throw new Error('Install the official Azure CLI first: https://learn.microsoft.com/cli/azure/install-azure-cli')
    // Avoid dumping CLI output, which may contain account or authentication details.
    throw new Error('Microsoft application setup failed. Check Azure CLI login, selected tenant and app registration permissions. Use az login --allow-no-subscriptions --tenant <your-tenant-id>.')
  }
}

export async function setupApplication({ id, manifest, config = configURL, run = azure } = {}) {
  if (manifest) {
    const selected = verifyApplication(manifest)
    await writeFile(config, `${JSON.stringify({ clientId: selected }, null, 2)}\n`)
    return selected
  }
  let selected = id ? clientID(id) : await readClientID({ env: {}, config, required: false })
  if (!selected) {
    // Recover an earlier creation if the process stopped before saving its ID.
    const owned = run(['ad', 'app', 'list', '--show-mine', '--filter', 'displayName eq \'Augma\'', '--all'])
    assert(owned.length <= 1, 'Multiple owned Augma registrations exist. Select one with --client-id <ID>.')
    if (owned.length) {
      selected = verifyApplication(owned[0])
    }
    else {
      const app = run(['rest', '--method', 'POST', '--url', 'https://graph.microsoft.com/v1.0/applications', '--headers', 'Content-Type=application/json', '--body', JSON.stringify(applicationManifest())])
      // Save immediately after successful creation so reruns cannot create duplicates.
      selected = verifyApplication(app)
    }
  }
  else {
    selected = verifyApplication(run(['ad', 'app', 'show', '--id', selected]))
  }
  await writeFile(config, `${JSON.stringify({ clientId: selected }, null, 2)}\n`)
  return selected
}

async function main(args) {
  const [command, ...options] = args
  if (command === 'setup') {
    assert(options.length === 0 || (options.length === 2 && ['--client-id', '--manifest'].includes(options[0])), 'Usage: pnpm mac:setup-todo [--client-id <ID> | --manifest <Microsoft Graph application manifest.json>]')
    const manifest = options[0] === '--manifest' ? JSON.parse(await readFile(options[1], 'utf8')) : undefined
    const id = await setupApplication({ id: options[0] === '--client-id' ? options[1] : undefined, manifest })
    console.log(`Configured the shared Augma Microsoft application: ${id}\nSaved ${fileURLToPath(configURL)}. Rebuild with pnpm mac:run; users can then sign in directly.`)
  }
  else if (command === 'client-id' || command === 'check') {
    assert(options.length === 0 || (command === 'client-id' && options.length === 1 && options[0] === '--allow-missing'), 'Unknown Microsoft configuration option')
    const id = await readClientID({ required: !options.includes('--allow-missing') })
    console.log(command === 'check' ? `Microsoft To Do build configuration is ready (${id}).` : id)
  }
  else {
    throw new Error('Usage: node scripts/microsoft-todo.mjs <setup|check|client-id>')
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await main(process.argv.slice(2))
  }
  catch (error) {
    console.error(error.message)
    process.exitCode = 1
  }
}
