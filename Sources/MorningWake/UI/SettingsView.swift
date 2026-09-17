import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("偏好设置")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("针对 \(HardwareInfo.shared.formattedDisplayName) 定制优化")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Mac mini M4 硬件特征与电源状态
                    GroupBox(label: Label("硬件适配 (Mac mini M4)", systemImage: "cpu.fill")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("设备芯片")
                                Spacer()
                                Text(HardwareInfo.shared.chipName)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            
                            HStack {
                                Text("硬件标识")
                                Spacer()
                                Text(HardwareInfo.shared.modelIdentifier)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("供电模式")
                                Spacer()
                                Text("交流常电 (无合盖休眠限制 · 定时唤醒 100% 可靠)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 2. 音频设备适配（DisplayPort 规避与扬声器锁定）
                    GroupBox(label: Label("音频路由与设备还原", systemImage: "hifispeaker.2.fill")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("响铃时锁定 Mac mini 内置扬声器发声", isOn: $appState.forceBuiltInSpeaker)
                                .help("强制使用机载扬声器，防止走显示器 DisplayPort 无音量控制或蓝牙耳机截流")
                            
                            Toggle("闹钟关闭后自动恢复先前的音频设备", isOn: $appState.restorePreviousDevice)
                                .help("关闭音乐后自动切回触发前的音频输出（如显示器或耳机），无缝衔接日常使用")
                            
                            Divider()
                            
                            Text("已侦测到的输出设备:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(audioEngine.availableDevices) { dev in
                                HStack {
                                    Image(systemName: dev.isBuiltIn ? "hifispeaker.fill" : (dev.supportsVolumeControl ? "headphones" : "display"))
                                        .foregroundColor(dev.supportsVolumeControl ? .green : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dev.name)
                                            .font(.system(size: 12))
                                        Text(dev.isBuiltIn ? "Mac mini 机载硬件 · 支持平滑调音 (首选)" : (dev.supportsVolumeControl ? "支持音量调节" : "DisplayPort/HDMI · 不支持系统调音 (已自动规避)"))
                                            .font(.system(size: 10))
                                            .foregroundColor(dev.isBuiltIn ? .green : (dev.supportsVolumeControl ? .secondary : .orange))
                                    }
                                    
                                    Spacer()
                                    
                                    if dev.isBuiltIn {
                                        Text("推荐")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.12))
                                            .cornerRadius(3)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 3. 唤醒时间与日程
                    GroupBox(label: Label("定时与日程", systemImage: "alarm.fill")) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("响铃时间")
                                Spacer()
                                HStack(spacing: 4) {
                                    Picker("", selection: $appState.alarmHour) {
                                        ForEach(0..<24) { h in
                                            Text(String(format: "%02d", h)).tag(h)
                                        }
                                    }
                                    .frame(width: 65)
                                    
                                    Text(":")
                                        .fontWeight(.bold)
                                    
                                    Picker("", selection: $appState.alarmMinute) {
                                        ForEach(0..<60) { m in
                                            Text(String(format: "%02d", m)).tag(m)
                                        }
                                    }
                                    .frame(width: 65)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("重复频率")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { appState.repeatSchedule },
                                    set: { appState.repeatSchedule = $0 }
                                )) {
                                    ForEach(RepeatSchedule.allCases) { item in
                                        Text(item.rawValue).tag(item)
                                    }
                                }
                                .frame(width: 160)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 4. 音频淡入曲线与音量（默认 20% -> 90% 2 分钟）
                    GroupBox(label: Label("听觉渐变与音量", systemImage: "speaker.wave.3.fill")) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("起始音量")
                                Spacer()
                                Text("\(Int(appState.startVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { appState.startVolume },
                                    set: {
                                        appState.startVolume = $0
                                        if appState.startVolume >= appState.targetVolume {
                                            appState.targetVolume = min(1.0, appState.startVolume + 0.1)
                                        }
                                    }
                                ),
                                in: 0.05...0.6,
                                step: 0.05
                            )
                            
                            HStack {
                                Text("最终唤醒音量")
                                Spacer()
                                Text("\(Int(appState.targetVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { appState.targetVolume },
                                    set: {
                                        appState.targetVolume = $0
                                        if appState.targetVolume <= appState.startVolume {
                                            appState.startVolume = max(0.05, appState.targetVolume - 0.1)
                                        }
                                    }
                                ),
                                in: 0.3...1.0,
                                step: 0.05
                            )
                            
                            HStack {
                                Text("渐变时长")
                                Spacer()
                                Text(appState.fadeDuration >= 60 ? "\(Int(appState.fadeDuration)) 秒 (\(String(format: "%.1f", appState.fadeDuration / 60.0)) 分钟)" : "\(Int(appState.fadeDuration)) 秒")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $appState.fadeDuration, in: 10...300, step: 5)
                            
                            Divider()
                            
                            HStack {
                                Text("升音曲线")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { appState.fadeCurve },
                                    set: { appState.fadeCurve = $0 }
                                )) {
                                    ForEach(FadeCurve.allCases) { curve in
                                        Text(curve.rawValue).tag(curve)
                                    }
                                }
                                .frame(width: 160)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 5. 系统开机项与兜底
                    GroupBox(label: Label("系统行为与安全兜底", systemImage: "shield.lefthalf.filled")) {
                        VStack(spacing: 10) {
                            Toggle("开机自动启动 (SMAppService)", isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { appState.setLaunchAtLogin($0) }
                            ))
                            .help("开机登录后自动常驻菜单栏")
                            
                            Divider()
                            
                            Toggle("应用启动失败时自动切换离线备用音", isOn: $appState.fallbackSoundEnabled)
                                .help("避免断网或客户端卡死导致未响铃")
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 460, height: 600)
    }
}
