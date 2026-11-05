import AppKit
import Combine
import Foundation
import SwiftUI

struct RGB: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let white = RGB(r: 255, g: 255, b: 255)
    static let warmWhite = RGB(r: 255, g: 204, b: 153)
    static let red = RGB(r: 255, g: 0, b: 0)
    static let green = RGB(r: 0, g: 255, b: 0)
    static let blue = RGB(r: 0, g: 0, b: 255)
    static let off = RGB(r: 0, g: 0, b: 0)

    func scaled(by brightness: Double) -> RGB {
        let t = max(0, min(1, brightness))
        return RGB(
            r: UInt8(Double(r) * t + 0.5),
            g: UInt8(Double(g) * t + 0.5),
            b: UInt8(Double(b) * t + 0.5)
        )
    }

    var color: Color {
        Color(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

enum LEDByteOrder: String {
    case rgb
    case grb
}

enum LEDConfig {
    static let ledCount = 54
    static let leftCount = 14
    static let topCount = 26
    static let rightCount = 14
}

@MainActor
final class LEDEngine: ObservableObject {
    static let ledCount = LEDConfig.ledCount
    static let leftCount = LEDConfig.leftCount
    static let topCount = LEDConfig.topCount
    static let rightCount = LEDConfig.rightCount

    @Published var isOn = true
    @Published var brightness: Double = 0.75
    @Published var color = RGB.warmWhite
    @Published var flowEnabled = false
    @Published var flowSpeed: Double = 3
    @Published var launchAtLogin = false
    @Published var statusText = "未连接"
    @Published var preview: [RGB] = Array(repeating: .warmWhite, count: LEDEngine.ledCount)

    private let serial = SerialPort()
    private var refreshTimer: Timer?
    private var flowPhase = 0.0
    private var byteOrder: LEDByteOrder = .rgb
    private let refreshInterval: TimeInterval = 0.033
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isOn = "sk0124.isOn"
        static let brightness = "sk0124.brightness"
        static let colorR = "sk0124.color.r"
        static let colorG = "sk0124.color.g"
        static let colorB = "sk0124.color.b"
        static let flowEnabled = "sk0124.flowEnabled"
        static let flowSpeed = "sk0124.flowSpeed"
    }

    init() {
        loadSettings()
        launchAtLogin = LaunchAtLogin.isEnabled
        Task { @MainActor in
            self.start()
        }
    }

    func start() {
        reconnect()
        push()
    }

    func reconnect() {
        do {
            try serial.openPreferred()
            statusText = serial.path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "已连接"
            push()
        } catch {
            statusText = error.localizedDescription
        }
    }

    func setPower(_ on: Bool) {
        isOn = on
        saveSettings()
        push()
    }

    func setColor(_ value: RGB) {
        color = value
        saveSettings()
        push()
    }

    func setBrightness(_ value: Double) {
        brightness = max(0.05, min(1, value))
        saveSettings()
        push()
    }

    func setFlow(_ enabled: Bool) {
        flowEnabled = enabled
        saveSettings()
        push()
    }

    func setFlowSpeed(_ value: Double) {
        flowSpeed = max(1, min(10, value))
        saveSettings()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if LaunchAtLogin.setEnabled(enabled) {
            launchAtLogin = LaunchAtLogin.isEnabled
        } else {
            launchAtLogin = LaunchAtLogin.isEnabled
            statusText = enabled ? "开机启动设置失败" : "取消开机启动失败"
        }
    }

    private func loadSettings() {
        if defaults.object(forKey: Keys.isOn) != nil {
            isOn = defaults.bool(forKey: Keys.isOn)
        }
        if defaults.object(forKey: Keys.brightness) != nil {
            brightness = max(0.05, min(1, defaults.double(forKey: Keys.brightness)))
        }
        if defaults.object(forKey: Keys.colorR) != nil {
            color = RGB(
                r: UInt8(clamping: defaults.integer(forKey: Keys.colorR)),
                g: UInt8(clamping: defaults.integer(forKey: Keys.colorG)),
                b: UInt8(clamping: defaults.integer(forKey: Keys.colorB))
            )
        }
        if defaults.object(forKey: Keys.flowEnabled) != nil {
            flowEnabled = defaults.bool(forKey: Keys.flowEnabled)
        }
        if defaults.object(forKey: Keys.flowSpeed) != nil {
            flowSpeed = max(1, min(10, defaults.double(forKey: Keys.flowSpeed)))
        }
        preview = Array(repeating: color.scaled(by: brightness), count: Self.ledCount)
    }

    private func saveSettings() {
        defaults.set(isOn, forKey: Keys.isOn)
        defaults.set(brightness, forKey: Keys.brightness)
        defaults.set(Int(color.r), forKey: Keys.colorR)
        defaults.set(Int(color.g), forKey: Keys.colorG)
        defaults.set(Int(color.b), forKey: Keys.colorB)
        defaults.set(flowEnabled, forKey: Keys.flowEnabled)
        defaults.set(flowSpeed, forKey: Keys.flowSpeed)
    }

    /// Sends solid red for byte-order verification. Returns current order.
    @discardableResult
    func sendProbeRed() -> LEDByteOrder {
        let pixels = Array(repeating: RGB.red, count: Self.ledCount)
        preview = pixels
        send(pixels: pixels, applyBrightness: false)
        return byteOrder
    }

    func setByteOrder(_ order: LEDByteOrder) {
        byteOrder = order
        push()
    }

    func quit() {
        stopRefresh()
        isOn = false
        send(pixels: Array(repeating: .off, count: Self.ledCount), applyBrightness: false)
        serial.close()
        NSApp.terminate(nil)
    }

    private func push() {
        if isOn {
            startRefresh()
        } else {
            stopRefresh()
        }
        tick(advanceFlow: false)
    }

    private func tick(advanceFlow: Bool) {
        let pixels: [RGB]
        if !isOn {
            pixels = Array(repeating: .off, count: Self.ledCount)
        } else if flowEnabled {
            if advanceFlow {
                flowPhase += flowSpeed * 0.35
                let span = Double(Self.ledCount)
                flowPhase = flowPhase.truncatingRemainder(dividingBy: span)
                if flowPhase < 0 { flowPhase += span }
            }
            pixels = flowFrame(phase: flowPhase)
        } else {
            pixels = Array(repeating: color.scaled(by: brightness), count: Self.ledCount)
        }
        preview = pixels
        send(pixels: pixels, applyBrightness: false)
    }

    private func flowFrame(phase: Double) -> [RGB] {
        (0..<Self.ledCount).map { index in
            var hue = (Double(index) + phase) / Double(Self.ledCount)
            hue = hue.truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            let ns = NSColor(hue: hue, saturation: 0.9, brightness: 1, alpha: 1)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ns.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            return RGB(r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
                .scaled(by: brightness)
        }
    }

    private func startRefresh() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn else { return }
                self.tick(advanceFlow: self.flowEnabled)
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func send(pixels: [RGB], applyBrightness: Bool) {
        if !serial.isOpen {
            reconnect()
        }
        guard serial.isOpen else { return }

        var frame = Data(capacity: 6 + pixels.count * 3)
        let count = UInt16(pixels.count)
        frame.append(contentsOf: [0x41, 0x64, 0x61, 0x00, UInt8(count >> 8), UInt8(count & 0xFF)])

        for pixel in pixels {
            let p = applyBrightness ? pixel.scaled(by: brightness) : pixel
            switch byteOrder {
            case .rgb:
                frame.append(contentsOf: [p.r, p.g, p.b])
            case .grb:
                frame.append(contentsOf: [p.g, p.r, p.b])
            }
        }

        do {
            try serial.write(frame)
        } catch {
            statusText = error.localizedDescription
            serial.close()
        }
    }
}
