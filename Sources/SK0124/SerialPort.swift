import Darwin
import Foundation

enum SerialError: LocalizedError {
    case openFailed(String)
    case configureFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .openFailed(let path):
            return "无法打开串口 \(path)"
        case .configureFailed:
            return "串口配置失败"
        case .writeFailed:
            return "串口写入失败"
        }
    }
}

final class SerialPort {
    private var fd: Int32 = -1
    private(set) var path: String?

    var isOpen: Bool { fd >= 0 }

    static func preferredPorts() -> [String] {
        let dir = "/dev"
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        let matched = names.filter { name in
            name.hasPrefix("cu.wchusbserial") || name.hasPrefix("cu.usbserial")
        }
        .sorted()
        return matched.map { "\(dir)/\($0)" }
    }

    func open(path: String, baud: speed_t = 115_200) throws {
        close()
        let handle = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard handle >= 0 else { throw SerialError.openFailed(path) }

        var tty = termios()
        guard tcgetattr(handle, &tty) == 0 else {
            Darwin.close(handle)
            throw SerialError.configureFailed
        }

        cfmakeraw(&tty)
        cfsetispeed(&tty, baud)
        cfsetospeed(&tty, baud)
        tty.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tty.c_cflag &= ~tcflag_t(PARENB)
        tty.c_cflag &= ~tcflag_t(CSTOPB)
        tty.c_cflag &= ~tcflag_t(CSIZE)
        tty.c_cflag |= tcflag_t(CS8)
        withUnsafeMutableBytes(of: &tty.c_cc) { buf in
            buf[Int(VMIN)] = 0
            buf[Int(VTIME)] = 0
        }

        guard tcsetattr(handle, TCSANOW, &tty) == 0 else {
            Darwin.close(handle)
            throw SerialError.configureFailed
        }

        tcflush(handle, TCIOFLUSH)

        let flags = fcntl(handle, F_GETFL)
        if flags >= 0 {
            _ = fcntl(handle, F_SETFL, flags & ~O_NONBLOCK)
        }

        fd = handle
        self.path = path
    }

    func openPreferred() throws {
        let ports = Self.preferredPorts()
        guard let first = ports.first else {
            throw SerialError.openFailed("/dev/cu.usbserial*")
        }
        var lastError: Error = SerialError.openFailed(first)
        for path in ports {
            do {
                try open(path: path)
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func write(_ data: Data) throws {
        guard fd >= 0 else { throw SerialError.writeFailed }
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { throw SerialError.writeFailed }
            var written = 0
            let total = raw.count
            while written < total {
                let n = Darwin.write(fd, base.advanced(by: written), total - written)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw SerialError.writeFailed
                }
                if n == 0 { throw SerialError.writeFailed }
                written += n
            }
        }
    }

    func close() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        path = nil
    }

    deinit { close() }
}
