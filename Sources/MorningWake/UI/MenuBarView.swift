import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isEditingTime: Bool = false
    @State private var selectedScheduleTab: Int = 0 // 0: 工作日, 1: 周末慢晨
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            
            // 1. 顶部栏：应用名称、M4定制标、日历节假日状态与整体就绪指示
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
                            
                            Text("M4 定制")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        Text(appState.isAlarmEnabled ? (appState.isSnoozing ? "小睡进行中" : (appState.isSkippedToday ? "今日已跳过" : (appState.todayScheduleInfo.isEmpty ? "Mac mini 唤醒已就绪" : "今天 · \(appState.todayScheduleInfo)"))) : "闹钟已暂停")
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
            .padding(.top, 14)
            
            // 2. 响铃控制条（正在响铃时展示）
            if appState.isAlarmRinging {
                ringingControlCard
            }
            
            // 3. 小睡横幅
            if appState.isSnoozing {
                snoozeBanner
            }
            
            // 4. 核心主卡片：采用 100% 原汁原味的 iOS 手机闹钟格式与布局
            VStack(spacing: 11) {
                // 上排：下次唤醒的具体日期（今天/明天/具体几号）与倒计时提示
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Text("下次唤醒")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if appState.isAlarmEnabled {
                            Text("· \(appState.nextAlarmDayTitle)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
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
                    }
                }
                
                // 核心行：iOS 闹钟标志性格式 —— 左侧大字号时间 (带上下午) + 右侧 iOS 原生绿色 Switch 开关
                HStack(alignment: .center) {
                    Button(action: {
                        toggleEditing()
                    }) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            // iOS 风格上下午标识
                            let targetHour = appState.nextAlarmTargetHour
                            let periodStr = targetHour < 12 ? "上午" : "下午"
                            Text(periodStr)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(appState.isAlarmEnabled ? .secondary : .secondary.opacity(0.4))
                            
                            // iOS 闹钟特有的轻盈大数字 (46pt SF Pro 字体)
                            Text(appState.nextAlarmDate != nil ? String(format: "%02d:%02d", appState.nextAlarmTargetHour, appState.nextAlarmTargetMinute) : "--:--")
                                .font(.system(size: 46, weight: .light, design: .default))
                                .foregroundColor(appState.isAlarmEnabled ? .primary : .secondary.opacity(0.4))
                                .fixedSize()
                        }
                    }
                    .buttonStyle(.plain)
                    .help("点击就地编辑闹钟时间")
                    
                    Spacer()
                    
                    // iOS 标志性绿色大开关（紧随时间右侧）
                    Toggle("", isOn: $appState.isAlarmEnabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.92)
                        .help("开启或关闭闹钟")
                }
                
                // 智能时间接力提示（例如今天时刻已过，明确提示自动接力明日排期）
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
                
                // 下排：作息摘要与音源 + iOS 风格展开修改胶囊
                Divider()
                    .opacity(0.6)
                
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
                            Text(isEditingTime ? "收起" : "修改")
                                .font(.system(size: 10, weight: .semibold))
                            Image(systemName: isEditingTime ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("展开/收起 iOS 闹钟调节面板")
                }
                
                // 展开区：iOS 闹钟编辑页专属的双方块大卡片时间选择器与快捷胶囊
                if isEditingTime {
                    inlineEditSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(12)
            .padding(.horizontal, 14)
            
            // 5. 试跑状态进度指示
            if appState.isTestRunning {
                testRunningCard
            }
            
            Divider()
                .padding(.horizontal, 14)
            
            // 6. 底部操作栏
            HStack(spacing: 8) {
                if !appState.isTestRunning && !appState.isAlarmRinging {
                    Button(action: {
                        appState.startTestRun()
                    }) {
                        Label("立即试跑", systemImage: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: {
                    appState.toggleSkipToday()
                }) {
                    Label(appState.isSkippedToday ? "取消跳过" : "今日跳过", systemImage: "arrow.uturn.forward")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .tint(appState.isSkippedToday ? .orange : nil)
                
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
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: 360)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isEditingTime)
    }
    
    // MARK: - 辅助子视图
    
    private func toggleEditing() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isEditingTime.toggle()
        }
    }
    
    private var inlineEditSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            if appState.repeatSchedule == .smartWorkday {
                // iOS 分段切换器：工作日 vs 周末慢晨
                Picker("", selection: $selectedScheduleTab) {
                    Text("💼 工作日唤醒").tag(0)
                    Text("☕ 周末慢晨").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                if selectedScheduleTab == 0 {
                    // 工作日时间选择器 (iOS 闹钟双方块大卡片 + 快捷增减)
                    VStack(spacing: 6) {
                        IOSTimePickerView(
                            hour: $appState.workdayHour,
                            minute: $appState.workdayMinute,
                            accentColor: .blue,
                            style: .expanded,
                            showQuickButtons: true
                        )
                        
                        Text("法定工作日及节假日调休上班日准时响铃")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    // 周末慢晨时间选择器
                    VStack(spacing: 8) {
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
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("周末及法定节假日保持静音，不打扰休息")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // 单轨固定响铃时间选择器
                VStack(spacing: 6) {
                    IOSTimePickerView(
                        hour: $appState.alarmHour,
                        minute: $appState.alarmMinute,
                        accentColor: .blue,
                        style: .expanded,
                        showQuickButtons: true
                    )
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
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
                
                Button("完成") {
                    toggleEditing()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.top, 4)
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
                        Label("清醒 (保持播放)", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut(.defaultAction)
                    
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
    
    private var testRunningCard: some View {
        VStack(spacing: 6) {
            HStack {
                WaveformIndicator(isActive: true)
                Text("试跑模拟中 (6秒快速预览)...")
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
    
    private var playerTargetName: String {
        switch appState.playerTarget {
        case .localFile: return "本地音乐"
        case .youtubeMusic: return "YT Music"
        case .appleMusic: return "Apple Music"
        case .fallbackOnly: return "自然和弦"
        }
    }
}
