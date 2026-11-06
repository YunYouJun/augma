// Generate and verify the machine-readable accessibility contract for the
// native macOS app. The Swift sources are the only source of truth: every
// identifier must be declared in ax-contract.json before an agent can use it.
//
//   node scripts/generate-ax-contract.mjs              # verify (default)
//   node scripts/generate-ax-contract.mjs --write      # refresh inventory, create contract if absent
//   node scripts/generate-ax-contract.mjs --bootstrap  # sync contract from sources (merge, non-destructive)
//   node scripts/generate-ax-contract.mjs --queue      # risk-ordered review queue for reviewed:false
//
// No external dependencies. The same extraction rules are independently
// implemented in AXContractTests.swift so source drift fails the Swift suite.
//
// --bootstrap MERGES: hand-maintained scenes, reviewed entries, notes and
// element order survive. Only new identifiers are appended (derived) and
// entries no longer in source are dropped. Concurrent chats maintain this
// contract, so never rebuild it from scratch.

import assert from 'node:assert/strict'
import { readdir, readFile, writeFile } from 'node:fs/promises'
import { basename, dirname, join, relative, resolve, sep } from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SOURCES = join(ROOT, 'apps', 'mac', 'Sources')
const DOCS = join(ROOT, 'apps', 'mac', 'docs')
const CONTRACT_PATH = join(DOCS, 'ax-contract.json')
const INVENTORY_PATH = join(DOCS, 'ax-identifiers.json')

const args = new Set(process.argv.slice(2))
const mode = args.has('--queue') ? 'queue' : args.has('--bootstrap') ? 'bootstrap' : args.has('--write') ? 'write' : 'check'
for (const arg of args) {
  assert(['--bootstrap', '--write', '--check', '--queue'].includes(arg), `Unknown option: ${arg}`)
}

// Scenes whose write actions make up the smallest useful external toolset.
// Used only to suggest a first review batch, never to change the contract.
const FIRST_BATCH_SCENES = new Set([
  'main-window',
  'panel:assistant',
  'settings:assistant',
  'panel:space',
  'panel:browser',
  'panel:project-regions',
  'panel:storage-analysis',
])

const SCENES = {
  'main-window': '主窗口 Augma 布局与侧栏布局的入口控件',
  'immersive': '沉浸助手的悬浮按钮、Dock 与系统菜单',
  'panel:assistant': '文字 / 语音助手输入面板',
  'settings:assistant': '设置 → AI 助手（运行时、DSH 路径与连接测试）',
  'settings:startup': '设置 → 启动与主页',
  'settings:shortcuts': '设置 → 全局快捷键',
  'panel:browser': '内置浏览会话面板',
  'panel:space': '空间扫描、锚点与模拟路线',
  'panel:map': '地图与路线步骤',
  'panel:notifications': '通知面板',
  'panel:device': '设备面板（连接、场景、睡眠）',
  'panel:quick-capture': '快速记录草稿',
  'panel:todo': 'Microsoft To Do 捕获入口',
  'panel:project-regions': '空间 → 项目区域',
  'panel:craft-hub': 'Craft Hub 只读绑定与项目选择',
  'panel:application-district': '空间 → 应用街区',
  'panel:market': '软件中心与 Augma Link 分组',
  'panel:application-library': '应用资料库与搜索',
  'panel:plugins': 'Augma Link 扩展中心',
  'panel:system-monitor': '系统监控入口',
  'panel:storage-analysis': '系统监控 → 存储分析',
  'panel:cleanup': '系统监控 → 清理（Homebrew / 模拟器 / Codex 存储）',
}

const ROLES = ['button', 'staticText', 'textField', 'checkBox', 'popUpButton', 'slider', 'progressIndicator', 'menuButton', 'group', 'list', 'unknown']
const ACTIONS = ['press', 'setValue', 'readValue', 'select', 'focus']
const ACCESS_LEVELS = ['read', 'write']
const WRITE_ACTIONS = new Set(['press', 'setValue', 'select'])

