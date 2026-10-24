import Combine
import Foundation

/// App-owned configurations, edits and results; scene stores own only selection and camera pose.
@MainActor
final class ProjectWorkspaceStore: ObservableObject {
  let craftHub: CraftHubConnectionStore
  @Published private(set) var regions: [ProjectRegion] = []
  @Published private(set) var drafts: [UUID: ProjectRegionDraft] = [:]
  @Published private(set) var reports: [UUID: ProjectOpenReport] = [:]
  @Published private(set) var openingID: UUID?
  @Published private(set) var error: String?
  @Published private(set) var loadError: String?
  @Published private(set) var saveError: String?
  @Published private(set) var canUndoRemoval = false
  var onOpenCompleted: ((UUID) -> Void)?
  var writable: Bool { loadError == nil && !closed }
  var editable: Bool { writable && openingID == nil }
  var hasUnsavedDrafts: Bool { regions.contains { draft(for: $0) != ProjectRegionDraft($0) } }
  private let client: ProjectWorkspaceClient
  private let persistence: ProjectWorkspacePersisting?
  private var removed: ProjectRegion?
  private var task: Task<Void, Never>?
  private var generation = UUID()
  private var closed = false
  private var connectionChanges: AnyCancellable?

  init(client: ProjectWorkspaceClient? = nil, persistence: ProjectWorkspacePersisting? = nil,
       craftHub: CraftHubConnectionStore? = nil) {
    self.client = client ?? SystemProjectWorkspaceClient()
    self.persistence = persistence
    self.craftHub = craftHub ?? CraftHubConnectionStore()
    connectionChanges = self.craftHub.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    reload()
  }

  func displayName(_ region: ProjectRegion) -> String { craftHub.context(for: region.craftHub)?.project.name ?? region.name }
  var presentedRegions: [ProjectRegion] {
    regions.map { region in var value = region; value.name = displayName(region); return value }
  }

  /// Binding changes only the source reference. The independent configuration remains available after unlinking.
  func bind(_ id: UUID, to binding: CraftHubProjectBinding) {
    guard craftHub.context(for: binding) != nil else { error = CraftHubError.changed.localizedDescription; return }
    edit(id) { $0.craftHub = binding }
    if error == nil { reports[id] = nil }
  }
  func unlink(_ id: UUID) {
    edit(id) { $0.craftHub = nil }
    if error == nil { reports[id] = nil }
  }
  @discardableResult func add(binding: CraftHubProjectBinding) -> UUID? {
    guard editable, let context = craftHub.context(for: binding) else { return nil }
    do {
      guard regions.count < ProjectRegion.capacity else { throw ProjectWorkspaceError.full }
      let folder = try client.captureFolder(URL(fileURLWithPath: context.project.path))
      let used = Set(regions.map(\.slot))
      let region = ProjectRegion(name: String(context.project.name.prefix(60)), folder: folder,
        editor: client.defaultApplication("com.microsoft.VSCode"), browser: client.defaultApplication("com.google.Chrome"),
        slot: (0..<ProjectRegion.capacity).first { !used.contains($0) }!, craftHub: binding)
      try commit(regions + [region]); error = nil
      return region.id
    } catch { self.error = error.localizedDescription; return nil }
  }
  func refreshBinding(_ id: UUID) async {
    guard let binding = regions.first(where: { $0.id == id })?.craftHub else { return }
    do { try await craftHub.read(binding) }
    catch { /* The connection panel and binding card display the failure without changing local configuration. */ }
  }

  func reload() {
    guard !closed, openingID == nil else { return }
    do {
      regions = try (persistence?.load() ?? ProjectWorkspaceDocument()).validated().regions
      drafts = [:]; reports = [:]; removed = nil; canUndoRemoval = false
      loadError = nil; saveError = nil; error = nil
    } catch { loadError = error.localizedDescription }
  }

  func rebuildUnreadableConfiguration() {
    guard loadError != nil, !closed else { return }
    do {
      try persistence?.preserveUnreadableFile()
      try persistence?.save(ProjectWorkspaceDocument())
      reload()
    } catch { loadError = error.localizedDescription }
  }

