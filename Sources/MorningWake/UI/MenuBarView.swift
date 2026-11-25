import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isEditingTime: Bool = false
    @State private var selectedScheduleTab: Int = 0 // 0: 工作日, 1: 周末慢晨
    @State private var measuredHeight: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            
            // 1. 顶部栏：应用名称、芯片定制标、日历节假日状态与整体就绪指示
            topBarView
            
            // 2. 响铃控制条（正在响铃时展示）
            if appState.isAlarmRinging {
                ringingControlCard
            }
            
            // 3. 小睡横幅
            if appState.isSnoozing {
                snoozeBanner
            }
            
            // 4. 核心主卡片：采用 100% 原汁原味的 iOS 手机闹钟格式与布局
            mainAlarmCard
            
            // 5. 试跑状态进度指示
            if appState.isTestRunning {
                testRunningCard
            }
            
            // 5.5 常态长效手动播放卡片
            if appState.isManualPlaying && !appState.isAlarmRinging {
                manualPlaybackCard
            }
            
            Divider()
                .padding(.horizontal, 14)
            
            // 6. 底部操作栏
            bottomActionBar
        }
        .frame(width: 360)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: MenuBarContentHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(MenuBarContentHeightKey.self) { height in
            if height > 50 {
                measuredHeight = height
            }
        }
        .background(WindowResizingBridge(targetHeight: measuredHeight))
    }
    
    // MARK: - 1. 顶部状态栏
    
    private var topBarView: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("MorningWake")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(hardwareChipBadge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(statusSubtitleText)
                        .font(.system(size: 11))
                        .foregroundColor(appState.isSnoozing ? .purple : (appState.isSkippedToday ? .orange : .secondary))
                }
            }
            
            Spacer()
            
            // 顶部状态指示胶囊
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.isAlarmEnabled ? (appState.isSnoozing ? Color.purple : (appState.isSkippedToday ? Color.orange : Color.green)) : Color.gray)
                    .frame(width: 6, height: 6)
                Text(appState.isAlarmEnabled ? (appState.isSkippedToday ? "已跳过" : "定时中") : "已停用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - 4. 核心主卡片（常规态与就地编辑态就地平滑置换）
    
    private var mainAlarmCard: some View {
        VStack(spacing: isEditingTime ? 8 : 10) {
            if isEditingTime {
                editingCardContent
            } else {
                normalCardContent
            }
        }
        .padding(isEditingTime ? 11 : 13)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal, 14)
    }
    
    /// 常规态：展示下次唤醒信息、大字号时间 + iOS 原生开关与作息音源摘要
    private var normalCardContent: some View {
        VStack(spacing: 10) {
            // 上排：下次唤醒的具体日期与倒计时提示
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Text("下次唤醒")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("· \(appState.isAlarmEnabled ? appState.nextAlarmDayTitle : "已暂停")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.isAlarmEnabled ? .primary : .secondary)
                    
                    if !appState.nextAlarmBadge.isEmpty && appState.isAlarmEnabled {
                        Text(appState.nextAlarmBadge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(appState.nextAlarmBadge == "工作日" ? .blue : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((appState.nextAlarmBadge == "工作日" ? Color.blue : Color.orange).opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 倒计时胶囊指示
                if appState.isAlarmEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isSnoozing ? Color.purple : (appState.isSkippedToday ? Color.orange : Color.green))
                            .frame(width: 6, height: 6)
                        
                        Text(appState.isSkippedToday ? "今日跳过" : appState.countdownString)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(appState.isSnoozing ? .purple : (appState.isSkippedToday ? .orange : .primary))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                } else {
                    Text("已暂停")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(12)
                }
            }
            
            // 核心行：iOS 闹钟标志性格式 —— 左侧大字号时间 (带上下午) + 右侧 iOS 原生绿色 Switch 开关
            HStack(alignment: .center) {
                Button(action: {
                    toggleEditing()
                }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        let targetHour = appState.displayTargetHour
                        let targetMinute = appState.displayTargetMinute
                        let periodStr = targetHour < 12 ? "上午" : "下午"
                        Text(periodStr)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(appState.isAlarmEnabled ? .secondary : .secondary.opacity(0.4))
                        
                        Text(String(format: "%02d:%02d", targetHour, targetMinute))
                            .font(.system(size: 44, weight: .light, design: .default))
                            .foregroundColor(appState.isAlarmEnabled ? .primary : .secondary.opacity(0.45))
                            .fixedSize()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(appState.isAlarmEnabled ? "点击修改唤醒时间" : "闹钟已暂停，点击设置唤醒时间")
                
                Spacer()
                
                // iOS 标志性绿色大开关
                Toggle("", isOn: $appState.isAlarmEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.92)
                    .help("开启或关闭闹钟")
            }
            
            // 智能时间接力提示
            if let notice = appState.scheduleNotice, !notice.isEmpty && appState.isAlarmEnabled {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text(notice)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }
            
            Divider()
                .opacity(0.6)
            
            // 下排：作息摘要与音源 + 修改按钮
            HStack {
                Label(appState.repeatScheduleSummary, systemImage: "repeat")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Label(playerTargetName, systemImage: "music.note")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Button(action: {
                    toggleEditing()
                }) {
                    HStack(spacing: 3) {
                        Text("修改")
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("修改闹钟排期与时间")
            }
        }
    }
    
    /// 就地编辑态：直接就地替代静态时间与摘要，聚焦排期与时钟微调，无冗余重复展示
    private var editingCardContent: some View {
        VStack(spacing: 8) {
            // 上排：下次唤醒与主开关
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("调整唤醒时刻")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(selectedScheduleTab == 0 ? "工作日" : "周末慢晨")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(selectedScheduleTab == 0 ? .blue : .orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background((selectedScheduleTab == 0 ? Color.blue : Color.orange).opacity(0.12))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Toggle("", isOn: $appState.isAlarmEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.85)
                    .help("开启或关闭闹钟")
            }
            
            if appState.repeatSchedule == .smartWorkday {
                // iOS 分段切换器：工作日 vs 周末慢晨
                Picker("", selection: $selectedScheduleTab) {
                    Text("💼 工作日 \(String(format: "%02d:%02d", appState.workdayHour, appState.workdayMinute))").tag(0)
                    Text(appState.weekendEnabled ? "☕ 周末 \(String(format: "%02d:%02d", appState.weekendHour, appState.weekendMinute))" : "☕ 周末 (休)").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                if selectedScheduleTab == 0 {
                    // 工作日时间选择器
                    VStack(spacing: 4) {
                        IOSTimePickerView(
                            hour: $appState.workdayHour,
                            minute: $appState.workdayMinute,
                            accentColor: .blue,
                            style: .expanded,
                            showQuickButtons: true
                        )
                        
                        Text("法定工作日及节假日调休上班日准时响铃")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 1)
                } else {
                    // 周末慢晨时间选择器
                    VStack(spacing: 5) {
                        HStack {
                            Label("周末慢晨唤醒", systemImage: "sun.max.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                            Spacer()
                            Toggle("", isOn: $appState.weekendEnabled)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }
                        .padding(.horizontal, 4)
                        
                        if appState.weekendEnabled {
                            IOSTimePickerView(
                                hour: $appState.weekendHour,
                                minute: $appState.weekendMinute,
                                accentColor: .orange,
                                style: .expanded,
                                showQuickButtons: true
                            )
                            
                            Text("法定节假日及周末延迟唤醒，舒缓慢晨")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        } else {
                            Text("周末及法定节假日保持静音，不打扰休息")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 1)
                }
            } else {
                // 单轨固定响铃时间选择器
                VStack(spacing: 4) {
                    IOSTimePickerView(
                        hour: $appState.alarmHour,
                        minute: $appState.alarmMinute,
                        accentColor: .blue,
                        style: .expanded,
                        showQuickButtons: true
                    )
                }
                .padding(.vertical, 1)
            }
            
            Divider()
                .opacity(0.6)
            
            // 底部操作区：高级设置入口 + 完成按钮
            HStack {
                Button(action: {
                    SettingsWindowManager.shared.showSettings()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape")
                        Text("更多高级排期设置...")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    toggleEditing()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("完成")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 辅助子视图与交互
    
    private func toggleEditing() {
        if !isEditingTime {
            let isWeekendActive = appState.nextAlarmBadge.contains("慢晨") || appState.nextAlarmBadge.contains("周末") || appState.nextAlarmBadge.contains("假期")
            selectedScheduleTab = isWeekendActive ? 1 : 0
        } else {
            // 收起时确保最新排期已计算就绪
            appState.reschedule()
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isEditingTime.toggle()
        }
    }
    
    private var ringingControlCard: some View {
        VStack(spacing: 10) {
            HStack {
                WaveformIndicator(isActive: true)
                Text("晨间唤醒进行中...")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                Spacer()
                Text("\(appState.currentVolumePercent)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Button(action: {
                        appState.keepPlaying()
                    }) {
                        Label("已醒 (保持播放)", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut(.defaultAction)
                    .help("确认已醒，声音将平缓渐缓降低至 40% 并继续播放背景音乐")
                    
                    Button(action: {
                        appState.stopAlarm()
                    }) {
                        Label("关闭音乐", systemImage: "stop.fill")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                }
                
                Button(action: {
                    appState.snooze()
                }) {
                    Label("小睡 \(appState.snoozeDurationMinutes) 分钟", systemImage: "moon.zzz.fill")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if appState.isManualVolumeOverridden {
                    Text("已检测到外部音量调整，已保持手动音量")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal, 14)
    }
    
    private var snoozeBanner: some View {
        HStack {
            Image(systemName: "moon.zzz.fill")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("小睡模式开启 (\(appState.snoozeDurationMinutes)分钟)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                Text("闹钟已暂停，将在不久后再次响起")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("取消小睡") {
                appState.cancelSnooze()
            }
            .font(.system(size: 11))
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 14)
    }
    
    private var manualPlaybackCard: some View {
        HStack(spacing: 10) {
            WaveformIndicator(isActive: true)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("背景音乐播放中")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(playerTargetName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(4)
                }
                
                Text("长效播放模式 · 允许显示器息屏")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Text("\(appState.currentVolumePercent)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Button(action: {
                    appState.stopManualPlayback()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8))
                        Text("停止")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 14)
    }
    
    private var testRunningCard: some View {
        VStack(spacing: 6) {
            HStack {
                WaveformIndicator(isActive: true)
                Text("试跑模拟中 (6秒淡入 + 2秒自动复位)...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(appState.currentVolumePercent)%")
                    .font(.caption)
                    .bold()
            }
            
            ProgressView(value: Double(appState.currentVolumePercent), total: 100.0)
                .tint(.orange)
            
            Button(role: .cancel, action: {
                appState.stopTestRun()
            }) {
                Text("停止测试")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 14)
    }
    
    // MARK: - 6. 底部操作栏
    
    private var bottomActionBar: some View {
        HStack(spacing: 6) {
            if !appState.isTestRunning && !appState.isAlarmRinging {
                // 手动长效播放 / 停止切换按钮
                Button(action: {
                    appState.toggleManualPlayback()
                }) {
                    Label(appState.isManualPlaying ? "停止播放" : "播放音乐", systemImage: appState.isManualPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .tint(appState.isManualPlaying ? .orange : nil)
                .help(appState.isManualPlaying ? "停止当前背景音乐播放并释放防休眠" : "开启长效背景音乐播放（不受试跑倒计时限制）")
                
                // 试跑预览按钮
                Button(action: {
                    appState.startTestRun()
                }) {
                    Label("试跑 (8s)", systemImage: "sparkles")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("模拟 6 秒平滑淡入并在 2 秒后自动复位，用于快速验证唤醒音量与音源")
            }
            
            Button(action: {
                appState.toggleSkipToday()
            }) {
                Label(appState.isSkippedToday ? "取消跳过" : "今日跳过", systemImage: "arrow.uturn.forward")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .tint(appState.isSkippedToday ? .orange : nil)
            .disabled(!appState.isAlarmEnabled)
            .help(appState.isAlarmEnabled ? (appState.isSkippedToday ? "恢复今日闹钟排期" : "跳过今日闹钟，自动顺延至下一排期") : "闹钟未启用，无需跳过")
            
            Spacer()
            
            Button(action: {
                SettingsWindowManager.shared.showSettings()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("打开偏好设置")
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("退出 MorningWake")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
    
    // MARK: - 文本与属性辅助
    
    private var playerTargetName: String {
        switch appState.playerTarget {
        case .localFile: return "本地音乐"
        case .youtubeMusic: return "YT Music"
        case .appleMusic: return "Apple Music"
        case .fallbackOnly: return "自然和弦"
        }
    }
    
    private var hardwareChipBadge: String {
        let chip = HardwareInfo.shared.chipName.replacingOccurrences(of: "Apple ", with: "")
        return chip.isEmpty ? "Mac 定制" : "\(chip) 定制"
    }
    
    private var statusSubtitleText: String {
        if !appState.isAlarmEnabled {
            return "闹钟已暂停"
        }
        if appState.isSnoozing {
            return "小睡进行中"
        }
        if appState.isSkippedToday {
            return "今日已跳过"
        }
        if !appState.todayScheduleInfo.isEmpty {
            return "今天 · \(appState.todayScheduleInfo)"
        }
        return HardwareInfo.shared.isMacMini ? "Mac mini 唤醒已就绪" : "晨间唤醒已就绪"
    }
}

// MARK: - 窗口尺寸顶部锚定动态伸缩桥接器

public struct MenuBarContentHeightKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

public struct WindowResizingBridge: NSViewRepresentable {
    public let targetHeight: CGFloat
    
    public init(targetHeight: CGFloat) {
        self.targetHeight = targetHeight
    }
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            adjustWindow(view)
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            adjustWindow(nsView)
        }
    }
    
    public static func calculateTopAnchoredFrame(currentFrame: NSRect, targetHeight: CGFloat) -> NSRect {
        guard targetHeight > 0 else { return currentFrame }
        let newY = currentFrame.maxY - targetHeight
        return NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: targetHeight)
    }
    
    private func adjustWindow(_ view: NSView) {
        guard let window = view.window else { return }
        guard targetHeight > 50 else { return }
        
        let curFrame = window.frame
        let diff = targetHeight - curFrame.height
        if abs(diff) > 1.5 {
            let newFrame = Self.calculateTopAnchoredFrame(currentFrame: curFrame, targetHeight: targetHeight)
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
