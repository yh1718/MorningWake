# MorningWake 🌅

> 专为 macOS（针对 Mac mini M4 深度定制）打造的原生极简、平滑渐进式晨间音乐唤醒应用。

---

## 🌟 项目亮点

* 🎵 **2分钟平滑对数渐入**：CoreAudio 底层以 100ms 高频微步进调谐，在 120 秒内从 20% 极其缓慢抬升至 90%，完全消除机械突兀感与刺耳惊吓。
* 🖥️ **Mac mini M4 专属硬件感知**：
  * **点亮外接显示器**：利用 `IOPMAssertionDeclareUserActivity` 在响铃时破晓点亮外接显示器（如 DisplayPort / HDMI 监视器）。
  * **显示器调音避坑**：自动检测音频设备可调节性，智能绕过无法软件调音的显示器通道，强制锁定机载 `Mac mini 扬声器`。
  * **常电定时唤醒**：针对 Mac mini 交流常电特性，提供 100% 准时的休眠硬件预热唤醒。
* 🔔 **锁屏交互与快捷键响应**：
  * 锁屏界面直接呈现交互式通知卡片：支持 **「我已清醒 (保持播放)」**、**「小睡 10 分钟」**、**「完全关闭音乐」**。
  * 菜单栏支持键盘快捷键：按 `Esc` 快速停止，按 `Enter` 快速清醒。
* 🔄 **音频输出无缝还原**：闹钟关闭后自动切回触发前的原音频输出设备（如显示器或耳机），无缝衔接日常使用。
* 🛡️ **安全熔断与干预检测**：
  * 30分钟无人应答安全熔断自动释放系统防休眠锁。
  * 渐变过程中用户轻按键盘 F11/F12 物理音量键即刻平稳退出自动淡入，尊重人工介入。
* ⚡ **纯原生极致轻量**：采用纯 Swift + SwiftUI 原生编写，开机自启常驻，内存占用仅约 20MB。

---

## 📂 工程结构

```text
MorningWake/
├── Package.swift                             # SPM 原生工程定义 (Target: macOS 13+)
├── Support/
│   └── Info.plist                            # LSUIElement=true（纯菜单栏常驻无 Dock 占位）
├── Sources/
│   └── MorningWake/
│       ├── App/
│       │   ├── MorningWakeApp.swift          # @main 入口与 MenuBarExtra 配置
│       │   └── AppState.swift                # 全局状态调度、持久化、定时触发
│       ├── Core/
│       │   ├── AudioEngine.swift             # CoreAudio 硬件音量淡入引擎与扬声器锁定
│       │   ├── PlayerController.swift        # YouTube Music 激活、媒体键注入与兜底
│       │   ├── PowerManager.swift            # IOKit 外接屏幕点亮与防休眠锁定
│       │   └── HardwareInfo.swift            # Mac mini M4 硬件与芯片识别
│       ├── UI/
│       │   ├── MenuBarView.swift             # 菜单栏主交互浮窗
│       │   ├── SettingsView.swift            # 详细偏好设置面板
│       │   ├── SettingsWindowManager.swift   # 独立设置窗口管理
│       │   └── WaveformIndicator.swift       # 动态音频波形指示微动画
│       └── Resources/
│           └── fallback_alarm.wav            # 内置生成的离线和弦自然唤醒铃声
├── scripts/
│   └── build_app.sh                          # 自动化编译、签名与打包脚本
└── LEGACY_MAC_AUTOMATION.md                  # 历史初代自动化脚本完整归档文档
```

## 📥 下载安装 (Mac 专有 DMG 格式)

直接前往 [GitHub Releases](https://github.com/yh1718/MorningWake/releases/latest) 下载预编译安装包：
- **`MorningWake.dmg`**：推荐下载。双击打开后，将 `MorningWake.app` 拖拽到 `Applications`（应用程序）即可完成安装。
- **`MorningWake.zip`**：备用压缩包，解压后双击即可运行。

---

## 🛠️ 源码构建与运行 (开发者)

### 环境要求
- 操作系统：macOS 13.0 (Ventura) 及以上
- 推荐机型：Mac mini (Apple M4)
- 工具链：Xcode Command Line Tools / Swift 5.9+

### 一键构建打包
```zsh
git clone https://github.com/yh1718/MorningWake.git
cd MorningWake
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

构建产物位于 `build/MorningWake.app`。

### 安装与自启
```zsh
# 复制到系统应用程序目录
cp -R build/MorningWake.app /Applications/

# 运行应用
open /Applications/MorningWake.app
```
打开应用后，在顶部菜单栏日出图标中点击「偏好设置」，开启「开机自动启动」即可。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
