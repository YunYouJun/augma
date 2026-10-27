export const agent = {
  id: 'augma',
  name: 'Augma',
  config: '~/Library/Application Support/Augma/Assistant/magpie.json',
  format: 'json',
  model: 'model',
  ua: ['augma'],
  icon: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMS44IiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Im0zIDIwIDktMTYgOSAxNk03IDE0aDEwTTkgMjBoNiIvPjwvc3ZnPgo=',
  notice: '在 Augma 插件面板管理推理强度。返回 Augma 检测连接并测试，通过后启用助手。',
}

// The host writes the complete model ID and keeps the original keys for disconnect.
// Effort stays in plugin options, so catalog refreshes cannot reset the selection.
export function connect() {
  return { version: 1, runtime: 'dsh', managed: true, plugin: 'magpie-plugin-augma' }
}
