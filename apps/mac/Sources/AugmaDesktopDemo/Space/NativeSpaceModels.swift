import Foundation

enum NativeSpaceSceneID: String, CaseIterable, Identifiable, Sendable {
  case garden
  case city
  case workspace
  case projects

  var id: Self { self }
}

/// A virtual landmark, rather than a geographic coordinate or a detected plane.
struct NativeSpaceLandmark: Identifiable, Equatable, Sendable {
  let id: String
  let distance: Int
  let position: SIMD3<Float>

  func title(locale: String) -> String {
    switch id {
    case "terrace": localized(locale, "观景平台", "Lookout Terrace", "展望テラス")
    case "pavilion": localized(locale, "玻璃回廊", "Glass Arcade", "ガラスの回廊")
    case "tree": localized(locale, "中央绿洲", "Central Oasis", "中央のオアシス")
    case "gallery": localized(locale, "光之美术馆", "Gallery of Light", "光の美術館")
    case "station": localized(locale, "空中车站", "Sky Station", "スカイステーション")
    case "square": localized(locale, "街角广场", "Corner Plaza", "街角の広場")
    case "workspace-center": localized(locale, "应用广场", "App Plaza", "アプリ広場")
    case "project-center": localized(locale, "项目区域", "Project Regions", "プロジェクトエリア")
    default: id
    }
  }

  func detail(locale: String) -> String {
    switch id {
    case "terrace": localized(locale, "穿过庭院，在开阔处停留片刻。", "Cross the garden and pause in the open air.", "庭園を抜けて、開けた場所でひと休み。")
    case "pavilion": localized(locale, "连接庭院两侧的透明步行空间。", "A transparent walkway linking both sides of the garden.", "庭園の両側をつなぐ透明な通路。")
    case "tree": localized(locale, "一处可以静下来聆听的绿意。", "A patch of green where you can stop and listen.", "静かに耳を澄ませられる緑の空間。")
    case "gallery": localized(locale, "沿步道前往街角的公共展览空间。", "Follow the walkway to the public gallery on the corner.", "遊歩道を進んだ先にある街角の公共ギャラリー。")
    case "station": localized(locale, "经过连桥，到达城市交通节点。", "Cross the bridge to reach the city transit hub.", "連絡橋を渡って街の交通拠点へ。")
    case "square": localized(locale, "建筑之间的小型开放广场。", "A small open plaza between the buildings.", "建物の間にある小さな広場。")
    case "workspace-center": localized(locale, "把常用应用放进空间。", "Place your apps in space.", "よく使うアプリを空間に配置します。")
    case "project-center": localized(locale, "集中管理项目的工作入口。", "Keep a project's tools together.", "プロジェクトの作業の入口をまとめます。")
    default: ""
    }
  }
}

struct NativeSpaceScene: Identifiable, Equatable, Sendable {
  let id: NativeSpaceSceneID
  let landmarks: [NativeSpaceLandmark]

  static let catalog: [NativeSpaceScene] = [
    NativeSpaceScene(id: .garden, landmarks: [
      NativeSpaceLandmark(id: "terrace", distance: 120, position: [1.1, 0, -0.6]),
      NativeSpaceLandmark(id: "pavilion", distance: 80, position: [-1, 0, -0.2]),
      NativeSpaceLandmark(id: "tree", distance: 45, position: [0, 0, 0.8]),
    ]),
    NativeSpaceScene(id: .city, landmarks: [
      NativeSpaceLandmark(id: "gallery", distance: 240, position: [1.1, 0, -0.6]),
      NativeSpaceLandmark(id: "station", distance: 160, position: [-1, 0, -0.2]),
      NativeSpaceLandmark(id: "square", distance: 60, position: [0, 0, 0.8]),
    ]),
    NativeSpaceScene(id: .workspace, landmarks: [
      NativeSpaceLandmark(id: "workspace-center", distance: 0, position: .zero),
    ]),
    NativeSpaceScene(id: .projects, landmarks: [
      NativeSpaceLandmark(id: "project-center", distance: 0, position: .zero),
    ]),
  ]

  static func scene(for id: NativeSpaceSceneID) -> NativeSpaceScene {
    // The enum and catalog are both closed and always contain a garden scene.
    catalog.first { $0.id == id } ?? catalog[0]
  }

  func title(locale: String) -> String {
    switch id {
    case .garden: localized(locale, "空中庭院", "Sky Garden", "空中庭園")
    case .city: localized(locale, "城市漫游", "City Stroll", "シティウォーク")
    case .workspace: localized(locale, "应用街区", "App District", "アプリ街区")
    case .projects: localized(locale, "项目区域", "Project Regions", "プロジェクトエリア")
    }
  }

  func detail(locale: String) -> String {
    switch id {
    case .garden: localized(locale, "沿着光的方向，重新发现身边的空间。", "Follow the light and rediscover the space around you.", "光の向きに沿って、身近な空間を見つめ直そう。")
    case .city: localized(locale, "让下一段旅程，浮现在眼前。", "Let your next journey appear right before your eyes.", "次の旅を、目の前に浮かび上がらせよう。")
    case .workspace: localized(locale, "点击大楼打开应用，把工作入口留在熟悉的位置。", "Open apps from buildings and keep your tools in familiar places.", "建物からアプリを開き、いつもの場所に作業の入口を配置します。")
    case .projects: localized(locale, "选择区域查看入口，一键打开项目与工作网址。", "Select a region, then open its project and work websites together.", "エリアを選び、プロジェクトと作業用サイトをまとめて開きます。")
    }
  }
}

private func localized(_ locale: String, _ chinese: String, _ english: String, _ japanese: String) -> String {
  if locale.hasPrefix("en") { return english }
  if locale.hasPrefix("ja") { return japanese }
  return chinese
}
