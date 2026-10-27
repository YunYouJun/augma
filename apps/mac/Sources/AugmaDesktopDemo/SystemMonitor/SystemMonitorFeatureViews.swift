import SwiftUI

struct SystemMonitorFeatureControls: View {
  @ObservedObject var store: SystemMonitorStore

  var body: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      VStack(alignment: .leading, spacing: 8) {
        Text("刷新间隔").font(.callout.weight(.medium))
        Picker("刷新间隔", selection: $store.sampleInterval) {
          Text("仅手动刷新").tag(0.0)
          Text("1 秒").tag(1.0)
          Text("2 秒").tag(2.0)
          Text("5 秒").tag(5.0)
          Text("10 秒").tag(10.0)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .accessibilityLabel("刷新间隔")
      }
      Toggle("应用内存排行", isOn: $store.applicationMemoryEnabled)
      Toggle("温度与风扇", isOn: $store.sensorsEnabled)
      Toggle("网速历史曲线", isOn: $store.networkHistoryEnabled)
      Text("温度、风扇与曲线默认关闭。仅打开监控面板或菜单栏摘要时采集这些可选数据；只有 HUD 可见时不扫描应用进程。全部监控界面关闭后停止采样并释放数据。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .toggleStyle(.switch)
    .controlSize(.regular)
  }
}

struct HardwareSensorMetrics: View {
  let snapshot: HardwareSensorSnapshot?
  var compact = false

  var body: some View {
    if let snapshot {
      LabeledContent("CPU 温度", value: snapshot.cpuTemperature.map {
        $0.formatted(.number.precision(.fractionLength(0))) + " °C"
      } ?? String(localized: "暂不可用"))
      if let fans = snapshot.fans {
        if fans.isEmpty { Label("无风扇", systemImage: "fan.slash").foregroundStyle(.secondary) }
        ForEach(fans) { fan in
          LabeledContent(String(format: String(localized: "风扇 %lld"), fan.id + 1), value: fan.rpm.map {
            $0.formatted(.number.precision(.fractionLength(0))) + " RPM"
          } ?? String(localized: "暂不可用"))
        }
      } else {
        LabeledContent("风扇转速", value: String(localized: "暂不可用"))
      }
      if !compact {
        if snapshot.cpuSensorCount > 1 {
          Text(String(format: String(localized: "来自 %lld 个有效 CPU 测点的平均值"), snapshot.cpuSensorCount))
            .font(.caption).foregroundStyle(.secondary)
        }
        LabeledContent("传感器更新") {
          Text(snapshot.sampledAt, format: .dateTime.hour().minute().second()).foregroundStyle(.secondary)
        }
      }
    } else {
      Text("当前机型暂无法读取传感器").foregroundStyle(.secondary)
    }
  }
}

struct NetworkHistoryView: View {
  let history: NetworkHistory
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if history.points.count < 2 {
        Text("等待更多网速采样…").font(.caption).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: compact ? 40 : 100)
      } else {
        Canvas { context, size in
          let ceiling = max(1, history.points.reduce(0) { max($0, $1.received, $1.sent) })
          let latest = history.points.last!.date
          for download in [true, false] {
            var path = Path()
            for (index, point) in history.points.enumerated() {
              let x = max(0, min(1, 1 + point.date.timeIntervalSince(latest) / NetworkHistory.duration)) * size.width
              let rate = download ? point.received : point.sent
              let position = CGPoint(x: x, y: 2 + (1 - min(1, rate / ceiling)) * max(0, size.height - 4))
              if index == 0 { path.move(to: position) }
              else { path.addLine(to: position) }
            }
            context.stroke(path, with: .color(download ? .augmaCyan : .augmaUpload),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
          }
        }
        .frame(height: compact ? 44 : 110)
        .accessibilityLabel("最近两分钟网速曲线")
      }
      HStack {
        Label("下载", systemImage: "arrow.down").foregroundStyle(Color.augmaCyan)
        Label("上传", systemImage: "arrow.up").foregroundStyle(Color.augmaUpload)
        Spacer()
        Text("最近两分钟").foregroundStyle(.secondary)
      }
      .font(.caption)
    }
  }
}