function posix(path) {
  return path.split(sep).join('/')
}

async function swiftFiles() {
  const files = []
  async function walk(dir) {
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.'))
        continue
      const path = join(dir, entry.name)
      if (entry.isDirectory())
        await walk(path)
      else if (entry.isFile() && entry.name.endsWith('.swift'))
        files.push(path)
    }
  }
  await walk(SOURCES)
  return files.sort((a, b) => {
    const left = posix(relative(SOURCES, a))
    const right = posix(relative(SOURCES, b))
    return left < right ? -1 : left > right ? 1 : 0
  })
}

// Read the argument of `.accessibilityIdentifier(...)`, ignoring parentheses
// and quotes. The declarations in this codebase are deliberately simple.
function callArguments(source, start) {
  let depth = 0
  let quote = false
  for (let i = start; i < source.length; i += 1) {
    const char = source[i]
    if (quote) {
      if (char === '"' && source[i - 1] !== '\\')
        quote = false
      continue
    }
    if (char === '"') {
      quote = true
      continue
    }
    if (char === '(') {
      depth += 1
    }
    else if (char === ')') {
      depth -= 1
      if (depth === 0)
        return source.slice(start + 1, i)
    }
  }
  return ''
}

function literalValues(text) {
  return [...text.matchAll(/"([^"]+)"/g)].map(match => match[1])
}

function sceneFor(sourcePath, id) {
  const path = posix(relative(SOURCES, sourcePath))
  if (path.startsWith('AugmaDesktopDemo/Immersive/'))
    return 'immersive'
  if (path.startsWith('AugmaDesktopDemo/Shortcuts/'))
    return 'settings:shortcuts'
  if (path.startsWith('AugmaDesktopDemo/Preferences/'))
    return 'settings:startup'
  if (path.startsWith('AugmaDesktopDemo/Assistant/'))
    return 'settings:assistant'
  if (path.startsWith('AugmaDesktopDemo/Browser/'))
    return 'panel:browser'
  if (path.startsWith('AugmaDesktopDemo/Space/'))
    return 'panel:space'
  if (path.startsWith('AugmaDesktopDemo/Maps/'))
    return 'panel:map'
  if (path.startsWith('AugmaDesktopDemo/ProjectWorkspace/'))
    return path.includes('CraftHub') ? 'panel:craft-hub' : 'panel:project-regions'
  if (path.startsWith('AugmaDesktopDemo/ApplicationDistrict/'))
    return 'panel:application-district'
  if (path.startsWith('AugmaDesktopDemo/Market/'))
    return path.includes('Library') ? 'panel:application-library' : path.includes('Extension') ? 'panel:plugins' : 'panel:market'
  if (path.startsWith('AugmaDesktopDemo/Link/'))
    return 'panel:plugins'
  if (path.startsWith('AugmaDesktopDemo/Productivity/'))
    return path.includes('Microsoft') ? 'panel:todo' : 'panel:quick-capture'
  if (path.startsWith('AugmaDesktopDemo/SystemMonitor/Cleanup/'))
    return 'panel:cleanup'
  if (path.startsWith('AugmaDesktopDemo/SystemMonitor/DiskUsage/'))
    return 'panel:storage-analysis'
  if (path.startsWith('AugmaDesktopDemo/SystemMonitor/'))
    return 'panel:system-monitor'
  if (path.endsWith('NativeCommandView.swift'))
    return 'panel:assistant'
  if (path.endsWith('NativeUtilityPanels.swift'))
    return id.startsWith('native-notifications') ? 'panel:notifications' : 'panel:device'
  return 'main-window'
}

