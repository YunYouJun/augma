import AppKit
import Darwin
import Foundation

struct ApplicationMemoryIdentity: Sendable {
  var processIdentifier: Int32
  var name: String
  var bundlePath: String
  var launchedAt: Date? = nil
}

struct ApplicationMemoryUsage: Identifiable, Sendable {
  var id: String { application.bundlePath }
  var application: ApplicationMemoryIdentity
  var physicalFootprint: UInt64 = 0
  var processCount: Int = 0
  var measuredProcessCount: Int = 0
  var unreadableProcessCount: Int { processCount - measuredProcessCount }
}

struct ApplicationMemorySnapshot: Sendable {
  var applications: [ApplicationMemoryUsage]
  var topApplications: [ApplicationMemoryUsage] { Array(applications.prefix(3)) }
}

/// Keep failed memory reads in the topology: their children can still belong to an app.
struct ApplicationMemoryProcess: Sendable {
  var pid: Int32
  var parentPID: Int32
  var startedAt: UInt64
  var executablePath: String?
  var physicalFootprint: UInt64?
}

enum ApplicationMemoryAggregation {
  /// The outer app owns nested helper apps, including helpers reparented to launchd.
  static func applicationPath(for executablePath: String) -> String? {
    let components = URL(filePath: executablePath).standardizedFileURL.pathComponents
    guard let end = components.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) else { return nil }
    return NSString.path(withComponents: Array(components[...end]))
  }

  static func aggregate(
    applications: [ApplicationMemoryIdentity], processes: [ApplicationMemoryProcess]
  ) -> ApplicationMemorySnapshot {
    let apps = Dictionary(applications.map { ($0.bundlePath, $0) }, uniquingKeysWith: { first, _ in first })
    let roots = Dictionary(applications.map { ($0.processIdentifier, $0.bundlePath) }, uniquingKeysWith: { first, _ in first })
    let byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    var owners: [Int32: String] = [:]
    var unowned: Set<Int32> = []

    func owner(of process: ApplicationMemoryProcess) -> String? {
      var current = process
      var visited: Set<Int32> = []
      var bundleOwner: String?
      while visited.insert(current.pid).inserted {
        if let cached = owners[current.pid] { return cached }
        if unowned.contains(current.pid) { return bundleOwner }
        if let path = current.executablePath, let appPath = applicationPath(for: path) {
          // A separately launched app belongs to itself. A tool executable inside
          // another app bundle (e.g. Xcode's git) still belongs to its live launcher.
          if roots[current.pid] == appPath { return appPath }
          if apps[appPath] != nil, bundleOwner == nil { bundleOwner = appPath }
        }
        guard current.parentPID > 1, let parent = byPID[current.parentPID],
          parent.startedAt <= current.startedAt
        else { return bundleOwner }
        current = parent
      }
      return nil // Broken/cyclic ancestry must not turn into a guessed association.
    }

    var totals: [String: ApplicationMemoryUsage] = [:]
    for process in byPID.values.sorted(by: { $0.pid < $1.pid }) {
      guard let path = owner(of: process), let app = apps[path] else {
        unowned.insert(process.pid)
        continue
      }
      owners[process.pid] = path
      var usage = totals[path] ?? ApplicationMemoryUsage(application: app)
      usage.processCount += 1
      if let bytes = process.physicalFootprint {
        let (total, overflow) = usage.physicalFootprint.addingReportingOverflow(bytes)
        // Do not wrap a malformed counter into a plausible small memory value.
        if !overflow {
          usage.physicalFootprint = total
          usage.measuredProcessCount += 1
        }
      }
      totals[path] = usage
    }
    return ApplicationMemorySnapshot(applications: totals.values.sorted {
      let leftAvailable = $0.measuredProcessCount > 0
      let rightAvailable = $1.measuredProcessCount > 0
      if leftAvailable != rightAvailable { return leftAvailable }
      if $0.physicalFootprint != $1.physicalFootprint { return $0.physicalFootprint > $1.physicalFootprint }
      // Stable ordering keeps equal-valued rows from jumping on every refresh.
      return $0.id < $1.id
    })
  }
}

enum ApplicationMemoryReader {
  static func sample() async -> ApplicationMemorySnapshot? {
    let apps = await MainActor.run {
      NSWorkspace.shared.runningApplications.compactMap { app -> ApplicationMemoryIdentity? in
        guard !app.isTerminated, app.activationPolicy != .prohibited,
          let url = app.bundleURL,
          let path = ApplicationMemoryAggregation.applicationPath(for: url.path)
        else { return nil }
        return ApplicationMemoryIdentity(processIdentifier: app.processIdentifier,
                                         name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                                         bundlePath: path, launchedAt: app.launchDate)
      }
    }
    guard !Task.isCancelled, let pids = processIDs() else { return nil }
    var processes: [ApplicationMemoryProcess] = []
    for pid in pids {
      guard !Task.isCancelled else { return nil }
      guard let before = bsdInfo(pid), before.pbi_uid == getuid() else { continue }
      // PROC_PIDPATHINFO_MAXSIZE is a C expression macro that Swift cannot import.
      var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
      let pathLength = proc_pidpath(pid, &path, UInt32(path.count))
      let executablePath = pathLength > 0
        ? String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) : nil
      var usage = rusage_info_v0()
      let result = withUnsafeMutablePointer(to: &usage) { pointer in
        pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
          proc_pid_rusage(pid, RUSAGE_INFO_V0, $0)
        }
      }
      // PID reuse or exit during a read must not assign a new process to an old app.
      guard let after = bsdInfo(pid), before.pbi_start_tvsec == after.pbi_start_tvsec,
        before.pbi_start_tvusec == after.pbi_start_tvusec, before.pbi_ppid == after.pbi_ppid,
        before.pbi_uid == after.pbi_uid
      else { continue }
      processes.append(ApplicationMemoryProcess(
        pid: pid, parentPID: Int32(before.pbi_ppid),
        startedAt: before.pbi_start_tvsec * 1_000_000 + before.pbi_start_tvusec,
        executablePath: executablePath,
        physicalFootprint: result == 0 && usage.ri_proc_exit_abstime == 0 ? usage.ri_phys_footprint : nil
      ))
    }
    return ApplicationMemoryAggregation.aggregate(applications: apps, processes: processes)
  }

  private static func processIDs() -> [Int32]? {
    // Leave room for launches between the count and fill calls; retry a full buffer.
    let count = proc_listallpids(nil, 0)
    guard count > 0 else { return nil }
    var capacity = Int(count) + 256
    for _ in 0..<3 {
      var pids = [Int32](repeating: 0, count: capacity)
      let filled = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
      guard filled > 0 else { return nil }
      if filled < capacity { return Array(Set(pids.prefix(Int(filled)).filter { $0 > 1 })) }
      capacity *= 2
    }
    return nil
  }

  private static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
    return info
  }
}
