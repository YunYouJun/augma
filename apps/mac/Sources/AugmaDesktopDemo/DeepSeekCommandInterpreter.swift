import Foundation

enum DeepSeekCommandInterpreter {
  private static let allowedCommands: Set<String> = [
    "map", "scan", "audio", "audioPause", "hide", "show", "weather",
    "notifications", "settings", "camera", "dark", "light", "routeStart",
    "routeNext", "routeStop",
  ]

  private static let systemPrompt = """
    You classify Chinese voice commands for an Augma macOS DEMO. Output only a JSON object: {"command":"map"} or {"command":null}.
    Allowed command values: map (open simulated map), scan (scan simulated space), audio (play demo sound), audioPause, hide/show (HUD), weather (open demo weather panel), notifications, settings, camera (open camera panel only), dark/light (theme), routeStart, routeNext, routeStop (simulated route).
    Choose one command only when the user explicitly asks to perform that action. Do not answer questions, infer hidden intent, invent actions, or turn a request for real weather, travel, files, apps, messages, or other macOS tasks into a demo action. For ambiguous or unsupported requests return {"command":null}. Your response must be JSON.
    """

  static func interpret(_ text: String, apiKey: String) async throws -> String? {
    guard !text.isEmpty, text.utf8.count <= 500 else { throw Failure.invalidInput }
    var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!, timeoutInterval: 15)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "deepseek-flash",
      "thinking": ["type": "disabled"],
      "response_format": ["type": "json_object"],
      "max_tokens": 80,
      "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": text],
      ],
    ])
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw Failure.invalidResponse }
    switch response.statusCode {
    case 200: return try parseResponse(data)
    case 401: throw Failure.invalidKey
    case 402: throw Failure.insufficientBalance
    case 429: throw Failure.rateLimited
    default: throw Failure.http(response.statusCode)
    }
  }

  static func parseResponse(_ data: Data) throws -> String? {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = root["choices"] as? [[String: Any]],
          let choice = choices.first,
          choice["finish_reason"] as? String == "stop",
          let message = choice["message"] as? [String: Any],
          let content = message["content"] as? String,
          let body = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
          body.count == 1,
          let value = body["command"] else { throw Failure.invalidResponse }
    if value is NSNull { return nil }
    guard let command = value as? String, allowedCommands.contains(command) else {
      throw Failure.invalidResponse
    }
    return command
  }

  enum Failure: LocalizedError {
    case invalidInput, invalidKey, insufficientBalance, rateLimited, invalidResponse, http(Int)

    var errorDescription: String? {
      switch self {
      case .invalidInput: "指令为空或过长。"
      case .invalidKey: "DeepSeek 密钥无效，请在 Augma 设置中更新。"
      case .insufficientBalance: "DeepSeek 账户余额不足。"
      case .rateLimited: "DeepSeek 请求过于频繁，请稍后再试。"
      case .invalidResponse: "DeepSeek 未返回可用的演示指令。"
      case .http(let code): "DeepSeek 请求失败（HTTP \(code)）。"
      }
    }
  }
}
