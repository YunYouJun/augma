import Combine
import Foundation

@MainActor
final class HomebrewCleanupStore: ObservableObject {
  enum Phase { case idle, previewing, cleaning }
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var preview: HomebrewCleanupPreview?
  @Published private(set) var receipt: HomebrewCleanupReceipt?
  @Published private(set) var error: String?
  private let client: HomebrewCleanupClient
  private var request: Task<Void, Never>?
  private var generation = 0
  var isBusy: Bool { phase != .idle }

  init(client: HomebrewCleanupClient = HomebrewCleanupClient()) { self.client = client }

  func startPreview() {
    guard !isBusy else { return }
    preview = nil; receipt = nil; error = nil
    phase = .previewing
    let token = generation
    request = Task { [weak self, client] in
      do {
        let result = try await client.preview()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.preview = result
        self.phase = .idle
      } catch {
        guard let self, self.generation == token else { return }
        self.error = error.localizedDescription
        self.phase = .idle
      }
    }
  }

  func cleanup(previewID: UUID) {
    guard !isBusy, let preview, preview.id == previewID, preview.canExecute else { return }
    phase = .cleaning; error = nil; receipt = nil
    request = Task { [weak self, client] in
      do {
        let result = try await client.cleanup(previewID: previewID)
        guard let self else { return }
        self.receipt = result
        self.preview = nil
        self.phase = .idle
      } catch {
        guard let self else { return }
        self.error = String(localized: "操作未完成；若清理已经开始，部分项目可能已移除。请重新预览。") + "\n" + error.localizedDescription
        self.preview = nil
        self.phase = .idle
      }
    }
  }

  func cancelPreview() {
    guard phase == .previewing else { return }
    generation += 1
    request?.cancel(); request = nil
    preview = nil
    phase = .idle
  }

  deinit { request?.cancel() }
}
