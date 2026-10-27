import SwiftUI

/// Shared sizing and rendering. Official images retain their color, shape and aspect ratio.
/// Callers supply their own accessible label, or hide the view when adjacent text names the item.
struct AppleIconView: View {
  let request: AppleIconRequest
  var size: CGFloat = 28
  var tint: Color = .secondary
  var resolver: AppleIconResolver = .shared

  var body: some View {
    Group {
      switch resolver.resolve(request) {
      case .image(let image):
        Image(nsImage: image).renderingMode(.original).resizable().scaledToFit()
      case .symbol(let name):
        Image(systemName: name).font(.system(size: size * 0.72, weight: .medium))
          .symbolRenderingMode(.hierarchical).foregroundStyle(tint)
      case .platformLabel(let name):
        Text(name).font(.system(size: size * (name.count > 4 ? 0.25 : 0.36), weight: .semibold, design: .rounded))
          .foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
          .padding(3).frame(width: size, height: size)
          .background(.background, in: RoundedRectangle(cornerRadius: size * 0.22))
          .overlay { RoundedRectangle(cornerRadius: size * 0.22).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5) }
      }
    }
    .frame(width: size, height: size)
  }
}
