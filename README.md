# MorningWake 🌅

> 专为 macOS（针对 Mac mini M4 深度定制）打造的原生极简、平滑渐进式晨间音乐唤醒应用。

---

## 🌟 项目亮点

* 🎵 **平滑微步渐进淡入**：CoreAudio 底层以 100ms 高频微步进调谐，在设定时长内（默认 120 秒）平滑抬升至唤醒音量，完全消除突兀惊吓。
* 🎶 **多音源自由适配**：
  * **YouTube Music**：支持桌面客户端一键调起与模拟媒体键播放。
  * **Apple Music**：系统原生音乐 App 深度无缝调度。
  * **自定义本地音乐**：自由导入 MP3 / M4A / FLAC / WAV / AAC 等音频文件。
  * **离线和弦自然音**：内置柔和晨鸣音频作为安全兜底。
* 📅 **灵活日程与个性排期**：
  * 支持 **每天**、**仅工作日**、**仅周末**，以及 **自定义星期 (周一至周日独立勾选)**。
  * 支持自定义小睡时长（5 / 10 / 15 / 20 分钟）。
* 🖥️ **Mac mini M4 专属硬件感知**：
  * **点亮外接显示器**：利用 `IOPMAssertionDeclareUserActivity` 在响铃时破晓点亮外接显示器（如 DisplayPort / HDMI 监视器）。
  * **显示器调音避坑**：自动检测音频设备可调节性，智能绕过无法软件调音的显示器通道，强制锁定机载 `Mac mini 扬声器`。
  * **常电定时唤醒**：针对 Mac mini 交流常电特性，提供 100% 准时的休眠硬件预热唤醒，并自动防旧事件残留。
* 🔔 **锁屏交互与快捷键响应**：
  * 锁屏界面直接呈现交互式通知卡片：支持 **「我已清醒 (保持播放)」**、**「小睡一下」**、**「完全关闭音乐」**。
  * 菜单栏支持键盘快捷键：按 `Esc` 快速停止，按 `Enter` 快速清醒。
* 🔄 **音频输出无缝还原**：闹钟关闭后自动切回触发前的原音频输出设备（如显示器或耳机），无缝衔接日常使用。
* 🛡️ **安全熔断与干预检测**：
  * 30分钟无人应答安全熔断自动释放系统防休眠锁。
  * 渐变过程中用户轻按键盘 F11/F12 物理音量键即刻平稳平滑退出自动淡入，尊重人工介入。
* ⚡ **纯原生极致轻量**：采用纯 Swift + SwiftUI 原生编写，附带精美 macOS 原生 App 图标，开机自启常驻，内存占用仅约 20MB。

---

## 📂 工程结构

```text
MorningWake/
├── Package.swift                             # SPM 原生工程定义 (Target: macOS 13+)
├── Support/
│   ├── Info.plist                            # 应用元数据与常驻配置 (LSUIElement=true)
│   ├── AppIcon.icns                          # 现代 macOS 破晓渐变原生高清应用图标
│   └── generate_icon.swift                   # 基于 CoreGraphics 的矢量多分辨率图标生成器
├── Sources/
│   └── MorningWake/
│       ├── App/
│       │   ├── MorningWakeApp.swift          # @main 入口与 MenuBarExtra 配置
│       │   └── AppState.swift                # 全局状态调度、多排期、持久化、定时触发
│       ├── Core/
│       │   ├── AudioEngine.swift             # CoreAudio 硬件音量淡入引擎、热插拔监听与扬声器锁定
│       │   ├── PlayerController.swift        # 多音源调度 (YouTube Music / Apple Music / 本地音频)
│       │   ├── PowerManager.swift            # IOKit 外接屏幕点亮、休眠定时唤醒管理
│       │   └── HardwareInfo.swift            # Mac mini M4 硬件与芯片识别
│       ├── UI/
│       │   ├── MenuBarView.swift             # 菜单栏主交互浮窗与状态指示
│       │   ├── SettingsView.swift            # 偏好设置面板 (音源、日程、硬件、声卡路由、音频试听)
│       │   ├── SettingsWindowManager.swift   # 独立设置窗口管理
│       │   └── WaveformIndicator.swift       # 动态音频波形指示微动画
│       └── Resources/
│           └── fallback_alarm.wav            # 内置生成的离线和弦自然唤醒铃声
├── Tests/
│   └── MorningWakeTests/
│       └── MorningWakeTests.swift            # 曲线算法、排期数学、设备与小睡同步单元测试
├── scripts/
│   ├── build_app.sh                          # 自动化编译、签名与打包脚本
│   └── package_dmg.sh                        # 自动生成 .dmg 镜像与 .zip 归档脚本
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

### 运行单元测试
```zsh
swift test
```
覆盖核心 `FadeCurve` 渐变曲线运算、多排期筛选解析、硬件音频标签判定与小睡状态动态联动测试。

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
