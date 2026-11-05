# SK0124 协议与 Swift 状态栏实现笔记

设备：Skydimo **SK0124**（54 灯，左 14 / 上 26 / 右 14）  
串口芯片：CH340  
来源：反汇编 `Skydimo` 中 `SKSerialPort` / `SKController` / `SKControllerEnumerator`，对照本仓库实现。

---

## 1. 物理层

| 项 | 值 |
|---|---|
| 设备节点 | `/dev/cu.usbserial*` 或 `/dev/cu.wchusbserial*`（用 `cu.`，不要用 `tty.`） |
| USB | CH340（原软件 `scanCH340Devices`） |
| 波特率 | **115200**（`0x1C200`） |
| 数据位 | 8 |
| 校验 | 无 |
| 停止位 | 1 |
| 流控 | 无（`CLOCAL \| CREAD`） |
| 打开后 | `tcflush(TCIOFLUSH)` 清缓冲 |

同一时间只能有一个进程占串口。Skydimo 开着时本程序连不上。

macOS 上用 Darwin `termios` 即可，不必引第三方串口库。打开时先 `O_NONBLOCK`，配好再清掉非阻塞，避免 `open` 卡住。

---

## 2. 帧格式（Adalight 变体）

原软件 `SKController::onLayoutChanged` 组头，`SKController::write` 追加 RGB 后写出。

### 2.1 结构

```text
偏移  长度  含义
0     3     魔数 ASCII "Ada" = 41 64 61
3     1     固定 0x00
4     2     灯数 big-endian uint16（就是 count，不是 count-1）
6     3*N   像素：每灯 3 字节，顺序 R, G, B
```

校验：原软件检查「头里字节 4、5 不能同时为 0」，否则打日志 `Invalid header, Abort write.` 并丢弃。没有经典 Adalight 的 `hi ^ lo ^ 0x55` 校验字节。

### 2.2 SK0124 示例

54 灯 = `0x0036`：

```text
41 64 61 00 00 36 | RR GG BB × 54
```

整帧长度：`6 + 54 × 3 = 168` 字节。

纯红探测帧（确认字节序）：

```text
41 64 61 00 00 36 ff 00 00 ff 00 00 ...（共 54 组 ff 00 00）
```

`AbsRGBController::testLeds` 里对「红通道」写的是 `FF 00 00`，主机侧 `SD_RGB` 即 **RGB**，不是 GRB。

### 2.3 亮度

协议里**没有**独立亮度命令。亮度 = 发送前把每个通道乘以系数（本项目默认 0.75）。关灯 = 发全 0。

### 2.4 刷新周期（重要）

原软件 `global.json`：

```json
"devUpdateInterval": 33
```

即约 **30 FPS** 持续写帧。控制器有超时：只发一次静态色，过一会儿会熄灭。  
本项目在亮灯时用 `Timer` 每 **33ms** 重发当前画面（流水则顺带推进相位）。

### 2.5 灯序与布局

配置：`nbLeds = 54`，`lines = [14, 26, 14]`。

像素数组下标按控制器灯珠物理接线顺序，不是屏幕坐标顺序。预览里按：

1. 左侧自下而上 14  
2. 顶边自左向右 26  
3. 右侧自上而下 14  

底边无灯。

---

## 3. 和经典 Adalight 的差别

| | 经典 Adalight | Skydimo / SK0124 |
|---|---|---|
| 头 | `Ada` + hi + lo + checksum | `Ada` + `0x00` + hi + lo |
| hi/lo | 通常是 `(N-1)` | 直接是 `N` |
| checksum | `hi ^ lo ^ 0x55` | 无 |

不要按网上通用 Adalight 示例照抄，会亮不起来或闪一下灭。

---

## 4. 命令行探测

先退出 Skydimo，再：

```bash
./SK0124.app/Contents/MacOS/SK0124 --probe-red
```

成功时打印类似：

```text
sent RGB red 168 bytes via /dev/cu.usbserial-XXXX
41 64 61 00 00 36 ff 00 00 ff 00 00
```

灯应显示红色。若偏绿，再考虑改成 GRB（当前硬件与原软件一致为 RGB）。

---

## 5. Swift 状态栏（MenuBarExtra）技巧

最低系统：**macOS 13+**（`MenuBarExtra`）。本项目用 SwiftUI + SPM 编可执行文件，再打成 `.app`。

### 5.1 无 Dock 图标

`Info.plist`：

```xml
<key>LSUIElement</key>
<true/>
```

