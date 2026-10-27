import SwiftUI

/// A glanceable reading, followed by three equally weighted supporting measurements.
struct WeatherCurrentReadings: View {
  let snapshot: WeatherSnapshot

  var body: some View {
    VStack(spacing: 16) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(snapshot.temperature.formatted(.number.precision(.fractionLength(0))) + "°")
              .font(.system(size: 64, weight: .light, design: .rounded))
              .tracking(-3)
            Text("C").font(.title3).foregroundStyle(.secondary)
          }
          .monospacedDigit()
          .accessibilityElement(children: .combine)
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { conditions }.fixedSize()
            VStack(alignment: .leading, spacing: 6) { conditions }
          }
          .font(.callout)
        }
        Spacer(minLength: 20)
        WeatherSymbol(snapshot: snapshot, size: 76)
          .frame(width: 112, height: 96)
          .background {
            Circle().fill(WeatherPalette.accent(for: snapshot).opacity(0.12)).blur(radius: 18)
          }
          .accessibilityHidden(true)
      }
      Divider().overlay(Color.primary.opacity(0.02))
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) { metrics }.frame(minWidth: 420)
        VStack(alignment: .leading, spacing: 16) { metrics }
      }
    }
  }

  @ViewBuilder private var conditions: some View {
    Text(snapshot.condition.description).fontWeight(.medium)
    temperatureRange
  }

  @ViewBuilder private var metrics: some View {
    metric("体感温度", symbol: "thermometer.medium", value: snapshot.apparentTemperature, unit: "°C")
    metric("相对湿度", symbol: "humidity", value: snapshot.relativeHumidity, unit: "%")
    metric("风速", symbol: "wind", value: snapshot.windSpeed, unit: "km/h", fractionLength: 1)
  }

  private var temperatureRange: some View {
    HStack(spacing: 9) {
      if let high = snapshot.highTemperature {
        Label(high.formatted(.number.precision(.fractionLength(0))) + "°", systemImage: "arrow.up")
          .accessibilityLabel(Text("今日最高") + Text(" \(high.formatted(.number.precision(.fractionLength(0)))) °C"))
      }
      if let low = snapshot.lowTemperature {
        Label(low.formatted(.number.precision(.fractionLength(0))) + "°", systemImage: "arrow.down")
          .accessibilityLabel(Text("今日最低") + Text(" \(low.formatted(.number.precision(.fractionLength(0)))) °C"))
      }
    }
    .foregroundStyle(.secondary)
    .labelStyle(.titleAndIcon)
    .monospacedDigit()
  }

  private func metric(_ title: LocalizedStringKey, symbol: String, value: Double, unit: String, fractionLength: Int = 0) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value.formatted(.number.precision(.fractionLength(fractionLength))))
          .font(.system(.title3, design: .rounded).weight(.medium))
        Text(unit).font(.caption).foregroundStyle(.secondary)
      }
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Palette rendering keeps clouds and nighttime symbols visible in either appearance.
struct WeatherSymbol: View {
  let snapshot: WeatherSnapshot
  let size: CGFloat

  var body: some View {
    let accent = WeatherPalette.accent(for: snapshot)
    Image(systemName: snapshot.condition.symbol)
      .symbolRenderingMode(.palette)
      .foregroundStyle(accent, accent.opacity(0.6), accent.opacity(0.4))
      .font(.system(size: size, weight: .light))
      .accessibilityHidden(true)
  }
}

private enum WeatherPalette {
  static func accent(for snapshot: WeatherSnapshot) -> Color {
    switch snapshot.weatherCode {
    case 0...2: snapshot.isDay ? .orange : .indigo
    case 95...99: .indigo
    default: .augmaCyan
    }
  }
}
