/* global magpie */
const effort = document.getElementById('effort')
const save = document.getElementById('save')
const status = document.getElementById('status')
let zh = true
let saving = false
const message = (cn, en) => zh ? cn : en
function error() {
  status.setAttribute('role', 'alert')
  status.textContent = message('保存或读取失败，请重新打开面板后重试。', 'Could not read or save settings. Reopen the panel and try again.')
}
function theme(value) {
  zh = value.lang?.startsWith('zh') ?? false
  document.getElementById('guide').textContent = message('在应用列表的 Augma 卡片选择模型或路由组。推理强度在这里保存。', 'Choose a model or routing group on the Augma card in Agents. Save reasoning effort here.')
  document.getElementById('effort-label').textContent = message('推理强度', 'Reasoning effort')
  save.textContent = message('保存', 'Save')
  document.getElementById('hint').textContent = message('仅应用于 Augma。修改模型或强度后，返回 Augma 检测并测试，通过后重新启用助手。请选用当前模型支持的强度。', 'Applies only to Augma. After changing the model or effort, detect and test in Augma, then enable the assistant again. Choose an effort supported by your model.')
}
async function load() {
  try {
    theme(await magpie.ready)
    magpie.onTheme(theme)
    const options = await magpie.options.get()
    const selected = options.effort ?? 'medium'
    if (![...effort.options].some(option => option.value === selected)) throw new Error('Unsupported effort')
    effort.value = selected
    effort.disabled = false
    save.disabled = false
  } catch { error() }
}
document.getElementById('settings').addEventListener('submit', async (event) => {
  event.preventDefault()
  if (saving) return
  saving = true
  save.disabled = effort.disabled = true
  try {
    const options = await magpie.options.get()
    await magpie.options.set({ ...options, integration: 'augma-v1', effort: effort.value })
    status.setAttribute('role', 'status')
    status.textContent = message('已保存。请返回 Augma 检测并测试。', 'Saved. Return to Augma to detect and test.')
  } catch { error() }
  finally { saving = false; save.disabled = effort.disabled = false }
})
load()
