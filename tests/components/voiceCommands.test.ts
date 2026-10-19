import { describe, expect, it } from 'vitest'
import { matchVoiceCommand } from '../../apps/ar/src/features/device/voiceCommands'

describe('macOS voice commands', () => {
  it.each([
    ['打开地图', 'map'],
    ['请显示导航路线。', 'map'],
    ['帮我扫描一下周围', 'scan'],
    ['开始识别空间', 'scan'],
    ['播放音乐', 'audio'],
    ['打开声音', 'audio'],
    ['暂停音乐', 'audioPause'],
    ['把 HUD 收起来', 'hide'],
    ['隐藏界面', 'hide'],
    ['显示 HUD', 'show'],
    ['打开天气', 'weather'],
    ['查看通知', 'notifications'],
    ['打开设置', 'settings'],
    ['打开摄像头', 'camera'],
    ['开启深色视界', 'dark'],
    ['切换浅色视界', 'light'],
    ['关闭深色视界', 'light'],
    ['开始模拟导航', 'routeStart'],
    ['前进一步', 'routeNext'],
    ['结束导航', 'routeStop'],
  ] as const)('maps %s to %s', (phrase, command) => {
    expect(matchVoiceCommand(phrase)).toBe(command)
  })

  it('does not guess an action for unrelated speech', () => {
    expect(matchVoiceCommand('今天天气怎么样')).toBeNull()
    expect(matchVoiceCommand('不要打开地图')).toBeNull()
    expect(matchVoiceCommand('不要播放音乐')).toBeNull()
    expect(matchVoiceCommand('')).toBeNull()
  })

  it.each([
    ['Open the map', 'map'],
    ['show me the route', 'map'],
    ['Scan the space around me.', 'scan'],
    ['Play some music', 'audio'],
    ['pause the sound', 'audioPause'],
    ['Hide the HUD', 'hide'],
    ['show the HUD again', 'show'],
    ['Show the weather', 'weather'],
    ['check my notifications', 'notifications'],
    ['open settings', 'settings'],
    ['turn on the camera', 'camera'],
    ['Turn on dark view', 'dark'],
    ['switch to light mode', 'light'],
    ['turn off dark mode', 'light'],
    ['start navigation', 'routeStart'],
    ['next step', 'routeNext'],
    ['stop navigating', 'routeStop'],
  ] as const)('maps English %s to %s', (phrase, command) => {
    expect(matchVoiceCommand(phrase, 'en-US')).toBe(command)
  })

  it.each([
    ['地図を開いて', 'map'],
    ['ルートを表示して', 'map'],
    ['周りの空間をスキャンして', 'scan'],
    ['音楽を再生して', 'audio'],
    ['サウンドを一時停止して', 'audioPause'],
    ['HUD を隠して', 'hide'],
    ['HUDを表示して', 'show'],
    ['天気を表示して', 'weather'],
    ['通知を確認して', 'notifications'],
    ['設定を開いて', 'settings'],
    ['カメラを起動して', 'camera'],
    ['ダークモードにして', 'dark'],
    ['ライトモードに切り替えて', 'light'],
    ['ダークモードをオフにして', 'light'],
    ['ナビを開始して', 'routeStart'],
    ['一歩進んで', 'routeNext'],
    ['ナビを終了して', 'routeStop'],
  ] as const)('maps Japanese %s to %s', (phrase, command) => {
    expect(matchVoiceCommand(phrase, 'ja-JP')).toBe(command)
  })

  it('matches typed text in any supported language and keeps refusals', () => {
    expect(matchVoiceCommand('open the map', 'zh-CN')).toBe('map')
    expect(matchVoiceCommand('打开天气', 'ja-JP')).toBe('weather')
    expect(matchVoiceCommand('設定を開いて', 'en-US')).toBe('settings')
    expect(matchVoiceCommand('不要打开地图', 'en-US')).toBeNull()
    expect(matchVoiceCommand('don\'t stop the music', 'en-US')).toBeNull()
    expect(matchVoiceCommand('what is the weather like today', 'en-US')).toBeNull()
    expect(matchVoiceCommand('地図を開かないで', 'ja-JP')).toBeNull()
    expect(matchVoiceCommand('今日の天気はどう', 'ja-JP')).toBeNull()
  })
})
