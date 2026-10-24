import AppKit
import Combine

/// App-owned catalog and durable layout; no camera, browser automation, or shell commands.
@MainActor
final class ApplicationDistrictStore: ObservableObject {
  @Published private(set) var buildings: [ApplicationBuilding] = []
  @Published private(set) var states: [String: ApplicationRunState] = [:]
  @Published private(set) var icons: [String: NSImage] = [:]
  @Published private(set) var suggestions: [InstalledApplication] = []
  @Published private(set) var opening: Set<String> = []
  @Published private(set) var error: String?
  @Published private(set) var loadError: String?
  @Published private(set) var saveError: String?
  @Published private(set) var canUndoRemoval = false
  var onOpen: ((String) -> Void)?
  var writable: Bool { loadError == nil && !closed }

  private let client: InstalledApplicationClient
  private let persistence: ApplicationDistrictPersisting?
  private var resolvedPaths: [String: String] = [:]
  private var tasks: [String: Task<Void, Never>] = [:]
  private var generations: [String: UUID] = [:]
  private var removed: (building: ApplicationBuilding, index: Int)?
  private var closed = false

  init(client: InstalledApplicationClient? = nil, persistence: ApplicationDistrictPersisting? = nil,
       observeLifecycle: Bool = false) {
    self.client = client ?? SystemInstalledApplicationClient()
    self.persistence = persistence
    reload()
    if observeLifecycle {
      self.client.onChange = { [weak self] in self?.refresh() }
      self.client.startObserving()
    }
  }

  func reload() {
    guard !closed else { return }
    do {
      let document = try (persistence?.load() ?? ApplicationDistrictDocument()).validated()
      buildings = document.buildings
      loadError = nil
      saveError = nil
      refresh()
    } catch { loadError = error.localizedDescription }
  }

  func rebuildUnreadableLayout() {
    guard loadError != nil, !closed else { return }
    do {
      try persistence?.preserveUnreadableFile()
      try persistence?.save(ApplicationDistrictDocument())
      loadError = nil
      buildings = []
      saveError = nil
      refresh()
    } catch { loadError = error.localizedDescription }
  }

  func refreshSuggestions() { suggestions = client.suggestions() }

  func refresh() {
    guard !closed else { return }
    let running = buildings.isEmpty ? [:] : client.runningStates()
    var next: [String: ApplicationRunState] = [:]
    let ids = Set(buildings.map(\.id))
    for id in Set(resolvedPaths.keys).subtracting(ids) { resolvedPaths[id] = nil; icons[id] = nil }
    for building in buildings {
      guard let application = client.resolve(building) else {
        next[building.id] = .missing
        resolvedPaths[building.id] = nil
        icons[building.id] = nil
        continue
      }
      next[building.id] = running[building.id] ?? .stopped
      if resolvedPaths[building.id] != application.path {
        resolvedPaths[building.id] = application.path
        icons[building.id] = client.icon(for: application)
      }
    }
    if states != next { states = next }
  }

  @discardableResult
  func add(url: URL) -> String? {
    guard writable else { return nil }
    do {
      let application = try client.inspect(url)
      var next = buildings
      if let index = next.firstIndex(where: { $0.id == application.id }) {
        next[index].applicationPath = application.path
        next[index].applicationName = application.name
      } else {
        guard next.count < ApplicationBuilding.capacity else { throw ApplicationDistrictError.full }
        let used = Set(next.map(\.slot))
        let slot = (0..<ApplicationBuilding.capacity).first { !used.contains($0) }!
        next.append(ApplicationBuilding(id: application.id, applicationName: application.name,
                                        applicationPath: application.path, slot: slot))
      }
      try commit(next)
      error = nil
      refresh()
      return application.id
    } catch { self.error = error.localizedDescription; return nil }
  }

