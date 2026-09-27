import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState = AppState.shared
    
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
                        
                        Text(appState.isAlarmEnabled ? (appState.isSnoozing ? "小睡进行中" : (appState.isSkippedToday ? "今日已跳过" : "Mac mini 唤醒已就绪")) : "已暂停")
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
            
            // 核心卡片：下次唤醒时间与倒计时
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%02d:%02d", appState.alarmHour, appState.alarmMinute))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    
                    Spacer()
                    
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
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Label(appState.playerTarget == .localFile ? "本地音乐" : (appState.playerTarget == .youtubeMusic ? "YT Music" : (appState.playerTarget == .appleMusic ? "Apple Music" : "自然和弦")), systemImage: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Label("Mac mini 扬声器", systemImage: "hifispeaker.fill")
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
        .frame(width: 315)
    }
}
