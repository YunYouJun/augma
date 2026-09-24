export type VoiceCommand
  = | 'map' | 'scan' | 'audio' | 'audioPause' | 'hide' | 'show'
    | 'weather' | 'notifications' | 'settings' | 'camera'
    | 'dark' | 'light' | 'routeStart' | 'routeNext' | 'routeStop'

const voiceCommands: readonly VoiceCommand[] = [
  'map',
  'scan',
  'audio',
  'audioPause',
  'hide',
  'show',
  'weather',
  'notifications',
  'settings',
  'camera',
  'dark',
  'light',
  'routeStart',
  'routeNext',
  'routeStop',
]

export function isVoiceCommand(value: unknown): value is VoiceCommand {
  return typeof value === 'string' && (voiceCommands as readonly string[]).includes(value)
}

export function matchVoiceCommand(transcript: string): VoiceCommand | null {
  const text = transcript.toLowerCase().replace(/[\s，。！？,.!?]/g, '')

  if (/暂停|停止|关闭/.test(text) && /声音|音乐|播放/.test(text))
    return 'audioPause'
  if (/结束|停止|取消/.test(text) && /导航|路线/.test(text))
    return 'routeStop'
  if (/下一步|前进一步|继续前进/.test(text))
    return 'routeNext'
  if (/不要|^别|请别|先别/.test(text))
    return null

  if (/关闭深色|浅色|亮色|日间/.test(text) && /模式|视界|主题|深色/.test(text))
    return 'light'
  if (/开启|打开|切换|显示/.test(text) && /深色|夜间/.test(text))
    return 'dark'
  if (/隐藏|收起|关闭|关掉/.test(text) && /hud|界面|视界|面板/.test(text))
    return 'hide'
  if (/显示|展开|恢复/.test(text) && /hud|界面|视界/.test(text))
    return 'show'
  if (/开始|启动/.test(text) && /导航|路线/.test(text))
    return 'routeStart'
  if (/扫描|识别|探测/.test(text) && /空间|周围|环境|附近/.test(text))
    return 'scan'
  if (/地图|导航|路线/.test(text) && /打开|显示|查看|看看|看|启动/.test(text))
    return 'map'
  if (/天气|气温|温度/.test(text) && /打开|显示|查看|看看|看/.test(text))
    return 'weather'
  if (/通知|消息/.test(text) && /打开|显示|查看|看看|看/.test(text))
    return 'notifications'
  if (/设置/.test(text) && /打开|显示|查看|看看|看/.test(text))
    return 'settings'
  if (/摄像头|相机/.test(text) && /打开|显示|查看|看看|看/.test(text))
    return 'camera'
  if (/声音|音乐|音频/.test(text) && /播放|打开|放|听/.test(text))
    return 'audio'

  return null
}
