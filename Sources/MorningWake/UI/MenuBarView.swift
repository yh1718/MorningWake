import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isEditingTime: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            
            // 1. 顶部栏：应用名称、M4定制标、日历节假日状态与主开关
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
                        
                        Text(appState.isAlarmEnabled ? (appState.isSnoozing ? "小睡进行中" : (appState.isSkippedToday ? "今日已跳过" : (appState.todayScheduleInfo.isEmpty ? "Mac mini 唤醒已就绪" : "今天 · \(appState.todayScheduleInfo)"))) : "已暂停")
                            .font(.system(size: 11))
                            .foregroundColor(appState.isSnoozing ? .purple : (appState.isSkippedToday ? .orange : .secondary))
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $appState.isAlarmEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.85)
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
            
            // 4. 核心主卡片：优化结构、防截断、大显示面积、就地修改交互
            VStack(spacing: 10) {
                // 上排：下次唤醒的明确日期（今天/明天/周几）+ 标签 + 倒计时指示
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
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isAlarmEnabled ? (appState.isSnoozing ? Color.purple : (appState.isSkippedToday ? Color.orange : Color.green)) : Color.gray)
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
                
                // 中排：大字体唤醒时间（带 fixedSize 绝对防截断）与醒目「修改时间」操作标签
                HStack(alignment: .center) {
                    Button(action: {
                        toggleEditing()
                    }) {
                        Text(appState.nextAlarmDate != nil ? String(format: "%02d:%02d", appState.nextAlarmTargetHour, appState.nextAlarmTargetMinute) : "--:--")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .help("点击就地修改唤醒时间")
                    
                    Spacer()
                    
                    Button(action: {
                        toggleEditing()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditingTime ? "chevron.up" : "pencil")
                                .font(.system(size: 10, weight: .semibold))
                            Text(isEditingTime ? "收起" : "修改时间")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(isEditingTime ? .secondary : .blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isEditingTime ? Color(NSColor.controlBackgroundColor) : Color.blue.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("就地展开/收起时间修改")
                }
                
                // 智能时间接力提示（例如今天时刻已过，明确提示自动接力明日工作日）
                if let notice = appState.scheduleNotice, !notice.isEmpty && appState.isAlarmEnabled {
                    HStack(spacing: 4) {
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
                
                // 下排：作息摘要与当前音源
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
                }
                
                // 展开区：就地快速修改面板（采用紧凑微调器，彻底杜绝下拉大菜单遮挡重叠）
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
        VStack(spacing: 10) {
            Divider()
            
            if appState.repeatSchedule == .smartWorkday {
                // 工作日时间快速调节
                HStack {
                    Label("工作日作息", systemImage: "briefcase.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                    TimeStepperView(hour: $appState.workdayHour, minute: $appState.workdayMinute, accentColor: .blue)
                }
                
                // 周末与慢晨作息调节与开关
                HStack {
                    HStack(spacing: 4) {
                        Label("周末慢晨", systemImage: "sun.max.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                        Toggle("", isOn: $appState.weekendEnabled)
                            .toggleStyle(.switch)
                            .scaleEffect(0.65)
                    }
                    Spacer()
                    if appState.weekendEnabled {
                        TimeStepperView(hour: $appState.weekendHour, minute: $appState.weekendMinute, accentColor: .orange)
                    } else {
                        Text("静音休息")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
            } else {
                HStack {
                    Text("响铃时间")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    TimeStepperView(hour: $appState.alarmHour, minute: $appState.alarmMinute, accentColor: .blue)
                }
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
