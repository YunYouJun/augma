import Combine
import Foundation

/// A window-owned, nonpersistent scan. Closing or changing scope cancels work and rejects late callbacks.
@MainActor
final class DiskUsageStore: ObservableObject {
  @Published private(set) var snapshot: DiskUsageSnapshot?
  @Published private(set) var scanning = false
  @Published private(set) var progress = DiskUsageProgress()
  @Published private(set) var feedback = ""
  @Published private(set) var root: URL?
  @Published private(set) var focusedPath: String?
  @Published var metric: DiskUsageMetric = .allocated
  private let scanner: any DiskUsageScanning
  private var request: Task<Void, Never>?
  private var generation = UUID()

  init(scanner: any DiskUsageScanning = DiskUsageScanner()) { self.scanner = scanner }

  var focusedNode: DiskUsageNode? {
    guard let snapshot else { return nil }
    return focusedPath.flatMap { snapshot.root.find($0) } ?? snapshot.root
  }

  func start(_ url: URL) {
    cancel()
    let root = url.standardizedFileURL
    self.root = root; snapshot = nil; focusedPath = nil; progress = .init(); feedback = ""
    scanning = true
    let generation = self.generation
    request = Task { [weak self, scanner] in
      do {
        let result = try await scanner.scan(root) { [weak self] update in
          Task { @MainActor [weak self] in
            guard let self, self.generation == generation, self.scanning else { return }
            self.progress = update
          }
        }
        guard let self, self.generation == generation, !Task.isCancelled else { return }
        self.snapshot = result; self.focusedPath = result.root.id; self.scanning = false
      } catch {
        guard let self, self.generation == generation, !Task.isCancelled else { return }
        self.feedback = error.localizedDescription; self.scanning = false
      }
    }
  }

  func focus(_ node: DiskUsageNode) {
    guard node.isDirectory, snapshot?.root.find(node.id) != nil else { return }
    focusedPath = node.id
  }

  func goUp() {
    guard let node = focusedNode, node.id != snapshot?.root.id,
      let parent = snapshot?.root.find(node.url.deletingLastPathComponent().path) else { return }
    focus(parent)
  }

  func cancel() {
    generation = UUID(); request?.cancel(); request = nil
    if scanning { feedback = String(localized: "扫描已取消，未生成完整结果。") }
    scanning = false
  }

  deinit { request?.cancel() }
}
