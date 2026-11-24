import { execFileSync } from 'node:child_process'
import { appendFileSync } from 'node:fs'
import { resolve } from 'node:path'
import process from 'node:process'
import { pathToFileURL } from 'node:url'

const lintedOrWebFile = /\.(?:[cm]?[jt]s|vue|json|ya?ml|md|css|html)$/i

function isNativeOnly(file) {
  return (file.startsWith('apps/mac/') || file.startsWith('packages/augma-ui/') || file.startsWith('script/'))
    && !lintedOrWebFile.test(file)
}

function triggersMac(file) {
  return file.startsWith('packages/augma-ui/')
    || file.startsWith('script/')
    || (file.startsWith('apps/mac/') && !file.endsWith('.md'))
    || file.startsWith('plugins/')
    || file.startsWith('assets/brand/')
    || file === 'packages/core/src/tokens.json'
    || file === 'package.json'
    || file === '.node-version'
    || file === '.github/workflows/ci.yml'
    || file === 'scripts/check-mac-localizations.mjs'
    || file === 'scripts/microsoft-todo.mjs'
    || file === 'scripts/sync-app-icon.mjs'
    || file === 'scripts/ci-changes.mjs'
    || /^tests\/release\/(?:mac-.*|microsoft-todo|ci-changes)\.test\.mjs$/.test(file)
}

export function classifyChanges(files, { eventName = 'push' } = {}) {
  const browsers = eventName === 'pull_request'
    ? ['chromium']
    : ['chromium', 'firefox', 'webkit']

  if (!files || files.length === 0)
    return { web: true, mac: true, browsers }

  return {
    web: files.some(file => !isNativeOnly(file)),
    mac: files.some(file => triggersMac(file)),
    browsers,
  }
}

function hasCommit(sha) {
  if (!sha || /^0+$/.test(sha))
    return false
  try {
    execFileSync('git', ['cat-file', '-e', `${sha}^{commit}`], { stdio: 'ignore' })
    return true
  }
  catch {
    return false
  }
}

export function listChangedFiles(env = process.env) {
  const eventName = env.GITHUB_EVENT_NAME || 'push'
  if (eventName === 'workflow_dispatch')
    return null

  let args
  if (eventName === 'pull_request') {
    const base = env.PR_BASE_SHA
    if (!hasCommit(base))
      return null
    args = ['-c', 'core.quotepath=false', 'diff', '--name-only', `${base}...HEAD`]
  }
  else if (eventName === 'push') {
    const before = env.PUSH_BEFORE_SHA
    const head = env.HEAD_SHA || 'HEAD'
    if (!hasCommit(before))
      return null
    args = ['-c', 'core.quotepath=false', 'diff', '--name-only', before, head]
  }
  else {
    return null
  }

  return execFileSync('git', args, { encoding: 'utf8' })
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const eventName = process.env.GITHUB_EVENT_NAME || 'push'
  const result = classifyChanges(listChangedFiles(process.env), { eventName })
  const lines = [
    `web=${result.web}`,
    `mac=${result.mac}`,
    `browsers=${JSON.stringify(result.browsers)}`,
  ]
  if (process.env.GITHUB_OUTPUT)
    appendFileSync(process.env.GITHUB_OUTPUT, `${lines.join('\n')}\n`)
  console.log(lines.join(' '))
}
