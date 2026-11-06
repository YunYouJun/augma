/* eslint test/no-import-node-test: off -- Release checks use Node's standalone runner. */
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { checkMacLocalizations, localizationKeys, parseStrings } from '../../scripts/check-mac-localizations.mjs'

test('native UI translations cover source literals and preserve formatting', async () => {
  const result = await checkMacLocalizations()
  assert(result.entries > 1300)
  assert(result.references > 900)
})

test('coverage extracts SwiftUI and service copy while retaining escaped strings', () => {
  assert.deepEqual(localizationKeys('Button("重试") {}; Text("请点击\\"重试\\""); String(appLocalized: "返回"); Text("\\(count) 项")'), ['重试', '请点击"重试"', '返回'])
  assert.equal(parseStrings('"重试" = "Retry"; /* copy */ "引号" = "A \\"quote\\"";').get('重试'), 'Retry')
  assert.throws(() => parseStrings('"重试" = "Retry"; "重试" = "Again";'), /Duplicate/)
})
