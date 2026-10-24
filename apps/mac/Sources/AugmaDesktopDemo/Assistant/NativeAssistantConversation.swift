import Foundation

struct NativeAssistantAnswer: Equatable, Sendable {
  let reply: String
  let command: NativeAssistantAction?
}

struct NativeAssistantTurn: Equatable, Sendable {
  let question: String
  let answer: NativeAssistantAnswer
}

enum NativeAssistantConversation {
  static let maxQuestionLength = 500
  static let maxReplyLength = 600
  static let historyLimit = 4

  static func messages(question: String, locale: String, history: [NativeAssistantTurn]) throws -> [[String: String]] {
    let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= maxQuestionLength else { throw DeepSeekClient.Failure.invalidInput }
    var messages = [["role": "system", "content": systemPrompt(locale: locale)]]
    for turn in history.suffix(historyLimit) {
      let data = try JSONSerialization.data(withJSONObject: [
        "reply": String(turn.answer.reply.prefix(maxReplyLength)),
        "command": turn.answer.command.map { $0.rawValue as Any } ?? NSNull(),
      ])
      messages.append(["role": "user", "content": String(turn.question.prefix(maxQuestionLength))])
      messages.append(["role": "assistant", "content": String(decoding: data, as: UTF8.self)])
    }
    messages.append(["role": "user", "content": text])
    return try DeepSeekClient.validate(messages)
  }

  static func parse(_ content: String) throws -> NativeAssistantAnswer {
    guard content.utf8.count <= 16_384, let data = content.data(using: .utf8),
          let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          Set(body.keys) == ["reply", "command"], let rawReply = body["reply"] as? String else {
      throw DeepSeekClient.Failure.invalidResponse
    }
    let command: NativeAssistantAction?
    if body["command"] is NSNull { command = nil }
    else if let value = body["command"] as? String, let action = NativeAssistantAction(rawValue: value) { command = action }
    else { throw DeepSeekClient.Failure.invalidResponse }
    let reply = String(rawReply.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxReplyLength))
    guard command != nil || !reply.isEmpty else { throw DeepSeekClient.Failure.invalidResponse }
    return NativeAssistantAnswer(reply: reply, command: command)
  }

  private static func systemPrompt(locale: String) -> String {
    let language = locale.hasPrefix("en") ? "English" : locale.hasPrefix("ja") ? "Japanese" : "Simplified Chinese"
    return """
    You are Augma, the assistant of a native macOS app. Always answer in \(language).
    Output only a JSON object: {"reply": string, "command": string or null}.
    Set command only when the user explicitly asks for one of these supported actions, otherwise null:
    - map: open the native map and route planning controls
    - scan: start a simulated scan in the native 3D space
    - audio / audioPause: play / pause the app soundscape
    - hide / show: hide / show the HUD
    - weather: open the weather panel
    - notifications / settings: open that app panel
    - camera: open camera controls only; never activate the camera or take a photo
    - browser: open the app web browser controls only; never select or navigate to a URL
    - dark / light: switch the theme
    - routeStart / routeNext / routeStop: start, advance or end the simulated 3D-space route
    When command is set, the app announces the real result, so set reply to "".
    Otherwise reply in at most two short plain-text sentences, without Markdown, lists, emoji or links.
    You cannot read the current map, weather, system metrics, location, files, other apps, messages or browser content. Panels may retrieve live data, but their data is not included here. Space scanning and route progress are simulated. Never invent live readings or claim to perform unsupported actions. Never execute a negated or refused request. If asked for something unsupported, say so briefly and suggest an available action.
    """
  }
}
