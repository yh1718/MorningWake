# 初始 macOS 自动化脚本完整归档文档 (mac-automation)

本文档整理归档了位于 `~/Scripts/mac-automation/` 的初代晨间音乐唤醒自动化任务的所有配置、脚本源码、历史演变、系统级映射信息及持久化停用记录。该任务现已被原生应用程序 **MorningWake (Mac mini M4 专享版)** 完整接管。

---

## 一、原始目录与文件清单

原脚本仓库完整保留在本地磁盘：`~/Scripts/mac-automation/`

```text
~/Scripts/mac-automation/
└── youtube-music/
    ├── README.md                   # 原始模块使用与维护说明文档 (2,011 字节)
    ├── com.user.youtubemusic.plist # macOS launchd 定时调度配置文件 (802 字节)
    └── youtube-music.sh            # 核心执行 Shell 脚本 (1,269 字节，带可执行权限 755)
```

---

## 二、核心文件完整内容归档

### 1. 执行脚本：`youtube-music.sh`
- **文件位置**：`~/Scripts/mac-automation/youtube-music/youtube-music.sh`
- **解释器**：`/bin/zsh`
- **功能描述**：解除静音、初始设定极低音量（20%）、拉起客户端、执行 2 分钟平滑升音至 90%（每 8.5 秒递增 5%）。

```zsh
#!/bin/zsh

LOG_FILE="$HOME/Library/Logs/youtube-music.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "==================== 任务开始 ===================="

# 1. 启动前将音量初始设为 20% 并解除静音
log "正在解除静音并将初始音量设为 20%..."
if osascript -e "set volume output volume 20 without output muted" >> "$LOG_FILE" 2>&1; then
    log "初始音量 20% 设置成功"
else
    log "【警告】初始音量调整失败，请检查系统权限"
fi

# 2. 打开 YouTube Music
log "正在启动 YouTube Music..."
if open -a "YouTube Music" >> "$LOG_FILE" 2>&1; then
    log "YouTube Music 启动命令已触发"
else
    log "【错误】无法启动 YouTube Music"
fi

# 3. 音量在 2 分钟内缓慢平滑淡入至 90%（每隔约 8.5 秒递增 5%）
log "开始执行 2 分钟平滑淡入（20% -> 90%）..."
for vol in 25 30 35 40 45 50 55 60 65 70 75 80 85 90; do
    sleep 8.5
    if osascript -e "set volume output volume $vol" >> "$LOG_FILE" 2>&1; then
        log "音量平滑递增至 ${vol}%"
    else
        log "【警告】音量递增至 ${vol}% 失败"
    fi
done
log "2 分钟音量淡入完成，当前音量为 90%"

log "==================== 任务结束 ===================="
```

---

### 2. 调度配置：`com.user.youtubemusic.plist`
- **文件位置**：`~/Scripts/mac-automation/youtube-music/com.user.youtubemusic.plist`
- **原映射位置**：`~/Library/LaunchAgents/com.user.youtubemusic.plist`
- **调度时间**：每天早晨 **07:35** 准时触发。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.youtubemusic</string>

    <key>ProgramArguments</key>
    <array>
        <string>~/Scripts/mac-automation/youtube-music/youtube-music.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>35</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>~/Library/Logs/com.user.youtubemusic.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>~/Library/Logs/com.user.youtubemusic.stderr.log</string>
</dict>
</plist>
```

---

### 3. 原始操作说明：`README.md`
- **文件位置**：`~/Scripts/mac-automation/youtube-music/README.md`

```markdown
# YouTube Music 晨间自动化播放任务 🎵

用于每天早晨自动唤起 YouTube Music 桌面应用，并以舒适的平滑淡入音量自动播放音乐，最终达到最大音量。

---

## 📂 模块文件结构

~/Scripts/mac-automation/youtube-music/
├── youtube-music.sh            # 核心执行脚本（带执行权限）
├── com.user.youtubemusic.plist # launchd 调度配置文件
└── README.md                   # 本说明文档

---

## ⏰ 调度与触发行为