  @discardableResult func add(folderURL: URL) -> UUID? {
    guard editable else { return nil }
    do {
      guard regions.count < ProjectRegion.capacity else { throw ProjectWorkspaceError.full }
      let folder = try client.captureFolder(folderURL)
      let used = Set(regions.map(\.slot))
      let region = ProjectRegion(name: String(folderURL.lastPathComponent.prefix(60)), folder: folder,
        editor: client.defaultApplication("com.microsoft.VSCode"), browser: client.defaultApplication("com.google.Chrome"),
        slot: (0..<ProjectRegion.capacity).first { !used.contains($0) }!)
      try commit(regions + [region])
      error = nil
      return region.id
    } catch { self.error = error.localizedDescription; return nil }
  }

  func draft(for region: ProjectRegion) -> ProjectRegionDraft { drafts[region.id] ?? ProjectRegionDraft(region) }
  func setDraft(_ id: UUID, _ draft: ProjectRegionDraft) {
    guard editable, regions.contains(where: { $0.id == id }) else { return }
    drafts[id] = draft
  }
  func discardDraft(_ id: UUID) { guard editable else { return }; drafts[id] = nil; error = nil }

  @discardableResult func saveDraft(_ id: UUID) -> Bool {
    guard editable, let index = regions.firstIndex(where: { $0.id == id }) else { return false }
    do {
      let draft = draft(for: regions[index])
      let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard ProjectWorkspaceDocument.validName(name) else { throw ProjectWorkspaceError.invalidName }
      var next = regions
      next[index].name = name
      next[index].websites = try ProjectWebsite.parse(draft.websites)
      if next[index] != regions[index] { reports[id] = nil }
      try commit(next)
      drafts[id] = nil; error = nil
      return true
    } catch { self.error = error.localizedDescription; return false }
  }

  func rebindFolder(_ id: UUID, url: URL) {
    guard regions.first(where: { $0.id == id })?.craftHub == nil else { return }
    edit(id) { $0.folder = try client.captureFolder(url) }
    if error == nil { setResult(id, "editor", .failed(String(localized: "项目文件夹已变更，请重新打开。"))) }
  }
  func bindApplication(_ id: UUID, url: URL, editor: Bool) {
    edit(id) {
      let binding = try client.inspectApplication(url, expectedID: editor ? "com.microsoft.VSCode" : "com.google.Chrome")
      if editor { $0.editor = binding } else { $0.browser = binding }
    }
  }
  func move(_ id: UUID, to slot: Int) {
    guard editable, (0..<ProjectRegion.capacity).contains(slot), let index = regions.firstIndex(where: { $0.id == id }) else { return }
    var next = regions
    if let other = next.firstIndex(where: { $0.slot == slot }) { next[other].slot = next[index].slot }
    next[index].slot = slot
    do { try commit(next); error = nil } catch { self.error = error.localizedDescription }
  }
  func remove(_ id: UUID) {
    guard writable, let region = regions.first(where: { $0.id == id }) else { return }
    if openingID == id { cancelOpening() }
    do {
      try commit(regions.filter { $0.id != id })
      removed = region; canUndoRemoval = true; drafts[id] = nil; reports[id] = nil; error = nil
    } catch { self.error = error.localizedDescription }
  }
  func undoRemoval() {
    guard editable, var removed, regions.count < ProjectRegion.capacity else { return }
    let used = Set(regions.map(\.slot))
    if used.contains(removed.slot) { removed.slot = (0..<ProjectRegion.capacity).first { !used.contains($0) }! }
    do {
      try commit(regions + [removed]); self.removed = nil; canUndoRemoval = false; error = nil
    } catch { self.error = error.localizedDescription }
  }
  func revealFolder(_ id: UUID) {
    guard let region = regions.first(where: { $0.id == id }) else { return }
    do { try client.revealFolder(region.folder); error = nil } catch { self.error = error.localizedDescription }
  }

