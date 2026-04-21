# GeniusMac

macOS 原生重构版 Genius，使用 Swift + SwiftUI 编写。

## 当前工程入口

推荐直接用 Xcode 工程维护：

- [Genius.xcodeproj](/Users/eugene/Downloads/GeniusMac/SwiftGenius/Genius.xcodeproj)
- `Target`: `GeniusMac`
- `Scheme`: `GeniusMac`

同时保留了 `Swift Package` 入口，方便命令行快速编译：

- [Package.swift](/Users/eugene/Downloads/GeniusMac/SwiftGenius/Package.swift)

## 目录结构

```
SwiftGenius/
├── Genius.xcodeproj/           # 标准 Xcode 工程
├── Package.swift               # SwiftPM 入口（保留）
├── project.yml                 # XcodeGen 配置源
├── GeniusMac/
│   ├── GeniusMacApp.swift      # App 入口
│   ├── Core/                   # 像素监控、按键发送、窗口检测
│   ├── Models/                 # 配置与事件模型
│   ├── Services/               # 配置、权限服务
│   ├── Views/                  # 主窗口与设置窗口
│   ├── Resources/              # Info.plist、entitlements、默认配置
│   └── Assets.xcassets/        # App 图标资源
└── scripts/
    └── build_xcode_app.sh      # 命令行构建 Xcode app
```

## 核心功能

| .NET (Windows) | Swift (macOS) |
|---------------|---------------|
| `GetDC` + `GetPixel` | `CGWindowListCreateImage` |
| `SendMessage WM_KEYDOWN` | `CGEvent.post(tap: .cghidEventTap)` |
| `Process.GetProcesses()` | `NSWorkspace.shared.runningApplications` |
| `Process.Start()` | `NSWorkspace.shared.openApplication` |
| WinForms | SwiftUI |
| SQLite/XML 配置 | JSON (`~/Library/Application Support/GeniusMac/Config.json`) |

## 新增特性

- **窗口前台检测**: 仅在目标窗口处于前台时才模拟按键和捕捉像素
- **JSON 配置**: 取代原有的 SQLite/XML，更简洁
- **Combine 响应式**: 窗口状态使用 `@Published` + Combine 绑定

## 权限要求

首次运行需要用户在 **系统设置 > 隐私与安全性** 中授权：

1. **屏幕录制** — `CGWindowListCreateImage` 捕捉其他应用窗口像素
2. **辅助功能** — `CGEvent.post` 模拟系统级按键

## 打开与构建

### 方式 1：Xcode

1. 打开 [Genius.xcodeproj](/Users/eugene/Downloads/GeniusMac/SwiftGenius/Genius.xcodeproj)
2. 选择 `GeniusMac` scheme
3. `Build & Run`

### 方式 2：命令行构建 Xcode app

```bash
./scripts/build_xcode_app.sh
```

### 方式 3：SwiftPM 快速编译

```bash
swift build
```

说明：

- 日常维护推荐优先使用 Xcode 工程
- `project.yml` 是 XcodeGen 的配置源；如果需要重建 `.xcodeproj`，执行 `xcodegen generate`
- 当前不再推荐手工创建或维护独立的 `.app` 目录

## 按键映射参考（macOS KeyCode）

原 .NET 项目使用 Windows Virtual Key Codes，macOS 使用 CGKeyCode。示例 `Config.json` 已包含常用映射：

| 按键 | macOS KeyCode |
|------|---------------|
| 1-0 | 18, 19, 20, 21, 23, 22, 26, 28, 25, 29 |
| F1-F12 | 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111 |
| ` | 50 |
| Space | 49 |

## 配置说明

配置文件自动创建于 `~/Library/Application Support/GeniusMac/Config.json`：

```json
{
  "captureX": 100,          // 像素捕捉 X 坐标
  "captureY": 100,          // 像素捕捉 Y 坐标
  "interval": 100,          // 前台采样间隔（毫秒）
  "backgroundInterval": 500,// 后台采样间隔（毫秒）
  "filterG": 0,             // 绿色过滤值
  "filterB": 0,             // 蓝色过滤值
  "gamePath": "",           // 游戏启动路径
  "keyMappings": {          // 颜色(R值) -> 按键码 映射
    "10": 18,
    "15": 19
  },
  "accounts": [             // 账号列表
    { "username": "", "password": "" }
  ]
}
```
