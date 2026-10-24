import Foundation

/// Sends the native assistant's bounded conversation using a Keychain key.
/// NativeAssistantConversation owns the prompt and strict action allowlist.
enum DeepSeekClient {
  /// System prompt, four earlier exchanges and the question fit well within these limits.
  static let maxMessages = 12
  static let maxCharacters = 12_000

  static func complete(_ messages: [[String: String]], apiKey: String) async throws -> String {
    var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "deepseek-flash",
      "thinking": ["type": "disabled"],
      "response_format": ["type": "json_object"],
      "max_tokens": 300,
      "messages": messages,
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

  /// Accept only plain chat messages that end with the user's question.
  static func validate(_ value: Any?) throws -> [[String: String]] {
    guard let items = value as? [[String: Any]], (2...maxMessages).contains(items.count) else {
      throw Failure.invalidInput
    }
    var characters = 0
    let messages = try items.map { item -> [String: String] in
      guard item.count == 2,
            let role = item["role"] as? String, ["system", "user", "assistant"].contains(role),
            let content = item["content"] as? String, !content.isEmpty else { throw Failure.invalidInput }
      characters += content.count
      return ["role": role, "content": content]
    }
    guard characters <= maxCharacters, messages.last?["role"] == "user" else { throw Failure.invalidInput }
    return messages
  }

  static func parseResponse(_ data: Data) throws -> String {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = root["choices"] as? [[String: Any]],
          let choice = choices.first,
          choice["finish_reason"] as? String == "stop",
          let message = choice["message"] as? [String: Any],
          let content = message["content"] as? String,
          !content.isEmpty else { throw Failure.invalidResponse }
    return content
  }

  enum Failure: Error {
    case invalidInput, invalidKey, insufficientBalance, rateLimited, invalidResponse, http(Int)

    /// Stable error code, also used by the standalone browser counterpart.
    var code: String {
      switch self {
      case .invalidInput: "deepseekInvalidInput"
      case .invalidKey: "deepseekInvalidKey"
      case .insufficientBalance: "deepseekInsufficientBalance"
      case .rateLimited: "deepseekRateLimited"
      case .invalidResponse: "deepseekInvalidResponse"
      case .http: "deepseekHttp"
      }
    }

    var detail: String? {
      if case .http(let status) = self { return String(status) }
      return nil
    }
  }
}
