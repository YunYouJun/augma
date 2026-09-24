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
})
