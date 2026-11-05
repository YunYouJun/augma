import Foundation

struct DiskUsageAdvice: Identifiable {
  enum Kind: Equatable { case project, build, installer, review }
  let node: DiskUsageNode
  let kind: Kind
  var id: String { node.id }

  var message: String {
    switch kind {
    case .project: String(localized: "此目录属于已共享项目。到 Craft Hub 审阅项目维护命令。")
    case .build: String(localized: "目录名称提示可能包含依赖或构建产物。先核对用途与重建方式，再决定如何维护。")
    case .installer: String(localized: "安装包或压缩文件值得检查。确认是否需要保留原件与离线副本。")
    case .review: String(localized: "优先检查内容与用途；占用大小和文件年龄不能证明可以删除。")
    }
  }

  static func suggestions(for node: DiskUsageNode, metric: DiskUsageMetric, projects: [CraftHubProject] = []) -> [Self] {
    node.children.filter { $0.bytes(metric) > 0 }.sorted { $0.bytes(metric) > $1.bytes(metric) }.prefix(5).map { child in
      let kind: Kind
      if matchingProject(child.url, projects: projects) != nil { kind = .project }
      else if child.isDirectory && ["node_modules", ".build", "build", "dist", ".next", ".nuxt", "DerivedData"].contains(child.url.lastPathComponent) { kind = .build }
      else if !child.isDirectory && ["dmg", "pkg", "xip", "zip", "tar", "gz"].contains(child.url.pathExtension.lowercased()) { kind = .installer }
      else { kind = .review }
      return .init(node: child, kind: kind)
    }
  }

  /// Match only shared roots, with a path-component boundary and the most specific project first.
  static func matchingProject(_ url: URL, projects: [CraftHubProject]) -> CraftHubProject? {
    let path = url.standardizedFileURL.path
    return projects.filter {
      let root = URL(filePath: $0.path).standardizedFileURL.path
      return root != "/" && (path == root || path.hasPrefix(root + "/"))
    }.max { $0.path.count < $1.path.count }
  }
}
