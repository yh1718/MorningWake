import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showQuickEdit: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            
            // 顶部栏：Logo、M4定制徽标、状态与主开关
            HStack {
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
                        HStack(spacing: 4) {
                            Text("MorningWake")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("M4 定制")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
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
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // 响铃状态控制区（清醒保持播放 / 完全停止 / 小睡）
            if appState.isAlarmRinging {
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
                            .keyboardShortcut(.defaultAction) // 回车快捷键
                            
                            Button(action: {
                                appState.stopAlarm()
                            }) {
                                Label("关闭音乐", systemImage: "stop.fill")
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction) // Esc 快捷键
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
                .padding(.horizontal, 12)
            }
            
            // 小睡激活状态横幅
            if appState.isSnoozing {
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
                .padding(.horizontal, 12)
            }
            
            // 核心卡片：下次唤醒时间、修改标签与倒计时
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        // 点击大数字可快捷呼出修改
                        Button(action: {
                            showQuickEdit.toggle()
                        }) {
                            Text(appState.nextAlarmDate != nil ? String(format: "%02d:%02d", appState.nextAlarmTargetHour, appState.nextAlarmTargetMinute) : "--:--")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        .help("点击快速修改唤醒时刻")
                        
                        // 状态标签（如“工作日”、“中秋假期”）
                        if !appState.nextAlarmBadge.isEmpty && appState.isAlarmEnabled {
                            Text(appState.nextAlarmBadge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(5)
                        }
                        
                        // 明确的【修改】交互标签按钮
                        Button(action: {
                            showQuickEdit.toggle()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 8, weight: .semibold))
                                Text("修改")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("快速修改唤醒时间与作息")
                        .popover(isPresented: $showQuickEdit, arrowEdge: .bottom) {
                            QuickEditView(isPresented: $showQuickEdit)
                        }
                    }
                    
                    Spacer()
                    
                    // 倒计时状态小卡片
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isAlarmEnabled ? (appState.isSnoozing ? Color.purple : (appState.isSkippedToday ? Color.orange : Color.green)) : Color.gray)
                            .frame(width: 6, height: 6)
                        
                        Text(appState.isSkippedToday ? "今日跳过" : appState.countdownString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(appState.isSnoozing ? .purple : (appState.isSkippedToday ? .orange : .primary))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                HStack(spacing: 6) {
                    Label(appState.repeatScheduleSummary, systemImage: "repeat")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Label(appState.playerTarget == .localFile ? "本地音乐" : (appState.playerTarget == .youtubeMusic ? "YT Music" : (appState.playerTarget == .appleMusic ? "Apple Music" : "自然和弦")), systemImage: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(10)
            .padding(.horizontal, 12)
            
            // 试跑状态进度指示
            if appState.isTestRunning {
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
                .padding(.horizontal, 12)
            }
            
            Divider()
                .padding(.horizontal, 12)
            
            // 底部操作按钮栏
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
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(width: 320)
    }
}

// MARK: - 快速修改时间小浮窗

struct QuickEditView: View {
    @ObservedObject var appState = AppState.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("修改唤醒时间")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button("完成") {
                    isPresented = false
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            Divider()
            
            if appState.repeatSchedule == .smartWorkday {
                // 工作日时间快速微调
                HStack {
                    Label("工作日", systemImage: "briefcase.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                    timePickers(hour: $appState.workdayHour, minute: $appState.workdayMinute)
                }
                
                // 周末时间快速微调与开关
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
                        timePickers(hour: $appState.weekendHour, minute: $appState.weekendMinute)
                    } else {
                        Text("休息静音")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // 传统响铃时间微调
                HStack {
                    Text("响铃时间")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    timePickers(hour: $appState.alarmHour, minute: $appState.alarmMinute)
                }
            }
            
            Divider()
            
            HStack {
                Button(action: {
                    isPresented = false
                    SettingsWindowManager.shared.showSettings()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape")
                        Text("偏好设置...")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !appState.todayScheduleInfo.isEmpty {
                    Text("今日: \(appState.todayScheduleInfo)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 250)
    }
    
    private func timePickers(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker("", selection: hour) {
                ForEach(0..<24) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 52)
            
            Text(":")
                .font(.system(size: 11, weight: .bold))
            
            Picker("", selection: minute) {
                ForEach(0..<60) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 52)
        }
    }
}
