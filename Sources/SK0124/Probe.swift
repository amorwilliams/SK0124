import Foundation

enum Probe {
    static func sendSolidRed() throws {
        let port = SerialPort()
        try port.openPreferred()
        let count = UInt16(LEDConfig.ledCount)
        var frame = Data([0x41, 0x64, 0x61, 0x00, UInt8(count >> 8), UInt8(count & 0xFF)])
        for _ in 0..<LEDConfig.ledCount {
            frame.append(contentsOf: [0xFF, 0x00, 0x00])
        }
        try port.write(frame)
        print("sent RGB red \(frame.count) bytes via \(port.path ?? "?")")
        print(frame.prefix(12).map { String(format: "%02x", $0) }.joined(separator: " "))
    }
}