// Inferred from the nearest control declaration above the identifier. Derived
// entries are marked `reviewed: false` and must be checked in a running App
// before they are exposed as agent actions.
function inferControl(lines, index) {
  const windowStart = Math.max(0, index - 14)
  const context = lines.slice(windowStart, index + 3).join('\n')
  const before = lines.slice(windowStart, index + 1).join('\n')
  const patterns = [
    [/TextField\(|TextEditor\(|SecureField\(/, 'textField', ['setValue', 'readValue'], 'write', false],
    [/Slider\(/, 'slider', ['setValue', 'readValue'], 'write', false],
    [/Picker\(/, 'popUpButton', ['select', 'readValue'], 'write', false],
    [/Toggle\(/, 'checkBox', ['press', 'readValue'], 'write', false],
    [/Menu\(/, 'menuButton', ['press'], 'write', false],
    [/Button\(/, 'button', ['press'], 'write', false],
    [/ProgressView\(/, 'progressIndicator', ['readValue'], 'read', true],
    [/List\(|ForEach\(/, 'list', ['readValue'], 'read', true],
    [/Text\(|Label\(/, 'staticText', ['readValue'], 'read', true],
    [/VStack\(|HStack\(|ZStack\(|Group\(|ScrollView\(|Section\(|HStack|VStack/, 'group', ['readValue'], 'read', true],
  ]
  let picked = null
  for (const [regex, role, actions, access, idempotent] of patterns) {
    const match = [...before.matchAll(new RegExp(regex, 'g'))].at(-1)
    if (match && (!picked || match.index > picked.index))
      picked = { index: match.index, role, actions, access, idempotent }
  }
  if (!picked)
    return { role: 'unknown', actions: ['readValue'], access: 'read', idempotent: true, disabledWhen: null, label: null }
  // Only modifiers on the same chain as the control count as its state.
  const controlLine = windowStart + before.slice(0, picked.index).split('\n').length - 1
  const chain = lines.slice(controlLine, index + 1).join('\n')
  const disabled = [...chain.matchAll(/\.disabled\(/g)].at(-1)
  const disabledWhen = disabled
    ? callArguments(chain, disabled.index + disabled[0].length - 1).trim().replace(/\s+/g, ' ')
    : null
  const labelArgs = [...context.matchAll(/\.accessibilityLabel\(/g)]
    .map(match => callArguments(context, match.index + match[0].length - 1))
  const label = literalValues(labelArgs.join(' ')).at(-1) ?? null
  return {
    role: picked.role,
    actions: picked.actions,
    access: picked.access,
    idempotent: picked.idempotent,
    disabledWhen: disabledWhen || null,
    label,
  }
}

function declaration(via, sourcePath, lines, index, id, pattern = null) {
  const control = inferControl(lines, index)
  const value = pattern ?? id
  return {
    ...(pattern ? { pattern } : { id }),
    role: control.role,
    label: control.label,
    scene: sceneFor(sourcePath, value),
    actions: control.actions,
    access: control.access,
    preconditions: control.disabledWhen ? ['control is enabled'] : [],
    disabledWhen: control.disabledWhen,
    idempotent: control.idempotent,
    reviewed: false,
    declaredVia: via,
    source: posix(relative(SOURCES, sourcePath)),
    notes: 'Derived from source. Verify role, state and side effects in a running App before exposing as an agent action.',
  }
}

// Curated entries were read in the Swift source and may be issued as actions.
// Everything else stays `reviewed: false`: lookup/read only. Re-running
// --bootstrap preserves these overrides.
function curated(fields) {
  return {
    role: 'button',
    label: null,
    actions: ['press'],
    access: 'write',
    preconditions: [],
    disabledWhen: null,
    idempotent: false,
    reviewed: true,
    notes: '',
    ...fields,
  }
}

const CURATION = {
  'main-go-home': curated({ label: '返回主页', idempotent: true, notes: '切换到主页模块，重复触发结果相同。' }),
  'main-layout-toggle': curated({ label: '切换布局', notes: '在 Augma 布局与 SwiftUI 侧栏布局间切换，重复触发会反转。' }),
  'native-assistant-input': curated({
    label: '输入指令',
    role: 'textField',
    actions: ['setValue', 'readValue'],
    disabledWhen: 'store.isBusy',
    preconditions: ['助手不忙'],
    idempotent: true,
    notes: '本地指令优先；未匹配时提交给所选 AI 运行时。',
  }),
  'native-assistant-submit': curated({
    label: '执行',
    disabledWhen: 'store.isBusy || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty',
    preconditions: ['助手不忙', '草稿非空'],
    notes: '提交指令；AI 请求可能消耗模型额度。',
  }),
  'assistant-runtime-picker': curated({
    label: 'AI 运行时',
    role: 'popUpButton',
    actions: ['select', 'readValue'],
    disabledWhen: 'magpieConfiguration.isManaged',
    preconditions: ['运行时未被 Magpie 托管'],
    idempotent: true,
  }),
  'dock-bottom-inset': curated({
    label: '底部间距',
    role: 'slider',
    actions: ['setValue', 'readValue'],
    preconditions: [],
    idempotent: true,
    notes: '设置 Augma 布局与沉浸模式底部 Dock 的可见间距，范围 0–120 pt，重启后保留。',
  }),
  'dock-bottom-inset-reset': curated({
    label: '与顶部间距一致',
    preconditions: [],
    idempotent: true,
    notes: '将底部 Dock 间距恢复为 17 pt，与顶部控件到菜单栏的可见间距一致。',
  }),
  'assistant-dsh-test': curated({
    label: '测试模型与只读工具',
    disabledWhen: 'busy || model.isEmpty',
    preconditions: ['无进行中的测试', '已选择模型'],
    notes: '发送真实系统摘要与应用占用，可能消耗模型额度；不执行清理。',
  }),
  'native-space-controls': curated({
    role: 'group',
    actions: ['readValue'],
    access: 'read',
    idempotent: true,
    notes: '空间控制面板根容器，仅用于定位子元素。',
  }),
  'native-space-scan': curated({
    label: '模拟扫描',
    preconditions: [],
    notes: '开始或取消模拟扫描；不使用摄像头，重复触发会反转状态。',
  }),
  'native-browser-address': curated({
    label: '输入网址或搜索',
    role: 'textField',
    actions: ['setValue', 'readValue'],
    preconditions: [],
    idempotent: true,
    notes: '提交后导航；页面加载结果由浏览器显示。',
  }),
  'native-browser-go': curated({
    label: '打开网页',
    disabledWhen: 'store.addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty',
    preconditions: ['地址栏非空'],
    notes: '打开已输入的地址；不保证页面加载成功。',
  }),
  'project-add-folder': curated({
    label: '添加项目文件夹…',
    disabledWhen: '!projects.editable || projects.regions.count >= ProjectRegion.capacity',
    preconditions: ['配置可编辑', '区域数未达 6 个上限'],
    notes: '打开系统目录选择器；需要用户选择。',
  }),
  'project-save': curated({ label: '保存配置', notes: '写入项目区域配置；保存失败可重试。' }),
  'project-select-{id}': curated({ label: '选择项目区域', notes: '选中区域后显示其编辑器；不打开工作区。' }),
  'codex-storage-scan': curated({
    label: '分析 Codex 占用',
    disabledWhen: 'disabled || store.isBusy',
    preconditions: ['无进行中的扫描或清理'],
    notes: '只读扫描，不删除文件。',
  }),
  'codex-storage-confirm': curated({
    label: '确认移入废纸篓',
    preconditions: ['已生成预览', '用户在原生 UI 中确认'],
    notes: '写操作。批准由本地 UI 产生，模型不能自行生成批准；仅将所选文件移入废纸篓。',
  }),
  'disk-usage-choose': curated({ label: '选择目录', notes: '打开系统目录选择器；需要用户选择。' }),
  'immersive-voice': curated({ label: '语音助手', idempotent: true, notes: '打开语音助手面板。' }),
  'immersive-system-menu': curated({
    label: '系统菜单',
    role: 'menuButton',
    actions: ['press'],
    notes: '展开模块与外观菜单。',
  }),
  'immersive-dock-{id}': curated({ label: 'Dock 入口', notes: '打开模块、应用或扩展；重复触发结果通常相同。' }),
  'native-notifications-clear': curated({ label: '清空通知', notes: '清空当前通知列表，不可撤销。' }),
  'native-device-connect': curated({ label: '连接设备', notes: '切换模拟设备连接状态。' }),
}

async function scan() {
  const files = await swiftFiles()
  const elements = []
  const seen = new Map()
  const add = (entry) => {
    const key = entry.pattern ?? entry.id
    const existing = seen.get(key)
    if (existing) {
      assert.equal(existing.source, entry.source, `Duplicate identifier ${key} in different files`)
      return
    }
    seen.set(key, entry)
    elements.push(entry)
  }

  for (const file of files) {
    const text = await readFile(file, 'utf8')
    const lines = text.split('\n')
    const callRegex = /\.accessibilityIdentifier\(/g
    for (const match of text.matchAll(callRegex)) {
      const index = match.index
      const line = text.slice(0, index).split('\n').length - 1
      const arg = callArguments(text, index + match[0].length - 1)
      const literals = literalValues(arg)
      if (literals.length === 0)
        continue // e.g. .accessibilityIdentifier(identifier) passthrough
      if (arg.includes('+')) {
        add(declaration('accessibilityIdentifier', file, lines, line, null, `${literals[0]}{id}`))
      }
      else {
        for (const literal of literals) add(declaration('accessibilityIdentifier', file, lines, line, literal))
      }
    }

    // NativeOrbButton forwards `identifier:` to .accessibilityIdentifier(identifier).
    // Only files that construct orb buttons can contain these declarations.
    if (text.includes('NativeOrbButton(')) {
      for (let i = 0; i < lines.length; i += 1) {
        const match = lines[i].match(/identifier:(.*)$/)
        if (!match)
          continue
        for (const literal of literalValues(match[1])) {
          add(declaration('NativeOrbButton(identifier:)', file, lines, i, literal))
        }
      }
    }
  }

  // Computed dock identifiers are assembled by identifier(for:) rather than
  // written as literals. Keep them explicit so source changes are still caught.
  const dock = files.find(file => basename(file) === 'ImmersiveDockView.swift')
  assert(dock, 'ImmersiveDockView.swift is required for computed dock identifiers')
  const dockText = await readFile(dock, 'utf8')
  assert(dockText.includes('identifier(for:') && dockText.includes('"immersive-"'), 'Computed dock identifier expression changed; update the generator')
  const dockLines = dockText.split('\n')
  const dockIndex = dockLines.findIndex(line => line.includes('private func identifier(for item:'))
  for (const pattern of ['immersive-dock-{id}', 'immersive-{id}']) {
    add(declaration('ImmersiveDockView.identifier(for:)', dock, dockLines, dockIndex, null, pattern))
  }

  elements.sort((a, b) => {
    const left = a.pattern ?? a.id
    const right = b.pattern ?? b.id
    return left < right ? -1 : left > right ? 1 : 0
  })
  return { files, elements }
}

function inventoryFrom(elements) {
  return {
    schemaVersion: 1,
    generator: 'scripts/generate-ax-contract.mjs',
    sourceRoot: 'apps/mac/Sources',
    elements: elements.map(({ id, pattern, source, declaredVia }) => ({ id, pattern, source, declaredVia })),
  }
}

function contractFrom(elements, existing = null, report = {}) {
  const defaults = {
    schemaVersion: 1,
    app: 'AugmaDesktopDemo',
    platform: 'macOS 26+',
    identifierAttribute: 'AXIdentifier',
    description: 'Declared accessibility identifiers for the native macOS UI. Consumers must resolve an id or pattern before issuing an AX action.',
    reviewPolicy: 'reviewed=true entries were checked against the Swift source and may be issued as actions. reviewed=false entries are derived from source: safe for lookup and readValue, but their role, preconditions and side effects must be verified in a running App before they become agent tools.',
    roles: ROLES,
    actions: ACTIONS,
    accessLevels: ACCESS_LEVELS,
    runtimeVerification: {
      axTreeOperatedInAcceptance: true,
      acceptanceEvidence: 'apps/mac/docs/disk-usage-acceptance.md',
      requiresTrustedAccessibilityProcess: true,
      voiceOverAnnouncementVerified: false,
      unitTestReadsAXTree: false,
      note: 'The running App was operated through the native accessibility tree during acceptance. Unit tests verify the contract and source declarations, not the live AX tree; VoiceOver announcement has not been recorded.',
    },
  }
  const base = existing ?? {}
  const sourceKeys = keySet(elements)
  const existingElements = base.elements ?? []
  const existingKeys = new Set(existingElements.map(entry => entry.pattern ?? entry.id))
  const merged = [...existingElements]
  const added = []

  for (const derived of elements) {
    const key = derived.pattern ?? derived.id
    if (existingKeys.has(key))
      continue
    // A new identifier in a known file inherits that file's scene when the
    // file has one unambiguous scene; otherwise use the source heuristic.
    const peerScenes = new Set(existingElements
      .filter(entry => entry.source === derived.source)
      .map(entry => entry.scene))
    const scene = peerScenes.size === 1 ? [...peerScenes][0] : derived.scene
    const initial = { ...derived, scene }
    merged.push(CURATION[key] ? { ...initial, ...CURATION[key] } : initial)
    added.push(key)
  }

  const stale = existingElements
    .map(entry => entry.pattern ?? entry.id)
    .filter(key => !sourceKeys.has(key))
  const finalElements = merged.filter(entry => sourceKeys.has(entry.pattern ?? entry.id))
  report.added = added
  report.stale = stale
  report.preserved = existingElements.length - stale.length

  // Keep the existing key order so a sync that only appends entries produces a
  // minimal diff. Concurrent chats maintain this file by hand.
  const scenes = { ...(base.scenes ?? {}) }
  for (const [key, value] of Object.entries(SCENES)) {
    if (!(key in scenes))
      scenes[key] = value
  }
  const mergedList = (key, fallback) => {
    const values = [...(base[key] ?? fallback)]
    for (const value of fallback) {
      if (!values.includes(value))
        values.push(value)
    }
    return values
  }
  const overrides = {
    scenes,
    roles: mergedList('roles', ROLES),
    actions: mergedList('actions', ACTIONS),
    accessLevels: mergedList('accessLevels', ACCESS_LEVELS),
    elements: finalElements,
  }
  const result = {}
  for (const key of Object.keys(base)) result[key] = key in overrides ? overrides[key] : base[key]
  for (const [key, value] of Object.entries(defaults)) {
    if (!(key in result))
      result[key] = value
  }
  return result
}

function keySet(elements) {
  return new Set(elements.map(entry => entry.pattern ?? entry.id))
}

const TIER_ORDER = ['high', 'medium', 'low']

// Review priority, computed only from declared fields. This is a triage hint,
// not a safety verdict: a high tier means "verify first", not "safe to expose".
function reviewRisk(element) {
  const key = element.pattern ?? element.id
  if (element.access === 'read')
    return { tier: 'low', reason: '只读：仅允许 readValue' }
  const confirmation = element.preconditions.some(text => /确认/.test(text))
    || /不可撤销|废纸篓|写操作/.test(element.notes)
  if (element.scene === 'panel:cleanup')
    return { tier: 'high', reason: '清理场景：可能触发真实副作用' }
  if (confirmation)
    return { tier: 'high', reason: '需要原生确认：写操作边界' }
  if (/confirm|execute|remove|clear|delete|disconnect|reset|rebuild/.test(key))
    return { tier: 'high', reason: '标识含破坏性动作词' }
  return { tier: 'medium', reason: '普通写动作' }
}

function reviewQueue(contract) {
  const pending = contract.elements.filter(element => !element.reviewed)
  const queue = pending.map((element) => {
    const risk = reviewRisk(element)
    return { key: element.pattern ?? element.id, element, ...risk }
  })
  assert.equal(queue.length, pending.length, 'Queue must cover every unreviewed entry')
  assert(queue.every(entry => TIER_ORDER.includes(entry.tier)), 'Invalid review tier')
  queue.sort((a, b) => {
    const byTier = TIER_ORDER.indexOf(a.tier) - TIER_ORDER.indexOf(b.tier)
    if (byTier !== 0)
      return byTier
    const byScene = a.element.scene.localeCompare(b.element.scene)
    return byScene !== 0 ? byScene : a.key.localeCompare(b.key)
  })
  return queue
}

function printQueue(contract) {
  const queue = reviewQueue(contract)
  const counts = Object.fromEntries(TIER_ORDER.map(tier => [tier, queue.filter(entry => entry.tier === tier).length]))
  const firstBatch = queue.filter(entry => FIRST_BATCH_SCENES.has(entry.element.scene) && entry.tier !== 'high')
  console.log(`AX review queue: ${queue.length} unreviewed of ${contract.elements.length} entries`)
  console.log(`  high ${counts.high}   medium ${counts.medium}   low ${counts.low}`)
  console.log(`\n第一批建议（最小暴露工具集内、排除高风险写操作的待复核条目，共 ${firstBatch.length} 条）：`)
  for (const entry of firstBatch)
    console.log(`  ${entry.key.padEnd(38)} ${entry.element.scene.padEnd(26)} ${entry.tier}`)
  console.log('\n按风险排序的完整复核队列（high → medium → low）：')
  let current = ''
  for (const entry of queue) {
    if (entry.tier !== current) {
      current = entry.tier
      console.log(`\n[${current}] ${counts[current]}`)
    }
    console.log(`  ${entry.key.padEnd(38)} ${entry.element.scene.padEnd(26)} ${String(entry.element.access).padEnd(6)} ${entry.reason}`)
  }
}

function validateContract(contract, inventory, sourceSet) {
  assert.equal(contract.schemaVersion, 1, 'Unsupported contract schemaVersion')
  assert.equal(contract.identifierAttribute, 'AXIdentifier')
  assert.equal(typeof contract.app, 'string')
  assert.equal(typeof contract.reviewPolicy, 'string', 'reviewPolicy is required')
  for (const key of Object.keys(CURATION)) assert(keySet(contract.elements).has(key), `Curation for unknown identifier: ${key}`)
  for (const [key, value] of Object.entries(contract.scenes)) assert.equal(typeof value, 'string', `Scene ${key} needs a description`)
  for (const role of ROLES) assert(contract.roles.includes(role), `Missing role ${role}`)
  for (const action of ACTIONS) assert(contract.actions.includes(action), `Missing action ${action}`)
  for (const access of ACCESS_LEVELS) assert(contract.accessLevels.includes(access), `Missing access level ${access}`)

  const verification = contract.runtimeVerification
  assert(verification, 'runtimeVerification is required')
  assert.equal(verification.voiceOverAnnouncementVerified, false, 'Do not claim VoiceOver announcement is verified without a recorded run')
  assert.equal(verification.unitTestReadsAXTree, false, 'Unit tests do not read the live AX tree; keep this boundary accurate')

  const keys = new Set()
  for (const element of contract.elements) {
    const key = element.pattern ?? element.id
    assert(key, 'Every element needs id or pattern')
    assert(!keys.has(key), `Duplicate contract entry: ${key}`)
    keys.add(key)
    assert(!(element.id && element.pattern), `${key} cannot be both id and pattern`)
    assert(contract.roles.includes(element.role), `${key}: invalid role ${element.role}`)
    assert(contract.scenes[element.scene], `${key}: unknown scene ${element.scene}`)
    assert(Array.isArray(element.actions) && element.actions.length > 0, `${key}: actions required`)
    for (const action of element.actions) assert(contract.actions.includes(action), `${key}: invalid action ${action}`)
    assert(contract.accessLevels.includes(element.access), `${key}: invalid access ${element.access}`)
    if (element.actions.some(action => WRITE_ACTIONS.has(action)))
      assert.equal(element.access, 'write', `${key}: write actions require access=write`)
    if (element.access === 'read')
      assert(!element.actions.some(action => WRITE_ACTIONS.has(action)), `${key}: read-only element cannot have write actions`)
    assert.equal(typeof element.idempotent, 'boolean', `${key}: idempotent must be a boolean`)
    assert.equal(typeof element.reviewed, 'boolean', `${key}: reviewed must be a boolean`)
    assert(Array.isArray(element.preconditions), `${key}: preconditions must be an array`)
    assert.equal(typeof element.source, 'string', `${key}: source is required`)
    assert.equal(typeof element.declaredVia, 'string', `${key}: declaredVia is required`)
  }

  const contractSet = keySet(contract.elements)
  const inventorySet = keySet(inventory.elements)
  const missing = [...inventorySet].filter(key => !contractSet.has(key))
  const stale = [...contractSet].filter(key => !inventorySet.has(key))
  assert.deepEqual(missing, [], `Source identifiers missing from contract: ${missing.join(', ')}`)
  assert.deepEqual(stale, [], `Contract entries absent from source: ${stale.join(', ')}`)
  assert.deepEqual([...inventorySet].sort(), [...sourceSet].sort(), 'Inventory does not match the Swift sources; run with --write')
  for (const element of contract.elements) {
    const match = inventory.elements.find(entry => (entry.pattern ?? entry.id) === (element.pattern ?? element.id))
    assert.equal(element.source, match.source, `${element.pattern ?? element.id}: source file drifted`)
  }
}

async function readExistingContract() {
  try {
    return JSON.parse(await readFile(CONTRACT_PATH, 'utf8'))
  }
  catch (error) {
    if (error.code === 'ENOENT')
      return null
    throw error
  }
}

const { files, elements } = await scan()
const sourceSet = keySet(elements)
const inventory = inventoryFrom(elements)

if (mode === 'bootstrap') {
  const report = {}
  const existing = await readExistingContract()
  const contract = contractFrom(elements, existing, report)
  const unchanged = existing && report.added.length === 0 && report.stale.length === 0
  if (unchanged) {
    // Do not rewrite a file another chat may be editing, even for a pure
    // key-order difference.
    console.log(`Already in sync: ${contract.elements.length} entries, ${files.length} Swift files; contract left untouched`)
  }
  else {
    await writeFile(CONTRACT_PATH, `${JSON.stringify(contract, null, 2)}\n`)
    console.log(`Synced ${contract.elements.length} entries into ${relative(ROOT, CONTRACT_PATH)}: preserved ${report.preserved}, added ${report.added.length}, dropped ${report.stale.length}`)
    if (report.added.length)
      console.log(`  added: ${report.added.join(', ')}`)
    if (report.stale.length)
      console.log(`  dropped: ${report.stale.join(', ')}`)
  }
}

const storedContract = JSON.parse(await readFile(CONTRACT_PATH, 'utf8'))
const storedInventory = mode === 'check' || mode === 'queue'
  ? JSON.parse(await readFile(INVENTORY_PATH, 'utf8'))
  : inventory
validateContract(storedContract, storedInventory, sourceSet)

if (mode === 'queue') {
  printQueue(storedContract)
}
else if (mode === 'write') {
  await writeFile(INVENTORY_PATH, `${JSON.stringify(inventory, null, 2)}\n`)
  console.log(`Wrote ${inventory.elements.length} identifiers from ${files.length} Swift files to ${relative(ROOT, INVENTORY_PATH)}`)
}
else {
  console.log(`AX contract OK: ${storedContract.elements.length} entries, ${files.length} Swift files, ${Object.keys(storedContract.scenes).length} scenes`)
}
