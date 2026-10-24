import Foundation

/// Only these actions may be selected by an assistant response. Camera opens
/// its controls; recording and photography always require a separate action.
enum NativeAssistantAction: String, CaseIterable, Sendable {
  case map, scan, audio, audioPause, hide, show, weather, notifications, settings, camera, browser
  case dark, light, routeStart, routeNext, routeStop
}

struct NativeAssistantResult: Equatable {
  var message: String
  var isError = false
}

enum NativeAssistantCommandMatch: Equatable {
  case action(NativeAssistantAction), refused, unmatched
}

enum NativeAssistantCommandParser {
  static func match(_ transcript: String) -> NativeAssistantCommandMatch {
    let text = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let compact = text.replacingOccurrences(of: #"[\s，。！？、,.!?]"#, with: "", options: .regularExpression)
    let english = " " + text.replacingOccurrences(of: #"[^a-z']+"#, with: " ", options: .regularExpression) + " "
    func contains(_ pattern: String, in source: String = "") -> Bool {
      (source.isEmpty ? compact : source).range(of: pattern, options: .regularExpression) != nil
    }
    // Refusals win in every language, including commands that mean stop.
    if contains("不要|^别|请别|先别|ないで|だめ|ダメ|いらない")
      || contains(#"\b(?:don't|dont|do not|never)\b"#, in: english) { return .refused }

    let zhView = contains("打开|显示|查看|看看|看|启动")
    let jaView = contains("開|表示|見せ|見て|見る|出して|確認|起動")
    let enView = contains(#"\b(?:open|show|view|display|see|check|bring up|pull up|go to|launch)\b"#, in: english)
    let rules: [(NativeAssistantAction, Bool)] = [
      (.audioPause, (contains("暂停|停止|关闭") && contains("声音|音乐|播放"))
        || (contains("一時停止|停止|止め|ストップ|やめ") && contains("音|サウンド|再生"))
        || (contains(#"\b(?:pause|stop|mute)\b"#, in: english) && contains(#"\b(?:sound|music|audio|playback)\b"#, in: english))),
      (.routeStop, (contains("结束|停止|取消") && contains("导航|路线"))
        || (contains("終了|停止|止め|やめ|キャンセル|終わ") && contains("ナビ|ルート|案内"))
        || (contains(#"\b(?:end|stop|cancel|exit|quit)\b"#, in: english) && contains(#"\b(?:navigation|navigating|route|directions)\b"#, in: english))),
      (.routeNext, contains("下一步|前进一步|继续前进|次へ|次のステップ|一歩進|前へ進|先に進")
        || contains(#"\b(?:next step|step forward|move forward|go forward|keep going)\b"#, in: english)),
      (.light, (contains("关闭深色|浅色|亮色|日间") && contains("模式|视界|主题|深色"))
        || (contains("ダーク|夜間") && contains("オフ|解除|消"))
        || (contains("ライト|明るい|日中|昼間") && contains("モード|テーマ|表示|ビュー"))
        || (contains(#"\b(?:turn off|disable|exit)\b"#, in: english) && contains(#"\bdark\b"#, in: english))
        || (contains(#"\b(?:light|day)\b"#, in: english) && contains(#"\b(?:mode|theme|view)\b"#, in: english))),
      (.dark, (contains("开启|打开|切换|显示") && contains("深色|夜间"))
        || (contains("ダーク|暗い|夜間|ナイト") && contains("オン|にして|切り替え|有効|つけ"))
        || (contains(#"\b(?:turn on|enable|switch to|use|open|show|go)\b"#, in: english) && contains(#"\b(?:dark|night)\b"#, in: english))),
      (.hide, (contains("隐藏|收起|关闭|关掉") && contains("hud|界面|视界|面板"))
        || (contains("隠し|隠す|非表示|閉じ|しまって") && contains("hud|インターフェース|画面|ui|パネル|ビュー"))
        || (contains(#"\b(?:hide|collapse|close|dismiss)\b"#, in: english) && contains(#"\b(?:hud|interface|ui|overlay|panel|view)\b"#, in: english))),
      (.show, (contains("显示|展开|恢复") && contains("hud|界面|视界"))
        || (contains("表示|見せ|出して|戻して|復元") && contains("hud|インターフェース|ui"))
        || (contains(#"\b(?:show|restore|bring back|display)\b"#, in: english) && contains(#"\b(?:hud|interface|ui|overlay)\b"#, in: english))),
      (.routeStart, (contains("开始|启动") && contains("导航|路线"))
        || (contains("開始|始め|スタート") && contains("ナビ|ルート|案内"))
        || (contains(#"\b(?:start|begin)\b"#, in: english) && contains(#"\b(?:navigation|navigating|route|directions)\b"#, in: english))),
      (.scan, (contains("扫描|识别|探测") && contains("空间|周围|环境|附近"))
        || (contains("スキャン|認識|検出") && contains("空間|周り|周囲|環境|近く|まわり|部屋"))
        || (contains(#"\b(?:scan|detect)\b"#, in: english) && contains(#"\b(?:space|room|surroundings|area|environment|around)\b"#, in: english))),
      (.map, (contains("地图|导航|路线") && zhView) || (contains("地図|マップ|ナビ|ルート") && jaView)
        || (contains(#"\b(?:map|navigation|route|directions)\b"#, in: english) && enView)),
      (.weather, (contains("天气|气温|温度") && zhView) || (contains("天気|気温|温度") && jaView)
        || (contains(#"\b(?:weather|temperature|forecast)\b"#, in: english) && enView)),
      (.notifications, (contains("通知|消息") && zhView) || (contains("通知|メッセージ|お知らせ") && jaView)
        || (contains(#"\b(?:notifications?|messages?|alerts?)\b"#, in: english) && (enView || contains(#"\bread\b"#, in: english)))),
      (.settings, (contains("设置") && zhView) || (contains("設定") && jaView)
        || (contains(#"\b(?:settings|preferences)\b"#, in: english) && enView)),
      (.camera, (contains("摄像头|相机") && zhView) || (contains("カメラ") && (jaView || contains("オン|つけ")))
        || (contains(#"\bcamera\b"#, in: english) && (enView || contains(#"\b(?:turn on|start)\b"#, in: english)))),
      (.browser, (contains("网页|浏览器") && zhView) || (contains("ブラウザ|ウェブ") && jaView)
        || (contains(#"\b(?:browser|web|website)\b"#, in: english) && enView)),
      (.audio, (contains("声音|音乐|音频") && contains("播放|打开|放|听"))
        || (contains("音|サウンド|オーディオ") && contains("再生|流して|かけて|聴|聞|オン|つけ"))
        || (contains(#"\b(?:sound|music|audio|soundscape)\b"#, in: english) && contains(#"\b(?:play|open|start|turn on|listen)\b"#, in: english))),
    ]
    return rules.first(where: { $0.1 }).map { .action($0.0) } ?? .unmatched
  }
}