- **触发时间**：每天早晨 **07:35**。
- **执行流程**：
  1. 解除系统静音，并将初始音量设为 **30%**（避免高音量瞬间惊吓）；
  2. 拉起 `/Applications/YouTube Music.app`（依靠客户端 `resumeOnStart: true` 自动继续播放）；
  3. 执行音量平滑淡入：每隔 2 秒提升 10%，自 `40% -> 50% -> 60% -> 70% -> 80% -> 90% -> 100%`，约 14 秒平滑过渡至最大音量。

---

## 🔗 系统映射关系

- **LaunchAgent 路径**：
  `~/Library/LaunchAgents/com.user.youtubemusic.plist`
  *(已配置为指向本目录下 plist 文件的软链接)*
- **执行脚本路径**：
  `~/Scripts/mac-automation/youtube-music/youtube-music.sh`
- **日志路径**：
  - 脚本执行日志：`~/Library/Logs/youtube-music.log`
  - 系统标准输出：`~/Library/Logs/com.user.youtubemusic.stdout.log`
  - 系统标准错误：`~/Library/Logs/com.user.youtubemusic.stderr.log`
```

---

## 三、系统级残留排查与彻底停用状态

为了确保在 Mac 重启、用户注销或锁屏时**绝对不会发生旧任务自动复活**，已实施双重彻底停用策略：

1. **当前会话卸载**：
   已执行 `launchctl unload ~/Library/LaunchAgents/com.user.youtubemusic.plist`，当前运行队列中已无该服务。
2. **全局持久化禁用**：
   已执行 `launchctl disable gui/$(id -u)/com.user.youtubemusic`，在 macOS launchd 数据库中标记永久禁用。
3. **消除启动扫描软链接**：
   将 `~/Library/LaunchAgents/com.user.youtubemusic.plist` 重命名为 `com.user.youtubemusic.plist.disabled`，彻底切断系统开机自动加载的路径。
4. **进程与计划任务核查**：
   - 进程树检查：无任何 `youtube-music.sh` 在后台运行。
   - `crontab -l`：确认用户 crontab 为空。
   - 音频播放状态：YouTube Music 当前处于静止未运行状态。

---

## 四、历史运行日志位置（供排查参考）

原脚本生成的运行日志仍安全保留在用户日志目录，供后续排查：
- 脚本执行日志：`~/Library/Logs/youtube-music.log` (记录了每日 07:35 的逐步升音日志)
- launchd 标准输出：`~/Library/Logs/com.user.youtubemusic.stdout.log`
- launchd 标准错误：`~/Library/Logs/com.user.youtubemusic.stderr.log`

---

## 五、如何恢复旧任务（如未来需要备用）

若后续需要重新恢复使用旧版脚本，仅需按顺序执行以下两行命令：
```zsh
# 1. 恢复软链接名称
mv ~/Library/LaunchAgents/com.user.youtubemusic.plist.disabled ~/Library/LaunchAgents/com.user.youtubemusic.plist

# 2. 启用并加载调度
launchctl enable gui/$(id -u)/com.user.youtubemusic
launchctl load ~/Library/LaunchAgents/com.user.youtubemusic.plist
```

---

## 六、与 MorningWake 原生应用的全景对照

| 维度 | 初始 mac-automation 脚本 | MorningWake 原生应用 (Mac mini M4 专享) |
| :--- | :--- | :--- |
| **应用形态** | 隐藏在后台的 Shell 脚本 | 顶部菜单栏精致卡片浮窗 + 独立居中设置面板 |
| **显示器联动** | 黑屏灭屏时无法唤醒屏幕 | `IOPMAssertionDeclareUserActivity` **即刻点亮外接显示器** |
| **设备兼容** | 遇 DisplayPort 显示器直接哑火 | **自动绕过不可调音显示器**，强制锁定机载 `Mac mini 扬声器` |
| **音量曲线** | 粗糙的 sleep 阶梯跳跃 | `CoreAudio` 100ms 无级平滑渐变，支持**对数感知曲线** |
| **早起交互** | 起床后需开终端杀进程 | 锁屏交互通知卡片、支持 **小睡 10 分钟**、**保持播放**、按 `Esc` 退出 |
| **状态还原** | 永久篡改系统输出设备与音量 | 闹钟关闭后**自动还原**至触发前的原音频输出（如耳机或显示器） |
