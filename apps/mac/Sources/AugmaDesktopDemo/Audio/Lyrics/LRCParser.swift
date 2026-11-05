import Foundation

/// Parses line timestamps, repeated timestamps, offsets and optional translations.
/// Enhanced-LRC word tags are stripped; the UI synchronizes whole lines.
enum LRCParser {
  private static let timestamp = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#)
  private static let offset = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
  private static let wordTime = try! NSRegularExpression(pattern: #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#)

  static func parse(_ original: String, translation: String? = nil) -> [LyricsLine] {
    let lines = parseSingle(original)
    guard let translation else { return lines }
    let translated = parseSingle(translation)
    return lines.map { line in
      var result = line
      if let nearest = translated.min(by: { abs($0.time - line.time) < abs($1.time - line.time) }),
         abs(nearest.time - line.time) <= 0.5, nearest.text != line.text {
        result.translation = nearest.text
      }
      return result
    }
  }

  private static func parseSingle(_ raw: String) -> [LyricsLine] {
    guard raw.utf8.count <= 1_048_576 else { return [] }
    let source = raw.replacingOccurrences(of: "\r\n", with: "\n")
    var shift: Double = 0
    if let match = offset.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
       let range = Range(match.range(at: 1), in: source), let value = Double(source[range]) {
      shift = -value / 1000
    }
    var entries: [(Double, String)] = []
    for row in source.split(separator: "\n") {
      let text = String(row)
      let matches = timestamp.matches(in: text, range: NSRange(text.startIndex..., in: text))
      guard let last = matches.last, let lastRange = Range(last.range, in: text) else { continue }
      let value = String(text[lastRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
      let content = wordTime.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "")
      for match in matches {
        guard let minutesRange = Range(match.range(at: 1), in: text), let secondsRange = Range(match.range(at: 2), in: text),
              let minutes = Double(text[minutesRange]), let seconds = Double(text[secondsRange]), seconds < 60 else { continue }
        let fraction: Double
        if let range = Range(match.range(at: 3), in: text) { fraction = Double("0." + text[range]) ?? 0 } else { fraction = 0 }
        let time = max(0, minutes * 60 + seconds + fraction + shift)
        entries.append((time, content))
      }
    }
    // Merge simultaneous lines while preserving their source order.
    let grouped = Dictionary(grouping: entries, by: { $0.0 })
    return grouped.keys.sorted().map { time in
      let values = grouped[time, default: []].map(\.1)
      let text = values.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: "\n")
      return LyricsLine(time: time, text: text)
    }
  }
}
