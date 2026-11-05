# AGENTS

给在本仓库工作的 AI Agent 用。人类说明见 [README.md](README.md)、协议见 [PROTOCOL.md](PROTOCOL.md)。

## 项目是什么

- 自用 macOS 菜单栏 App，控制 Skydimo **SK0124** LED
- SwiftUI `MenuBarExtra` + Darwin `termios`，无第三方依赖
- 不复刻 Skydimo UI / 屏幕同步 / 激活；不整包反编译交付源码

## 硬约束

- 只改明确要求的范围；不擅自加功能、不写无关文档/测试/示例
- 回复用简体中文，少废话
- 未要求时不 `git commit` / 不 `git push`
- 不要改 git config；不要 force push main
- `.build/`、`SK0124.app` 已 gitignore，不要提交构建产物
- 本机自用：`codesign -s -`，不开付费开发者账号、不开 App Sandbox

## 协议（改串口代码前必读）

- 115200 8N1，节点用 `cu.` 不是 `tty.`
- 帧：`Ada` + `0x00` + big-endian **灯数 N** + RGB×N（不是 N-1，无 Adalight checksum）
- SK0124：N=54，头 `41 64 61 00 00 36`
- 亮灯时约 **33ms** 重发，否则会超时熄灭
- 字节序 RGB；探测：`--probe-red`
- 原软件认设备靠写 `Moni-A`、读响应前缀 `SK`；本项目目前按端口名过滤

## 状态栏关键点

- `Resources/Info.plist`：`LSUIElement = true`
- `Sources/SK0124/App.swift`：`MenuBarExtra` + `.menuBarExtraStyle(.window)`
- 串口/Timer 在引擎启动时做，不要只挂面板 `onAppear`
- Timer 加到 `RunLoop.main` 的 `.common`
- 开机启动：只写 LaunchAgent plist，**不要** `launchctl load`（会多开实例）；已有单实例退出逻辑

## 常用命令

```bash
./build.sh
open ./SK0124.app
pkill -f 'SK0124.app/Contents/MacOS/SK0124'
```

改完 Swift 后重建并重启 App 再验证。

## 布局常量

- 54 灯：左 14、上 26、右 14（无底边）
- 默认亮度 0.75；设置键前缀 `sk0124.`