否则菜单栏工具还会在 Dock 占一个图标。

### 5.2 面板样式

```swift
MenuBarExtra { ... } label: { ... }
    .menuBarExtraStyle(.window)
```

- `.menu`：系统菜单，控件少  
- `.window`：可放 `Slider` / 预览 / `Toggle`，适合本项目

### 5.3 状态栏图标用模板图

菜单栏要跟系统深浅色自适应：黑白 + alpha，并设：

```swift
image.isTemplate = true
image.size = NSSize(width: 18, height: 18)
```

资源放 `Contents/Resources/MenuBarIcon.png`（及 `@2x`）。用 `Bundle.main.url(forResource:withExtension:)` 读，**不要**指望 SPM 可执行文件自己带 Asset Catalog，除非你声明了 `resources`。

`NSBitmapImageRep(contentsOf:)` 在新 SDK 上可能不可用，优先 `NSImage(contentsOf:)`。

### 5.4 生命周期坑

`MenuBarExtra` 内容视图的 `onAppear` **往往要等用户点开面板才触发**。  
串口打开、定时刷新应在引擎 `init` / App 启动时就做，不能只挂在面板 `onAppear`。

本项目：`LEDEngine.init` → `Task { start() }`，保证一点图标灯已经在刷。

### 5.5 Timer 与菜单栏 RunLoop

```swift
Timer.scheduledTimer(...)
RunLoop.main.add(timer, forMode: .common)
```

只加到 `.default` 时，用户拖菜单/滚动时可能停刷，灯会闪或灭。用 `.common` 覆盖 tracking 模式。

### 5.6 状态共享

```swift
@StateObject private var engine = LEDEngine()
// 面板里
.environmentObject(engine)
```

`label` 和面板要读同一份状态（例如开/关改图标透明度），必须共用一个 `ObservableObject`。

### 5.7 本机签名，不要沙盒

```bash
codesign -s - --force --deep SK0124.app
```

串口设备访问：本机自用 **不要** 开 App Sandbox。付费开发者账号不是必需的。

`LSMinimumSystemVersion` 与 `platforms: [.macOS(.v13)]` 对齐。

### 5.8 打包方式（本仓库）

SPM 只产出二进制；`build.sh` 负责：

1. `swift build -c release`  
2. 建 `SK0124.app/Contents/{MacOS,Resources}`  
3. 拷贝可执行文件、`Info.plist`、`AppIcon.icns`、菜单栏 PNG  
4. `codesign -s -`

应用图标：`CFBundleIconFile = AppIcon`（对应 `AppIcon.icns`，不要写 `.icns` 后缀）。

### 5.9 设置持久化

`UserDefaults` 存：开关、亮度、RGB、流水开关、速度。  
改设置时立刻 `set`；启动 `init` 里先 `load` 再连串口。  
注意：`bool(forKey:)` 没写过时也是 `false`，要用 `object(forKey:) != nil` 区分「未设置」和「用户关了」。

### 5.10 退出

菜单栏 App 没有标准窗口关闭流。提供「退出」：

1. 停 Timer  
2. 发一帧全黑（可选）  
3. 关串口  
4. `NSApp.terminate(nil)`

---

## 6. 本仓库关键文件

| 路径 | 作用 |
|---|---|
| `Sources/SK0124/SerialPort.swift` | termios 串口 |
| `Sources/SK0124/LEDEngine.swift` | 组帧、33ms 刷新、流水、偏好 |
| `Sources/SK0124/App.swift` | MenuBarExtra 入口 |
| `Sources/SK0124/ContentView.swift` | 面板 UI |
| `Resources/Info.plist` | LSUIElement、图标名 |
| `build.sh` | 打 `.app` 并签名 |
| `Scripts/make_icon.swift` | 生成 icns / 菜单栏模板图 |

编译运行：

```bash
cd /Users/robin/Work/SK0124
./build.sh
open ./SK0124.app
```

---

## 7. 排查清单

1. 灯一会灭 → 是否在持续 33ms 写帧；Timer 是否在 `.common`  
2. 打不开串口 → Skydimo 是否占用；看 `lsof /dev/cu.usbserial*`  
3. 颜色不对 → 用 `--probe-red`；确认 RGB 而非 GRB  
4. 菜单栏没图标 → Resources 是否拷进 `.app`；模板图是否 `isTemplate`  
5. Dock 还有图标 → `LSUIElement` 是否为 `true`，改完需重建 `.app`
