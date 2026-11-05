import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: LEDEngine

    private let presets: [(String, RGB)] = [
        ("白色", .white),
        ("暖白", .warmWhite),
        ("红色", .red),
        ("绿色", .green),
        ("蓝色", .blue),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SK0124")
                    .font(.headline)
                Spacer()
                Button(engine.isOn ? "关灯" : "开灯") {
                    engine.setPower(!engine.isOn)
                }
            }

            LEDPreview(pixels: engine.preview)
                .frame(height: 120)

            HStack(spacing: 0) {
                ForEach(Array(presets.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Spacer(minLength: 0) }
                    Button {
                        engine.setColor(item.1)
                        if !engine.isOn { engine.setPower(true) }
                    } label: {
                        Circle()
                            .fill(item.1.color)
                            .overlay(
                                Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: engine.color == item.1 ? 2 : 0)
                                    .padding(-3)
                            )
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help(item.0)
                }
            }

            HStack {
                Text("亮度")
                Slider(
                    value: Binding(
                        get: { engine.brightness },
                        set: { engine.setBrightness($0) }
                    ),
                    in: 0.05...1
                )
                Text("\(Int(engine.brightness * 100))%")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }

            Toggle("流水", isOn: Binding(
                get: { engine.flowEnabled },
                set: { engine.setFlow($0) }
            ))

            Toggle("开机启动", isOn: Binding(
                get: { engine.launchAtLogin },
                set: { engine.setLaunchAtLogin($0) }
            ))

            HStack {
                Text("速度")
                Slider(
                    value: Binding(
                        get: { engine.flowSpeed },
                        set: { engine.setFlowSpeed($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .disabled(!engine.flowEnabled)
                Text("\(Int(engine.flowSpeed))")
                    .monospacedDigit()
                    .frame(width: 24, alignment: .trailing)
                    .foregroundStyle(engine.flowEnabled ? .primary : .secondary)
            }

            HStack {
                Text(engine.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("重连") { engine.reconnect() }
                    .font(.caption)
                Button("退出") { engine.quit() }
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 248)
    }
}

struct LEDPreview: View {
    let pixels: [RGB]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.35))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black)
                    .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))

                ForEach(0..<LEDEngine.ledCount, id: \.self) { index in
                    let point = Self.position(index: index, width: w, height: h)
                    Circle()
                        .fill(pixels[index].color)
                        .frame(width: 6, height: 6)
                        .position(point)
                }
            }
        }
    }

    private static func position(index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let left = LEDEngine.leftCount
        let top = LEDEngine.topCount
        let right = LEDEngine.rightCount
        if index < left {
            let t = CGFloat(index) / CGFloat(max(left - 1, 1))
            return CGPoint(x: width * 0.07, y: height * (0.86 - t * 0.74))
        }
        if index < left + top {
            let i = index - left
            let t = CGFloat(i) / CGFloat(max(top - 1, 1))
            return CGPoint(x: width * (0.12 + t * 0.74), y: height * 0.06)
        }
        let i = index - left - top
        let t = CGFloat(i) / CGFloat(max(right - 1, 1))
        return CGPoint(x: width * 0.91, y: height * (0.12 + t * 0.74))
    }
}
