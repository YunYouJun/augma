import SwiftUI

struct ApplicationLibraryPage: View {
  @ObservedObject var store: ApplicationLibraryStore
  @ObservedObject var dock: NativeDockStore
  @State private var section: ApplicationLibrarySection = .installed

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Label("应用列表", systemImage: "square.grid.2x2").font(.title2.bold())
        Picker("应用来源", selection: $section) {
          ForEach(ApplicationLibrarySection.allCases) { section in Text(section.title).tag(section) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("application-library-section")
      }
      .padding()
      Divider()
      ApplicationLibraryView(store: store, dock: dock, section: section)
    }
  }
}
