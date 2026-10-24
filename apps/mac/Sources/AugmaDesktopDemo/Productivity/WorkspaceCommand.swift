import Foundation

enum NativeAudioAction: Equatable {
  case play, pause, next, previous
}

enum WorkspaceCommand: Equatable {
  case note(String), task(String), startFocus(TimeInterval), pause, resume, extend, cancel, undo
  case open(DemoModule)
  case audio(NativeAudioAction)
  case space(NativeSpaceAction)

  static func parse(_ input: String) -> WorkspaceCommand? {
    let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw == "メモを開く" { return .open(.notes) }
    if let task = capture("^(?:(?:添加待办|新建待办|待办)[：:\\s]*|(?:todo|task)\\s+|タスク[：:\\s]*)(.+)$", in: raw) {
      return .task(task)
    }
    // Capture note text before matching any embedded action words.
    if let note = capture("^(?:(?:记下|记录|记一笔|帮我记下)(?:一下)?[：:\\s]*|(?:note|remember)\\s+|メモ(?:して)?[：:\\s]*)(.+)$", in: raw) {
      return .note(note)
    }
    let text = raw.replacingOccurrences(of: "[。.!！]+$", with: "", options: .regularExpression)
    let compact = text.lowercased().replacingOccurrences(of: " ", with: "")
    let spacePhrases: [(NativeSpaceAction, [String])] = [
      (.scan, ["扫描空间", "扫描", "开始模拟扫描", "scan", "scanspace", "空間をスキャン", "スキャン"]),
      (.cancelScan, ["取消扫描", "停止扫描", "cancelscan", "stopscan", "スキャンを中止"]),
      (.routeStart, ["开始模拟路线", "开始模拟导航", "startsimulatedroute", "シミュレーション経路を開始"]),
      (.routeNext, ["模拟路线前进一步", "前进一步", "stepforward", "一歩進む"]),
      (.routeStop, ["结束模拟路线", "停止模拟导航", "stopsimulatedroute", "シミュレーション経路を終了"]),
    ]
    for (action, phrases) in spacePhrases where phrases.contains(compact) { return .space(action) }
    let audioPhrases: [(NativeAudioAction, [String])] = [
      (.play, ["播放声音", "播放音乐", "开始播放声音", "继续播放声音", "playsound", "playaudio", "playmusic", "resumesound", "サウンドを再生", "音楽を再生", "音を再生"]),
      (.pause, ["暂停声音", "暂停音乐", "停止声音", "pausesound", "pauseaudio", "pausemusic", "サウンドを一時停止", "音楽を一時停止", "音を一時停止"]),
      (.next, ["下一首", "下一曲", "nexttrack", "nextsong", "次の曲", "次の曲へ"]),
      (.previous, ["上一首", "上一曲", "previoustrack", "previoussong", "前の曲", "前の曲へ"]),
    ]
    for (action, phrases) in audioPhrases where phrases.contains(compact) { return .audio(action) }
    if ["暂停专注", "暂停计时", "pause", "pausefocus", "pausetimer", "タイマーを一時停止"].contains(compact) { return .pause }
    if ["继续专注", "继续计时", "恢复计时", "resume", "resumefocus", "resumetimer", "タイマーを再開"].contains(compact) { return .resume }
    if ["延长五分钟", "延长5分钟", "再加五分钟", "再加5分钟", "extend", "add5minutes", "5分延長"].contains(compact) { return .extend }
    if ["取消专注", "结束专注", "取消计时", "结束计时", "cancel", "canceltimer", "stopfocus", "stoptimer", "タイマーを終了"].contains(compact) { return .cancel }
    if ["撤销", "撤销上一步", "undo", "元に戻す"].contains(compact) { return .undo }
    let destinations: [(DemoModule, [String])] = [
      (.notes, ["快速记录", "打开记录", "查看记录", "notes", "opennotes", "メモを開く"]),
      (.focus, ["专注计时", "打开计时", "focus", "timer", "タイマー"]),
      (.actions, ["快捷指令", "打开指令", "commands", "コマンド"]),
      (.monitor, ["系统监控", "打开系统监控", "查看系统信息", "查看网速", "磁盘还剩多少", "monitor", "systemmonitor", "opensystemmonitor", "システムモニタ", "システムモニタを開く"]),
      (.weather, ["打开天气", "weather", "openweather", "天気を開く"]),
      (.audio, ["打开声音", "sound", "opensound", "サウンドを開く"]),
      (.navigation, ["打开地图", "打开导航", "地图导航", "map", "maps", "openmaps", "opennavigation", "地図を開く", "ナビを開く"]),
      (.camera, ["打开摄像头", "摄像头", "camera", "opencamera", "カメラを開く"]),
      (.space, ["打开空间", "空间", "space", "openspace", "空間を開く"]),
      (.browser, ["打开网页", "打开浏览器", "网页", "browser", "openbrowser", "ブラウザを開く"]),
    ]
    for (module, phrases) in destinations where phrases.contains(compact) { return .open(module) }
    if let duration = capture("^(?:(?:开始)?(?:专注|计时)|(?:start\\s+)?(?:focus|timer)\\s+)(.+)$", in: text),
       let seconds = seconds(duration) { return .startFocus(seconds) }
    if let duration = capture("^(.+?)(?:のタイマー|集中)$", in: text), let seconds = seconds(duration) { return .startFocus(seconds) }
    return nil
  }

