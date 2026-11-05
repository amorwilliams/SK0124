# SK0124

macOS 菜单栏控灯工具，替代 Skydimo 驱动 **SK0124**（54 灯，CH340 串口）。约 30MB 内存，无屏幕同步。

## 要求

- macOS 13+
- Xcode Command Line Tools / Swift 5.9+
- 设备占用 `/dev/cu.usbserial*` 或 `/dev/cu.wchusbserial*`（勿同时开 Skydimo）

## 构建运行

```bash
./build.sh
open ./SK0124.app
```

探测纯红帧（确认 RGB 字节序）：

```bash
./SK0124.app/Contents/MacOS/SK0124 --probe-red
```

## 功能

- 开关、白/暖白/红/绿/蓝、亮度、流水与速度
- 约 33ms 持续刷帧（设备超时否则会灭）
- 记住上次设置（`UserDefaults`）
- 开机启动（`~/Library/LaunchAgents/local.sk0124.menubar.plist`，下次登录生效）
- 单实例；`LSUIElement` 无 Dock 图标

## 协议摘要

```text
Ada | 0x00 | count_hi | count_lo | R G B × N
```

SK0124：`41 64 61 00 00 36` + 162 字节像素，115200 8N1。完整说明见 [PROTOCOL.md](PROTOCOL.md)。

## 结构

| 路径 | 说明 |
|---|---|
| `Sources/SK0124/` | SwiftUI 菜单栏应用 |
| `Resources/` | Info.plist、图标 |
| `Scripts/make_icon.swift` | 生成 icns / 菜单栏模板图 |
| `build.sh` | 打 `.app` 并 ad-hoc 签名 |
| `PROTOCOL.md` | 串口协议与实现笔记 |
| `AGENTS.md` | 给 AI Agent 的仓库约定 |