  func rename(_ id: String, to name: String) {
    edit(id) { building in
      guard name.count <= 40, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
      else { throw ApplicationDistrictError.invalidName }
      building.nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  func setFixed(_ id: String, _ fixed: Bool) { edit(id) { $0.fixed = fixed } }

  func move(_ id: String, to slot: Int) {
    guard writable, let source = buildings.firstIndex(where: { $0.id == id }),
          (0..<ApplicationBuilding.capacity).contains(slot), buildings[source].slot != slot else { return }
    let target = buildings.firstIndex { $0.slot == slot }
    guard !buildings[source].fixed, target.map({ !buildings[$0].fixed }) ?? true else {
      error = ApplicationDistrictError.fixedPosition.localizedDescription
      return
    }
    var next = buildings
    if let target { next[target].slot = next[source].slot }
    next[source].slot = slot
    do { try commit(next); error = nil } catch { self.error = error.localizedDescription }
  }

  func remove(_ id: String) {
    guard writable, let index = buildings.firstIndex(where: { $0.id == id }) else { return }
    let previous = buildings[index]
    var next = buildings
    next.remove(at: index)
    do {
      try commit(next)
      tasks.removeValue(forKey: id)?.cancel()
      generations[id] = nil
      opening.remove(id)
      removed = (previous, index)
      canUndoRemoval = true
      error = nil
      refresh()
    } catch { self.error = error.localizedDescription }
  }

  func undoRemoval() {
    guard writable, var removed, buildings.count < ApplicationBuilding.capacity,
          !buildings.contains(where: { $0.id == removed.building.id }) else { return }
    let used = Set(buildings.map(\.slot))
    if used.contains(removed.building.slot) {
      removed.building.slot = (0..<ApplicationBuilding.capacity).first { !used.contains($0) }!
    }
    var next = buildings
    next.insert(removed.building, at: min(removed.index, next.count))
    do {
      try commit(next)
      self.removed = nil
      canUndoRemoval = false
      refresh()
    } catch { self.error = error.localizedDescription }
  }

  func restoreLayout() {
    guard writable else { return }
    let reserved = Set(buildings.filter(\.fixed).map(\.slot))
    var slots = (0..<ApplicationBuilding.capacity).filter { !reserved.contains($0) }.makeIterator()
    let next = buildings.map { building in
      var result = building
      if !result.fixed { result.slot = slots.next()! }
      return result
    }
    do { try commit(next); error = nil } catch { self.error = error.localizedDescription }
  }

  func open(_ id: String) {
    guard !closed, !opening.contains(id), let building = buildings.first(where: { $0.id == id }) else { return }
    guard let application = client.resolve(building) else {
      error = ApplicationDistrictError.missingApplication.localizedDescription
      refresh()
      return
    }
    error = nil
    let generation = UUID()
    generations[id] = generation
    opening.insert(id)
    tasks[id] = Task { [weak self, client] in
      do {
        try await client.open(application)
        guard let self, !self.closed, self.generations[id] == generation, !Task.isCancelled else { return }
        self.finishOpening(id)
        self.refresh()
        self.onOpen?(id)
      } catch {
        guard let self, !self.closed, self.generations[id] == generation, !Task.isCancelled else { return }
        self.finishOpening(id)
        self.error = error.localizedDescription
        self.refresh()
      }
    }
  }

  func retrySave() {
    guard writable else { return }
    do { try persistence?.save(ApplicationDistrictDocument(buildings: buildings)); saveError = nil }
    catch { saveError = error.localizedDescription }
  }

  func dismissError() { error = nil }

  func shutdown() {
    closed = true
    tasks.values.forEach { $0.cancel() }
    tasks.removeAll()
    generations.removeAll()
    opening.removeAll()
    client.stopObserving()
    onOpen = nil
  }

  private func edit(_ id: String, change: (inout ApplicationBuilding) throws -> Void) {
    guard writable, let index = buildings.firstIndex(where: { $0.id == id }) else { return }
    var next = buildings
    do { try change(&next[index]); try commit(next); error = nil }
    catch { self.error = error.localizedDescription }
  }

  private func commit(_ next: [ApplicationBuilding]) throws {
    _ = try ApplicationDistrictDocument(buildings: next).validated()
    guard next != buildings else { return }
    buildings = next
    retrySave()
  }

  private func finishOpening(_ id: String) { tasks[id] = nil; generations[id] = nil; opening.remove(id) }
}
