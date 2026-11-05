import Combine
import Foundation

@MainActor
final class CodexStorageStore: ObservableObject {
  enum Phase { case idle, scanning, previewing, analyzing, cleaning }
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var scan: CodexStorageScan?
  @Published var selection: Set<UUID> = [] { didSet { preview = nil } }
  @Published private(set) var preview: CodexStoragePreview?
  @Published private(set) var receipt: CodexStorageReceipt?
  @Published private(set) var moleReport: MoleDiskReport?
  @Published private(set) var moleScopeID: String?
  @Published private(set) var moleCheckedAt: Date?
  @Published private(set) var error: String?
  var canStartOperation: () -> Bool = { true }
  private let client: any CodexStorageProviding
  private let mole: any MoleToolProviding
  private var request: Task<Void, Never>?
  private var generation = 0

  init(
    client: any CodexStorageProviding = CodexStorageScanner(),
    mole: any MoleToolProviding = MoleToolClient()
  ) {
    self.client = client
    self.mole = mole
  }

  var isBusy: Bool { phase != .idle }

  func startScan() {
    guard !isBusy, canStartOperation() else { return }
    generation += 1
    let token = generation
    phase = .scanning
    scan = nil
    selection = []
    preview = nil
    moleReport = nil
    moleScopeID = nil
    moleCheckedAt = nil
    error = nil
    request = Task { [weak self, client] in
      do {
        let result = try await client.scan()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.scan = result
        self.phase = .idle
        self.request = nil
      } catch {
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.error = error.localizedDescription
        self.phase = .idle
        self.request = nil
      }
    }
  }

  func buildPreview() {
    guard !isBusy, canStartOperation(), let scan, !selection.isEmpty else { return }
    generation += 1
    let token = generation
    let selected = selection
    phase = .previewing
    preview = nil
    error = nil
    request = Task { [weak self, client] in
      do {
        let result = try await client.preview(scanID: scan.id, ids: selected)
        guard let self, self.generation == token, !Task.isCancelled, self.scan?.id == scan.id else {
          return
        }
        if self.selection == selected { self.preview = result }
        self.phase = .idle
        self.request = nil
      } catch {
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.error = error.localizedDescription
        self.phase = .idle
        self.request = nil
      }
    }
  }

  func analyzeWithMole(scopeID: String) {
    guard !isBusy, canStartOperation(), let scan,
      scan.scopes.contains(where: { $0.id == scopeID && $0.canAnalyzeWithMole })
    else { return }
    generation += 1
    let token = generation
    phase = .analyzing
    moleReport = nil
    moleScopeID = nil
    moleCheckedAt = nil
    error = nil
    request = Task { [weak self, client, mole] in
      do {
        let installation = try await mole.inspect()
        guard installation.version != nil else { throw MoleToolError.missing }
        guard installation.supported else { throw MoleToolError.unsupported }
        try Task.checkCancellation()
        let scope = try await client.moleScope(scanID: scan.id, scopeID: scopeID)
        let result = try await mole.analyze(scope: scope)
        guard let self, self.generation == token, self.scan?.id == scan.id, !Task.isCancelled else {
          return
        }
        self.moleReport = result
        self.moleScopeID = scopeID
        self.moleCheckedAt = .now
        self.phase = .idle
        self.request = nil
      } catch {
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.error = error.localizedDescription
        self.phase = .idle
        self.request = nil
      }
    }
  }

  func restoreReceipt() async {
    guard !isBusy, receipt == nil else { return }
    do {
      let result = try await client.lastReceipt()
      if !isBusy, receipt == nil { receipt = result }
    } catch { if !isBusy { self.error = error.localizedDescription } }
  }

  /// Called only after reviewing the immutable, itemized confirmation sheet.
  func execute(_ confirmed: CodexStoragePreview) {
    guard !isBusy, canStartOperation(), preview?.id == confirmed.id,
      selection == Set(confirmed.items.map(\.id))
    else { return }
    phase = .cleaning
    error = nil
    // Retain the owner until the operation has produced a receipt; closing cannot cancel a mutation.
    request = Task { [self, client] in
      do {
        receipt = try await client.execute(
          previewID: confirmed.id, confirmedIDs: Set(confirmed.items.map(\.id)))
      } catch { self.error = error.localizedDescription }
      scan = nil
      selection = []
      preview = nil
      moleReport = nil
      moleScopeID = nil
      moleCheckedAt = nil
      phase = .idle
      request = nil
    }
  }

  func cancelReadOnly() {
    guard phase != .cleaning else { return }
    generation += 1
    request?.cancel()
    request = nil
    phase = .idle
  }

  deinit { request?.cancel() }
}