  func open(_ id: UUID, failedOnly: Bool = false) {
    guard editable else { return }
    if failedOnly, let region = regions.first(where: { $0.id == id }), draft(for: region) != ProjectRegionDraft(region) {
      error = String(localized: "配置已修改，请保存后重新打开工作区。")
      return
    }
    guard saveDraft(id), saveError == nil, let region = regions.first(where: { $0.id == id }) else { return }
    let items = [ProjectOpenItem(id: "editor", title: "VS Code · " + region.name)] +
      region.websites.map { ProjectOpenItem(id: $0, title: $0) }
    let pending: [String]
    if failedOnly {
      guard let report = reports[id] else { return }
      pending = report.items.compactMap {
        switch $0.state { case .failed, .cancelled: $0.id; default: nil }
      }
      guard !pending.isEmpty else { return }
      for itemID in pending { setResult(id, itemID, .waiting) }
    } else {
      reports[id] = ProjectOpenReport(regionID: id, items: items)
      pending = items.map(\.id)
    }
    openingID = id
    let generation = UUID(); self.generation = generation
    task = Task { [weak self, client] in
      var folder = region.folder
      if let binding = region.craftHub {
        do {
          guard let self else { return }
          let context = try await self.craftHub.read(binding)
          guard self.generation == generation, !Task.isCancelled else { return }
          folder = try client.captureFolder(URL(fileURLWithPath: context.project.path))
        } catch {
          guard let self, self.generation == generation, !Task.isCancelled else { return }
          for itemID in pending { self.setResult(id, itemID, .failed(error.localizedDescription)) }
          self.openingID = nil; self.task = nil
          return
        }
      }
      for itemID in pending {
        guard let self, self.generation == generation, !Task.isCancelled else { return }
        if let binding = region.craftHub, self.craftHub.context(for: binding) == nil {
          self.cancelOpening()
          return
        }
        self.setResult(id, itemID, .opening)
        do {
          if itemID == "editor" { try await client.openEditor(folder: folder, application: region.editor) }
          else if let url = URL(string: itemID) { try await client.openWebsite(url, application: region.browser) }
          else { throw ProjectWorkspaceError.invalidWebsite }
          guard self.generation == generation, !Task.isCancelled else { return }
          self.setResult(id, itemID, .opened)
        } catch {
          guard self.generation == generation, !Task.isCancelled else { return }
          self.setResult(id, itemID, .failed(error.localizedDescription))
        }
      }
      guard let self, self.generation == generation, !Task.isCancelled else { return }
      self.openingID = nil; self.task = nil
      if self.reports[id]?.items.allSatisfy({ $0.state == .opened }) == true { self.onOpenCompleted?(id) }
    }
  }

  func cancelOpening() {
    generation = UUID(); task?.cancel(); task = nil
    if let id = openingID, let items = reports[id]?.items {
      for item in items where item.state == .waiting || item.state == .opening { setResult(id, item.id, .cancelled) }
    }
    openingID = nil
  }

  func retrySave() {
    guard writable else { return }
    do { try persistence?.save(ProjectWorkspaceDocument(regions: regions)); saveError = nil }
    catch { saveError = error.localizedDescription }
  }
  func flush() -> Bool {
    cancelOpening()
    guard loadError == nil else { return true } // No unsaved edits were allowed to the unreadable file.
    for region in regions where draft(for: region) != ProjectRegionDraft(region) {
      if !saveDraft(region.id) { return false }
    }
    retrySave()
    return saveError == nil
  }
  func dismissError() { error = nil }
  func shutdown() { cancelOpening(); closed = true; onOpenCompleted = nil; craftHub.shutdown(); connectionChanges = nil }

  private func edit(_ id: UUID, change: (inout ProjectRegion) throws -> Void) {
    guard editable, let index = regions.firstIndex(where: { $0.id == id }) else { return }
    var next = regions
    do { try change(&next[index]); try commit(next); error = nil }
    catch { self.error = error.localizedDescription }
  }
  private func commit(_ regions: [ProjectRegion]) throws {
    _ = try ProjectWorkspaceDocument(regions: regions).validated()
    self.regions = regions
    retrySave()
  }
  private func setResult(_ regionID: UUID, _ itemID: String, _ state: ProjectOpenState) {
    guard let index = reports[regionID]?.items.firstIndex(where: { $0.id == itemID }) else { return }
    reports[regionID]?.items[index].state = state
  }
}
