import SwiftUI

struct WeatherCityCard: View {
  let city: WeatherCity
  let snapshot: WeatherSnapshot?
  let isSelected: Bool
  let select: () -> Void
  let remove: () -> Void
  @State private var isHovered = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Button(action: select) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 5) {
            Text(city.name).fontWeight(.semibold).lineLimit(1)
            if city.isCurrentLocation {
              Image(systemName: "location.fill").font(.caption2).foregroundStyle(.secondary)
                .accessibilityLabel("当前位置")
            }
            if isSelected {
              Image(systemName: "checkmark").font(.caption2).foregroundStyle(Color.augmaCyan)
                .accessibilityLabel("当前城市")
            }
            Spacer(minLength: 0)
          }
          .padding(.trailing, 16)
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let snapshot {
              HStack(spacing: 5) {
                WeatherSymbol(snapshot: snapshot, size: 13)
                Text(snapshot.condition.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
              }
              Spacer(minLength: 0)
              Text(snapshot.temperature.formatted(.number.precision(.fractionLength(0))) + "°")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .monospacedDigit()
            } else {
              Text("查看天气").font(.caption).foregroundStyle(.secondary)
              Spacer(minLength: 0)
              Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: NativePageLayout.cornerRadius))
        .overlay {
          RoundedRectangle(cornerRadius: NativePageLayout.cornerRadius)
            .strokeBorder(isSelected ? Color.augmaCyan.opacity(0.6) : Color.primary.opacity(0.07), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: NativePageLayout.cornerRadius))
      }
      .buttonStyle(.plain)
      .onHover { isHovered = $0 }
      .accessibilityValue(isSelected ? String(localized: "当前城市") : "")
      .help(city.regionDescription)
      .accessibilityHint(city.regionDescription)
      .contextMenu { Button("删除城市", systemImage: "trash", role: .destructive, action: remove) }

      Menu {
        Button("删除城市", systemImage: "trash", role: .destructive, action: remove)
      } label: {
        Image(systemName: "ellipsis").font(.caption).foregroundStyle(.secondary)
          .frame(width: 18, height: 18)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .padding(10)
      .accessibilityLabel(Text("管理城市：\(city.name)"))
    }
  }

  private var fill: Color {
    if isSelected { return .augmaCyan.opacity(0.07) }
    return .primary.opacity(isHovered ? 0.045 : 0.02)
  }
}
