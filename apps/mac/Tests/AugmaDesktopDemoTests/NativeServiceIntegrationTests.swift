import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeServiceIntegrationTests: XCTestCase {
  func testReadOnlySoundCommandsOpenThePanelAcrossThreeLanguages() {
    for phrase in ["打开声音", "查看正在播放", "正在播放", "Show Now Playing", "open sound", "サウンドを開く", "再生中の曲"] {
      XCTAssertEqual(WorkspaceCommand.parse(phrase), .open(.audio), phrase)
    }
    for phrase in ["播放声音", "播放音乐", "Play Sound!", "play audio", "音楽を再生", "暂停声音", "Pause Sound", "サウンドを一時停止", "下一首", "next track", "次の曲", "上一首", "previous song", "前の曲"] {
      XCTAssertNil(WorkspaceCommand.parse(phrase), phrase)
    }
    XCTAssertEqual(WorkspaceCommand.parse("记下：下一首是我喜欢的歌"), .note("下一首是我喜欢的歌"))
    XCTAssertEqual(WorkspaceCommand.parse("note play sound later"), .note("play sound later"))
    XCTAssertEqual(WorkspaceCommand.parse("pause"), .pause)
    XCTAssertNil(WorkspaceCommand.parse("不要播放声音"))
    XCTAssertEqual(WorkspaceAction.all.filter { $0.command == .open(.audio) }.count, 1)
  }

  func testOpeningSoundNeedsNoWritableWorkspaceOrAudioTransport() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-readonly-sound-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "workspace.json")
    let corruptData = Data("unreadable workspace".utf8)
    try corruptData.write(to: fileURL)
    let workspace = WorkspaceStore(url: fileURL, notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    XCTAssertFalse(workspace.writable)
    let commands = WorkspaceCommands(store: workspace)
    var navigations: [DemoModule] = []
    commands.navigate = { navigations.append($0) }
    commands.receiveSpeech(type: "final", text: "查看正在播放")
    XCTAssertEqual(navigations, [.audio])
    XCTAssertFalse(commands.resultIsError)
    XCTAssertEqual(try Data(contentsOf: fileURL), corruptData)
  }
}
