import type { Locale } from '../../i18n/locale'
import { locales } from '../../i18n/locale'

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

// A matcher returns a command, `null` when the phrase is an explicit refusal ("don't…"),
// or `undefined` when it does not recognize the phrase so another language can try.
type Matcher = (transcript: string) => VoiceCommand | null | undefined

function matchChinese(transcript: string): VoiceCommand | null | undefined {
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
}

function matchEnglish(transcript: string): VoiceCommand | null | undefined {
  // Keep word boundaries: English needs spaces that the CJK matchers strip.
  const text = ` ${transcript.toLowerCase().replace(/[^a-z']+/g, ' ').trim()} `
  const view = /\b(?:open|show|view|display|see|check|bring up|pull up|go to|launch)\b/

  // Unlike the Chinese rules, refusals win here so "don't stop the music" does nothing.
  if (/\b(?:don't|dont|do not|never)\b/.test(text))
    return null
  if (/\b(?:pause|stop|mute)\b/.test(text) && /\b(?:sound|music|audio|playback)\b/.test(text))
    return 'audioPause'
  if (/\b(?:end|stop|cancel|exit|quit)\b/.test(text) && /\b(?:navigation|navigating|route|directions)\b/.test(text))
    return 'routeStop'
  if (/\b(?:next step|step forward|move forward|go forward|keep going)\b/.test(text))
    return 'routeNext'

  if ((/\b(?:turn off|disable|exit)\b/.test(text) && /\bdark\b/.test(text)) || (/\b(?:light|day)\b/.test(text) && /\b(?:mode|theme|view)\b/.test(text)))
    return 'light'
  if (/\b(?:turn on|enable|switch to|use|open|show|go)\b/.test(text) && /\b(?:dark|night)\b/.test(text))
    return 'dark'
  if (/\b(?:hide|collapse|close|dismiss)\b/.test(text) && /\b(?:hud|interface|ui|overlay|panel|view)\b/.test(text))
    return 'hide'
  if (/\b(?:show|restore|bring back|display)\b/.test(text) && /\b(?:hud|interface|ui|overlay)\b/.test(text))
    return 'show'
  if (/\b(?:start|begin)\b/.test(text) && /\b(?:navigation|navigating|route|directions)\b/.test(text))
    return 'routeStart'
  if (/\b(?:scan|detect)\b/.test(text) && /\b(?:space|room|surroundings|area|environment|around)\b/.test(text))
    return 'scan'
  if (/\b(?:map|navigation|route|directions)\b/.test(text) && view.test(text))
    return 'map'
  if (/\b(?:weather|temperature|forecast)\b/.test(text) && view.test(text))
    return 'weather'
  if (/\b(?:notifications?|messages?|alerts?)\b/.test(text) && (view.test(text) || /\bread\b/.test(text)))
    return 'notifications'
  if (/\b(?:settings|preferences)\b/.test(text) && view.test(text))
    return 'settings'
  if (/\bcamera\b/.test(text) && (view.test(text) || /\b(?:turn on|start)\b/.test(text)))
    return 'camera'
  if (/\b(?:sound|music|audio|soundscape)\b/.test(text) && /\b(?:play|open|start|turn on|listen)\b/.test(text))
    return 'audio'
}

function matchJapanese(transcript: string): VoiceCommand | null | undefined {
  const text = transcript.toLowerCase().replace(/[\s、。！？,.!?]/g, '')
  const view = /開|表示|見せ|見て|見る|出して|確認/

  if (/ないで|だめ|ダメ|いらない/.test(text))
    return null
  if (/一時停止|停止|止め|ストップ|やめ/.test(text) && /音|サウンド|再生/.test(text))
    return 'audioPause'
  if (/終了|停止|止め|やめ|キャンセル|終わ/.test(text) && /ナビ|ルート|案内/.test(text))
    return 'routeStop'
  if (/次へ|次のステップ|一歩進|前へ進|先に進/.test(text))
    return 'routeNext'

  if ((/ダーク|夜間/.test(text) && /オフ|解除|消/.test(text)) || (/ライト|明るい|日中|昼間/.test(text) && /モード|テーマ|表示|ビュー/.test(text)))
    return 'light'
  if (/ダーク|暗い|夜間|ナイト/.test(text) && /オン|にして|切り替え|有効|つけ/.test(text))
    return 'dark'
  if (/隠し|隠す|非表示|閉じ|しまって/.test(text) && /hud|インターフェース|画面|ui|パネル|ビュー/.test(text))
    return 'hide'
  if (/表示|見せ|出して|戻して|復元/.test(text) && /hud|インターフェース|ui/.test(text))
    return 'show'
  if (/開始|始め|スタート/.test(text) && /ナビ|ルート|案内/.test(text))
    return 'routeStart'
  if (/スキャン|認識|検出/.test(text) && /空間|周り|周囲|環境|近く|まわり|部屋/.test(text))
    return 'scan'
  if (/地図|マップ|ナビ|ルート/.test(text) && (view.test(text) || /起動/.test(text)))
    return 'map'
  if (/天気|気温|温度/.test(text) && view.test(text))
    return 'weather'
  if (/通知|メッセージ|お知らせ/.test(text) && view.test(text))
    return 'notifications'
  if (/設定/.test(text) && view.test(text))
    return 'settings'
  if (/カメラ/.test(text) && (view.test(text) || /起動|オン|つけ/.test(text)))
    return 'camera'
  if (/音|サウンド|オーディオ/.test(text) && /再生|流して|かけて|聴|聞|オン|つけ/.test(text))
    return 'audio'
}

const matchers: Record<Locale, Matcher> = { 'zh-CN': matchChinese, 'en-US': matchEnglish, 'ja-JP': matchJapanese }

/**
 * Map a spoken or typed phrase in Chinese, English or Japanese to a demo command.
 *
 * @param transcript - What the user said or typed
 * @param preferred - The language tried first; the others follow, since typed text may be in any language
 * @returns The matched command, or `null` when nothing matches or the phrase is a refusal
 *
 * @example
 * ```ts
 * matchVoiceCommand('open the map') // 'map'
 * matchVoiceCommand('地図を開かないで', 'ja-JP') // null
 * ```
 */
export function matchVoiceCommand(transcript: string, preferred: Locale = 'zh-CN'): VoiceCommand | null {
  for (const language of [preferred, ...locales.filter(item => item !== preferred)]) {
    const command = matchers[language](transcript)
    if (command !== undefined)
      return command
  }
  return null
}
