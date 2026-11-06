import AppKit

/// Candidate navigation belongs to the input method until the field editor commits its marked text.
@MainActor
enum NativeCommandInputRouting {
  @discardableResult
  static func navigate(editor: (any NSTextInputClient)?, perform: () -> Void) -> Bool {
    guard editor?.hasMarkedText() != true else { return false }
    perform()
    return true
  }
}