  private static func capture(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func seconds(_ source: String) -> TimeInterval? {
    let text = source.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if ["半小时", "half an hour"].contains(text) { return 1800 }
    guard let regex = try? NSRegularExpression(pattern: "^([0-9]+(?:\\.[0-9]+)?|[零〇一二两三四五六七八九十百千]+|[a-z -]+?)\\s*(分钟|分|minutes?|mins?|m|秒钟|秒|seconds?|secs?|s|小时|hours?|hrs?|h|時間)$"),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let numberRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text),
          let number = number(String(text[numberRange]).trimmingCharacters(in: .whitespaces)), number.isFinite else { return nil }
    let unit = String(text[unitRange])
    let factor: Double = ["小时", "時間", "hour", "hours", "hr", "hrs", "h"].contains(unit) ? 3600
      : ["秒", "秒钟", "second", "seconds", "sec", "secs", "s"].contains(unit) ? 1 : 60
    let seconds = number * factor
    return (5...86_400).contains(seconds) ? seconds : nil
  }

  private static func number(_ text: String) -> Double? {
    if let value = Double(text) { return value }
    let english = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
                   "ten": 10, "eleven": 11, "twelve": 12, "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60]
    let words = text.replacingOccurrences(of: "-", with: " ").split(separator: " ")
    if !words.isEmpty, words.allSatisfy({ english[String($0)] != nil }) {
      return Double(words.reduce(0) { $0 + (english[String($1)] ?? 0) })
    }
    let digits: [Character: Int] = ["零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
    let units: [Character: Int] = ["十": 10, "百": 100, "千": 1000]
    var total = 0, current = 0
    for character in text {
      if let digit = digits[character] { current = current * 10 + digit }
      else if let unit = units[character] { total += max(1, current) * unit; current = 0 }
      else { return nil }
    }
    return text.isEmpty ? nil : Double(total + current)
  }
}

struct WorkspaceAction: Identifiable {
  let id: String
  let title: String
  let symbol: String
  let command: WorkspaceCommand

  static var all: [WorkspaceAction] { [
    .init(id: "notes", title: String(localized: "快速记录"), symbol: "square.and.pencil", command: .open(.notes)),
    .init(id: "monitor", title: String(localized: "系统监控"), symbol: "gauge.with.dots.needle.50percent", command: .open(.monitor)),
    .init(id: "weather", title: String(localized: "天气"), symbol: "cloud.sun", command: .open(.weather)),
    .init(id: "navigation", title: String(localized: "地图导航"), symbol: "map", command: .open(.navigation)),
    .init(id: "camera", title: String(localized: "摄像头"), symbol: "camera", command: .open(.camera)),
    .init(id: "space", title: String(localized: "空间"), symbol: "viewfinder", command: .open(.space)),
    .init(id: "browser", title: String(localized: "网页"), symbol: "globe", command: .open(.browser)),
    .init(id: "spaceScan", title: String(localized: "模拟扫描"), symbol: "viewfinder.circle", command: .space(.scan)),
    .init(id: "audioPlay", title: String(localized: "播放声音"), symbol: "play.circle", command: .audio(.play)),
    .init(id: "audioPause", title: String(localized: "暂停声音"), symbol: "pause.circle", command: .audio(.pause)),
    .init(id: "focus25", title: String(localized: "专注 25 分钟"), symbol: "timer", command: .startFocus(1500)),
    .init(id: "focus5", title: String(localized: "休息 5 分钟"), symbol: "cup.and.saucer", command: .startFocus(300)),
    .init(id: "pause", title: String(localized: "暂停计时"), symbol: "pause", command: .pause),
    .init(id: "resume", title: String(localized: "继续计时"), symbol: "play", command: .resume),
    .init(id: "extend", title: String(localized: "延长 5 分钟"), symbol: "plus.circle", command: .extend),
    .init(id: "cancel", title: String(localized: "结束计时"), symbol: "stop", command: .cancel),
    .init(id: "undo", title: String(localized: "撤销上一步"), symbol: "arrow.uturn.backward", command: .undo),
  ] }
}
