import AppKit
import SwiftUI

@main
struct SK0124App: App {
    @StateObject private var engine = LEDEngine()

    init() {
        if Self.anotherInstanceRunning() {
            Darwin.exit(0)
        }

        if CommandLine.arguments.contains("--probe-red") {
            do {
                try Probe.sendSolidRed()
                Darwin.exit(0)
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                Darwin.exit(1)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(engine)
                .onAppear { engine.start() }
        } label: {
            MenuBarLabel(isOn: engine.isOn)
        }
        .menuBarExtraStyle(.window)
    }

    private static func anotherInstanceRunning() -> Bool {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let bundlePath = Bundle.main.bundleURL.path
        return NSWorkspace.shared.runningApplications.contains { app in
            guard app.processIdentifier != selfPID else { return false }
            guard let url = app.bundleURL else { return false }
            return url.path == bundlePath
        }
    }
}

private struct MenuBarLabel: View {
    let isOn: Bool

    var body: some View {
        if let image = Self.templateIcon() {
            Image(nsImage: image)
                .opacity(isOn ? 1 : 0.45)
        } else {
            Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
        }
    }

    private static func templateIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
