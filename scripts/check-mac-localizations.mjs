import assert from 'node:assert/strict'
import { readdir, readFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

export function parseStrings(source) {
  const result = new Map()
  for (const match of source.matchAll(/("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*")\s*;/g)) {
    const key = JSON.parse(match[1])
    assert(!result.has(key), `Duplicate translation: ${key}`)
    result.set(key, JSON.parse(match[2]))
  }
  return result
}

export function localizationKeys(source) {
  // Interpolated Swift literals are covered by runtime tests; static UI copy must have a resource.
  const calls = /\b(?:Text|Button|Label|Menu|Picker|Toggle|Section|GroupBox|ContentUnavailableView|Window|WindowGroup|TextField|SecureField|ProgressView|LabeledContent|NavigationLink|text|help|accessibilityLabel|accessibilityHint|accessibilityValue|navigationTitle|navigationSubtitle|confirmationDialog|alert)\(\s*("(?:\\.|[^"\\])*")|String\(appLocalized:\s*("(?:\\.|[^"\\])*")/g
  return [...source.matchAll(calls)].flatMap((match) => {
    const raw = match[1] ?? match[2]
    return raw.includes('\\(') ? [] : [JSON.parse(raw)]
  }).filter(key => /\p{Script=Han}/u.test(key))
}

const placeholders = text => [...text.replaceAll('%%', '').matchAll(/%(?:\d+\$)?[-+# ]*\d*(?:\.\d+)?(?:hh|ll|[hlztjL])?[@diuoxXfFeEgGaAcCsSp]/g)].map(match => match[0])

export async function checkMacLocalizations(project = root) {
  const catalogs = {}
  const permissionCopy = {}
  for (const language of ['zh-Hans', 'en', 'ja']) {
    catalogs[language] = parseStrings(await readFile(join(project, `apps/mac/Localization/${language}.lproj/Localizable.strings`), 'utf8'))
    permissionCopy[language] = parseStrings(await readFile(join(project, `apps/mac/Localization/${language}.lproj/InfoPlist.strings`), 'utf8'))
  }
  for (const [language, catalog] of Object.entries(catalogs)) {
    assert.deepEqual([...catalog.keys()].sort(), [...catalogs['zh-Hans'].keys()].sort(), `${language}: translation keys differ`)
    for (const [key, value] of catalog) {
      assert(value.length > 0, `${language}: empty translation: ${key}`)
      assert.deepEqual(placeholders(value), placeholders(key), `${language}: incompatible placeholders: ${key}`)
      if (language === 'en')
        assert(!/\p{Script=Han}/u.test(value), `en: untranslated Chinese: ${key}`)
    }
  }
  for (const [language, catalog] of Object.entries(permissionCopy)) {
    assert.deepEqual([...catalog.keys()].sort(), [...permissionCopy['zh-Hans'].keys()].sort(), `${language}: permission explanation keys differ`)
    for (const [key, value] of catalog) {
      assert(value.length > 0, `${language}: empty permission explanation: ${key}`)
      if (language === 'en')
        assert(!/\p{Script=Han}/u.test(value), `en: untranslated permission explanation: ${key}`)
    }
  }
  let checked = 0
  async function walk(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name)
      if (entry.isDirectory()) {
        await walk(path)
      }
      else if (entry.name.endsWith('.swift')) {
        const source = await readFile(path, 'utf8')
        if (entry.name !== 'NativeLocalization.swift')
          assert(!source.includes('String(localized:') && !source.includes('NSLocalizedString('), `${path}: bypasses the selected app language`)
        for (const key of localizationKeys(source)) {
          assert(catalogs.en.has(key), `${path}: missing English translation: ${key}`)
          checked++
        }
      }
    }
  }
  await walk(join(project, 'apps/mac/Sources'))
  return { entries: catalogs.en.size, references: checked }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const result = await checkMacLocalizations()
  console.log(`macOS localization OK: ${result.entries} keys, ${result.references} static references, three languages`)
}
