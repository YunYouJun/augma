const elements = Object.fromEntries(['title', 'description', 'orbit', 'phase', 'count', 'toggle', 'reset', 'rounds', 'footnote'].map(id => [id, document.getElementById(id)]))
const locale = navigator.language.startsWith('zh') ? 'zh' : navigator.language.startsWith('ja') ? 'ja' : 'en'
const messages = {
  zh: { title: '留一点安静的时间', description: '吸气 4 秒，呼气 6 秒。跟随圆环，按自己的节奏来。', ready: '准备好了', inhale: '吸气', exhale: '呼气', start: '开始', pause: '暂停', resume: '继续', reset: '重置', rounds: n => `已完成 ${n} 轮`, footnote: '随时暂停。离开页面或停用插件后，本次练习结束。' },
  en: { title: 'A little room to breathe', description: 'Breathe in for 4 seconds, out for 6. Follow the orbit at your own pace.', ready: 'When you’re ready', inhale: 'Breathe in', exhale: 'Breathe out', start: 'Begin', pause: 'Pause', resume: 'Resume', reset: 'Reset', rounds: n => `${n} rounds completed`, footnote: 'Pause whenever you like. Leaving this page or disabling the plugin ends the session.' },
  ja: { title: '静かなひとときを', description: '4秒吸って、6秒吐く。円の動きに合わせて、自分のペースで。', ready: '準備ができたら', inhale: '吸って', exhale: '吐いて', start: '開始', pause: '一時停止', resume: '再開', reset: 'リセット', rounds: n => `${n} 回完了`, footnote: 'いつでも一時停止できます。ページを離れるかプラグインを無効にすると終了します。' },
}[locale]
for (const key of ['title', 'description', 'footnote']) elements[key].textContent = messages[key]
elements.phase.textContent = messages.ready
elements.toggle.textContent = messages.start
elements.reset.textContent = messages.reset
elements.rounds.textContent = messages.rounds(0)
let running = false
let elapsed = 0
let startedAt = 0
let frame = 0
function render(now) {
  if (!running)
    return
  const total = elapsed + now - startedAt
  const position = total % 10000
  elements.phase.textContent = position < 4000 ? messages.inhale : messages.exhale
  elements.count.textContent = String(Math.max(1, Math.ceil(((position < 4000 ? 4000 : 10000) - position) / 1000)))
  elements.rounds.textContent = messages.rounds(Math.floor(total / 10000))
  frame = requestAnimationFrame(render)
}
elements.toggle.addEventListener('click', () => {
  if (running) {
    elapsed += performance.now() - startedAt
    running = false
    cancelAnimationFrame(frame)
    elements.toggle.textContent = messages.resume
  }
  else {
    running = true
    startedAt = performance.now()
    elements.toggle.textContent = messages.pause
    frame = requestAnimationFrame(render)
  }
  elements.orbit.classList.toggle('paused', !running)
})
elements.reset.addEventListener('click', () => {
  running = false
  cancelAnimationFrame(frame)
  elapsed = 0
  elements.orbit.classList.add('paused')
  // Recreate the animated ring so a reset starts a fresh cycle without inline styles.
  const ring = elements.orbit.querySelector('.ring')
  ring.replaceWith(ring.cloneNode(true))
  elements.phase.textContent = messages.ready
  elements.count.textContent = '4 : 6'
  elements.toggle.textContent = messages.start
  elements.rounds.textContent = messages.rounds(0)
})
addEventListener('pagehide', () => {
  running = false
  cancelAnimationFrame(frame)
})
