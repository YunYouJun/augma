import Darwin
import Foundation

/// Reads metadata only. Descriptor-relative traversal never follows a discovered symlink or crosses volumes.
actor DiskUsageScanner: DiskUsageScanning {
  private struct Identity: Hashable {
    let device: dev_t
    let inode: ino_t
    init(_ info: stat) { device = info.st_dev; inode = info.st_ino }
  }

  private struct State {
    let deadline: ContinuousClock.Instant
    var remaining: Int
    var progress = DiskUsageProgress()
    var files: Set<Identity> = []
    var skippedSymlinks = 0
    var duplicateFiles = 0
    var skippedSpecialFiles = 0
    var issues: [DiskUsageIssue] = []
    var omittedIssues = 0
    var stopped = false

    mutating func issue(_ url: URL, _ reason: DiskUsageIssue.Reason) {
      if issues.count < 12 { issues.append(.init(path: url.path, reason: reason)) }
      else { omittedIssues += 1 }
    }

    mutating func consume(_ url: URL) throws -> Bool {
      try Task.checkCancellation()
      guard !stopped else { return false }
      if remaining <= 0 {
        issue(url, .entryLimit); stopped = true; return false
      }
      if ContinuousClock.now >= deadline {
        issue(url, .timeLimit); stopped = true; return false
      }
      remaining -= 1
      progress.entries += 1
      return true
    }
  }

  private let maximumEntries: Int
  private let maximumDuration: TimeInterval
  private let maximumDepth: Int

  init(maximumEntries: Int = 50_000, maximumDuration: TimeInterval = 8, maximumDepth: Int = 48) {
    self.maximumEntries = maximumEntries
    self.maximumDuration = maximumDuration
    self.maximumDepth = maximumDepth
  }

  func scan(_ root: URL, progress: @escaping @Sendable (DiskUsageProgress) -> Void = { _ in }) async throws -> DiskUsageSnapshot {
    try Task.checkCancellation()
    let root = root.standardizedFileURL
    guard root.isFileURL, root.resolvingSymlinksInPath().path == root.path else { throw DiskUsageError.invalidRoot }
    let descriptor = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else { throw DiskUsageError.unreadable }
    var info = stat()
    guard fstat(descriptor, &info) == 0 else {
      close(descriptor); throw DiskUsageError.unreadable
    }
    var state = State(deadline: .now.advanced(by: .seconds(maximumDuration)), remaining: maximumEntries)
    // walk takes ownership of the descriptor, including cancellation and error paths.
    var node = try walk(root, descriptor: descriptor, info: info, depth: 0, state: &state, progress: progress)
    var current = stat()
    if lstat(root.path, &current) != 0 || !unchanged(info, current) {
      state.issue(root, .changed); node.incomplete = true
    }
    try Task.checkCancellation()
    progress(state.progress)
    return .init(root: node, checkedAt: .now, entries: state.progress.entries,
      skippedSymlinks: state.skippedSymlinks, duplicateFiles: state.duplicateFiles,
      skippedSpecialFiles: state.skippedSpecialFiles, issues: state.issues, omittedIssues: state.omittedIssues)
  }

  private func walk(_ url: URL, descriptor: Int32, info: stat, depth: Int,
                    state: inout State, progress: @Sendable (DiskUsageProgress) -> Void) throws -> DiskUsageNode {
    guard let directory = fdopendir(descriptor) else {
      close(descriptor); state.issue(url, .unreadable)
      return .init(url: url, isDirectory: true, incomplete: true)
    }
    defer { closedir(directory) }
    var node = DiskUsageNode(url: url, isDirectory: true)
    guard try state.consume(url) else { node.incomplete = true; return node }
    guard depth < maximumDepth else {
      state.issue(url, .depthLimit); node.incomplete = true; return node
    }
    while true {
      try Task.checkCancellation()
      errno = 0
      guard let entry = readdir(directory) else {
        if errno != 0 { state.issue(url, .unreadable); node.incomplete = true }
        break
      }
      var value = entry.pointee
      let name = withUnsafePointer(to: &value.d_name) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
      }
      if name == "." || name == ".." { continue }
      let childURL = url.appendingPathComponent(name)
      // Count every discovered entry, including links and failures, against the same budget.
      guard try state.consume(childURL) else { node.incomplete = true; break }
      if state.progress.entries.isMultiple(of: 256) { progress(state.progress) }
      var childInfo = stat()
      guard fstatat(dirfd(directory), name, &childInfo, AT_SYMLINK_NOFOLLOW) == 0 else {
        state.issue(childURL, .unreadable); node.incomplete = true; continue
      }
      let type = childInfo.st_mode & S_IFMT
      if type == S_IFLNK { state.skippedSymlinks += 1; continue }
      guard childInfo.st_dev == info.st_dev else {
        state.issue(childURL, .differentVolume); node.incomplete = true; continue
      }
      var child: DiskUsageNode
      if type == S_IFDIR {
        let childFD = openat(dirfd(directory), name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        var opened = stat()
        guard childFD >= 0 else {
          state.issue(childURL, .unreadable); node.incomplete = true
          node.children.append(.init(url: childURL, isDirectory: true, incomplete: true)); continue
        }
        guard fstat(childFD, &opened) == 0, unchanged(childInfo, opened) else {
          close(childFD); state.issue(childURL, .changed); node.incomplete = true; continue
        }
        // The directory entry was already counted above.
        state.remaining += 1; state.progress.entries -= 1
        child = try walk(childURL, descriptor: childFD, info: opened, depth: depth + 1, state: &state, progress: progress)
        var linked = stat()
        if fstatat(dirfd(directory), name, &linked, AT_SYMLINK_NOFOLLOW) != 0 || !unchanged(opened, linked) {
          state.issue(childURL, .changed); child.incomplete = true
        }
      } else if type == S_IFREG {
        guard state.files.insert(Identity(childInfo)).inserted else { state.duplicateFiles += 1; continue }
        child = .init(url: childURL, isDirectory: false,
          logicalBytes: UInt64(max(0, childInfo.st_size)), allocatedBytes: UInt64(max(0, childInfo.st_blocks)) * 512,
          fileCount: 1)
        state.progress.logicalBytes += child.logicalBytes
      } else { state.skippedSpecialFiles += 1; continue }
      node.children.append(child)
      node.logicalBytes += child.logicalBytes
      node.allocatedBytes += child.allocatedBytes
      node.fileCount += child.fileCount
      node.incomplete = node.incomplete || child.incomplete
      if state.stopped { node.incomplete = true; break }
    }
    var after = stat()
    if fstat(dirfd(directory), &after) != 0 || !unchanged(info, after) {
      state.issue(url, .changed); node.incomplete = true
    }
    return node
  }

  private func unchanged(_ first: stat, _ second: stat) -> Bool {
    Identity(first) == Identity(second) && first.st_mode == second.st_mode
      && first.st_mtimespec.tv_sec == second.st_mtimespec.tv_sec
      && first.st_mtimespec.tv_nsec == second.st_mtimespec.tv_nsec
      && first.st_ctimespec.tv_sec == second.st_ctimespec.tv_sec
      && first.st_ctimespec.tv_nsec == second.st_ctimespec.tv_nsec
  }
}
