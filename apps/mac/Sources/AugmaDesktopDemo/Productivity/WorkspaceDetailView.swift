import SwiftUI

struct WorkspaceDetailView: View {
  @ObservedObject var model: NativeDemoModel
  let store: WorkspaceStore
  let commands: WorkspaceCommands
  let monitor: SystemMonitorStore
  let weather: WeatherStore
  let preferences: NativePreferencesStore
  let audio: NativeAudioStore
  let maps: NativeMapStore
  let camera: NativeCameraStore

  var body: some View {
    ZStack {
      if !model.isImmersive {
        switch model.selection {
        case .notes: QuickNotesView(store: store, commands: commands)
        case .focus: FocusTimerView(store: store, commands: commands)
        case .actions: WorkspaceCommandView(commands: commands, store: store)
        case .monitor: SystemMonitorView(store: monitor)
        case .market: ApplicationMarketView(store: model.market)
        case .weather: NativeLiveWeatherView(store: weather)
        case .audio: NativeAudioView(store: audio)
        case .navigation: NativeMapView(store: maps)
        case .camera: NativeCameraView(store: camera)
        case .space: NativeSpaceView(store: model.space, preferences: preferences)
        case .settings: NativeScenePreferencesView(store: preferences)
        case .notifications: NativeNotificationsView(store: model.notifications)
        case .commands: NativeCommandView(store: model.assistant, commands: commands)
        case .device: NativeDeviceView(store: model.device, space: model.space, camera: camera, preferences: preferences)
        case .browser: NativeBrowserView(store: model.browser)
        case nil: ContentUnavailableView("选择应用", systemImage: "square.grid.2x2")
        }
      }
    }
  }
}
