import SwiftUI

/// Shared rhythm for native content pages; maps, browsers and inspectors retain their own canvas layout.
enum NativePageLayout {
  static let contentWidth: CGFloat = 800
  static let wideContentWidth: CGFloat = 1000
  static let pagePadding: CGFloat = 24
  static let sectionSpacing: CGFloat = 24
  static let cardPadding: CGFloat = 20
  static let itemSpacing: CGFloat = 12
  static let cornerRadius: CGFloat = 16
}

struct NativePage<Content: View>: View {
  var maxWidth: CGFloat = NativePageLayout.contentWidth
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing, content: content)
        .nativePageContent(maxWidth: maxWidth)
    }
    .controlSize(.regular)
  }
}

struct NativePageSection<Content: View>: View {
  private let title: Text
  private let content: Content

  init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
    self.title = Text(title)
    self.content = content()
  }

  init(title: Text, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      title.font(.headline).accessibilityAddTraits(.isHeader)
      VStack(alignment: .leading, spacing: 16) { content }
        .nativeCard()
    }
  }
}

extension View {
  func nativePageContent(maxWidth: CGFloat = NativePageLayout.contentWidth) -> some View {
    frame(maxWidth: maxWidth, alignment: .leading)
      .padding(NativePageLayout.pagePadding)
      .frame(maxWidth: .infinity, alignment: .top)
  }

  func nativeCard() -> some View {
    padding(NativePageLayout.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: NativePageLayout.cornerRadius))
  }
}
