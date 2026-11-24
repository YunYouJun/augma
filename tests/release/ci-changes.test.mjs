/* eslint test/no-import-node-test: off -- CI path classification is verified with Node's standalone test runner. */
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { classifyChanges } from '../../scripts/ci-changes.mjs'

test('pure native changes skip web verification and run macOS checks', () => {
  assert.deepEqual(
    classifyChanges([
      'apps/mac/Sources/AugmaDesktopDemo/ImmersiveViews.swift',
      'apps/mac/Localization/en.lproj/Localizable.strings',
      'packages/augma-ui/Sources/AugmaUI/AugmaOrbControl.swift',
      'script/build_and_run.sh',
    ]),
    { web: false, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('pure web and site changes run web verification and skip macOS checks', () => {
  assert.deepEqual(
    classifyChanges([
      'packages/core/src/style.css',
      'packages/augma/src/components/AgmButton.vue',
      'apps/site/design/index.md',
    ]),
    { web: true, mac: false, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('shared design tokens trigger both web and macOS checks', () => {
  assert.deepEqual(
    classifyChanges([
      'packages/core/src/tokens.json',
      'packages/core/src/tokens.css',
      'packages/augma-ui/Sources/AugmaUI/AugmaTokens.swift',
    ]),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('mac markdown docs still lint via web job without triggering Swift tests', () => {
  assert.deepEqual(
    classifyChanges(['apps/mac/README.md']),
    { web: true, mac: false, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('linted native config and helper scripts run both web lint and macOS checks', () => {
  assert.deepEqual(
    classifyChanges([
      'apps/mac/Config/microsoft-todo.json',
      'script/verify-craft-hub.mjs',
    ]),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('workflow edits route ci.yml to both jobs and release.yml only to web lint', () => {
  assert.deepEqual(
    classifyChanges(['.github/workflows/ci.yml']),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
  assert.deepEqual(
    classifyChanges(['.github/workflows/release.yml']),
    { web: true, mac: false, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('missing or empty file lists fall back to running all jobs', () => {
  assert.deepEqual(
    classifyChanges(null),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
  assert.deepEqual(
    classifyChanges([]),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})

test('pull requests test Chromium only while pushes and manual runs test all three browsers', () => {
  assert.deepEqual(
    classifyChanges(['packages/core/src/style.css'], { eventName: 'pull_request' }),
    { web: true, mac: false, browsers: ['chromium'] },
  )
  assert.deepEqual(
    classifyChanges(['packages/core/src/style.css'], { eventName: 'push' }),
    { web: true, mac: false, browsers: ['chromium', 'firefox', 'webkit'] },
  )
  assert.deepEqual(
    classifyChanges(null, { eventName: 'workflow_dispatch' }),
    { web: true, mac: true, browsers: ['chromium', 'firefox', 'webkit'] },
  )
})
