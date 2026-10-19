import type { SFCDescriptor } from '@vue/compiler-sfc'
import { parse } from '@vue/compiler-sfc'
import { describe, expect, it } from 'vitest'

type TemplateNode = NonNullable<NonNullable<SFCDescriptor['template']>['ast']>['children'][number]

// The Chinese examples are the source; the docs show a translated copy from examples/<locale>/ on /en/ and /ja/.
const sources = Object.fromEntries(
  Object.entries(import.meta.glob<string>('../../examples/**/*.vue', { query: '?raw', import: 'default', eager: true }))
    .map(([path, source]) => [path.replace('../../examples/', ''), source]),
)
const locales = ['en-US', 'ja-JP'] as const
const originals = Object.keys(sources).filter(path => !locales.some(locale => path.startsWith(`${locale}/`)))
// A translation may add these to replace a component's built-in Chinese default, such as AgmSelect's 请选择
// or AgmDialog's 关闭对话框. The Chinese examples rely on the defaults, so they leave these out.
const translationOnly = new Set(['placeholder', 'indeterminate-text', 'close-label', 'region-label'])
const han = /\p{Script=Han}/u
const languages = {
  'en-US': /^\P{Script=Han}*$/u,
  'ja-JP': /[\p{Script=Hiragana}\p{Script=Katakana}]/u,
}

function tokenize(code: string) {
  return (code.match(/\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`|[\w$]+|\S/g) ?? [])
    .filter(token => !token.startsWith('//') && !token.startsWith('/*'))
}

function walk(node: TemplateNode, tokens: string[]) {
  if ('tag' in node) {
    tokens.push(`<${node.tag}`)
    for (const prop of node.props) {
      if (!('value' in prop))
        tokens.push(prop.rawName ?? prop.name, ...tokenize(prop.exp?.loc.source ?? ''))
      else if (!translationOnly.has(prop.name))
        tokens.push(prop.name, ...(prop.value ? [`"${prop.value.content}"`] : []))
    }
    tokens.push('>')
    for (const child of node.children)
      walk(child, tokens)
    tokens.push(`</${node.tag}>`)
  }
  // Interpolations count; plain text is copy and may be reworded freely.
  else if (node.loc.source.startsWith('{{')) {
    tokens.push(...tokenize(node.loc.source))
  }
}

/** Everything but the copy: script and expression tokens, the element tree, attributes and styles. */
function skeleton(source: string) {
  const { descriptor, errors } = parse(source)
  expect(errors).toEqual([])
  const tokens = tokenize(descriptor.scriptSetup?.content ?? '')
  for (const node of descriptor.template?.ast?.children ?? [])
    walk(node, tokens)
  return { tokens, styles: descriptor.styles.map(style => [style.scoped, style.content]) }
}

describe('localized examples', () => {
  it.each(locales)('%s translates every example and nothing else', (locale) => {
    const translated = Object.keys(sources).filter(path => path.startsWith(`${locale}/`))
    expect(translated.sort()).toEqual(originals.map(path => `${locale}/${path}`).sort())
  })

  it.each(locales.flatMap(locale => originals.map(path => [locale, path] as const)))('%s keeps %s in step with the Chinese source', (locale, path) => {
    const translation = sources[`${locale}/${path}`]!
    const original = skeleton(sources[path]!)
    const { tokens, styles } = skeleton(translation)
    // Strings that hold Chinese copy may differ; every other token must match.
    const aligned = tokens.map((token, index) => {
      const source = original.tokens[index] ?? ''
      return /^['"`]/.test(token) && /^['"`]/.test(source) && han.test(source) ? source : token
    })
    expect(aligned).toEqual(original.tokens)
    expect(styles).toEqual(original.styles)
    expect(translation).toMatch(languages[locale])
  })
})
