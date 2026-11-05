import Foundation

enum LaunchAtLogin {
    static let label = "local.sk0124.menubar"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return install()
        }
        return uninstall()
    }

    private static func executablePath() -> String {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/SK0124")
            .path
    }

    private static func install() -> Bool {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath()],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            // 只登记，不 load/bootstrap，否则当前会话会再起一个实例
            return true
        } catch {
            return false
        }
    }

    private static func uninstall() -> Bool {
        let uid = getuid()
        _ = runLaunchctl(["bootout", "gui/\(uid)/\(label)"])
        _ = runLaunchctl(["unload", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
        return !isEnabled
    }

    @discardableResult
    private static func runLaunchctl(_ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
}
