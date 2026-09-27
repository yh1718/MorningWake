import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import UserNotifications

public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPreviewPlaying: Bool = false
    @State private var previewPlayer: AVAudioPlayer? = nil
    @StateObject private var previewDelegate = AudioPreviewDelegate()
    @State private var notificationStatus: String = "检测中..."
    @State private var isNotificationAuthorized: Bool = true
    
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
                    
                    // 3. 唤醒音源与应用
                    GroupBox(label: Label("唤醒音源与应用", systemImage: "music.note.list")) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("播放目标")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { appState.playerTarget },
                                    set: { appState.playerTarget = $0 }
                                )) {
                                    ForEach(PlayerTarget.allCases) { item in
                                        Text(item.rawValue).tag(item)
                                    }
                                }
                                .frame(width: 200)
                            }
                            
                            if appState.playerTarget == .localFile {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(appState.customAudioPath.isEmpty ? "未选择音频文件" : URL(fileURLWithPath: appState.customAudioPath).lastPathComponent)
                                            .font(.system(size: 11))
                                            .foregroundColor(appState.customAudioPath.isEmpty ? .secondary : .primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        
                                        if !appState.customAudioPath.isEmpty {
                                            Button(action: {
                                                toggleAudioPreview()
                                            }) {
                                                Label(isPreviewPlaying ? "停止" : "试听", systemImage: isPreviewPlaying ? "stop.fill" : "play.fill")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.bordered)
                                            
                                            Button("清除") {
                                                stopPreview()
                                                appState.customAudioPath = ""
                                            }
                                            .font(.system(size: 11))
                                            .buttonStyle(.bordered)
                                        }
                                        
                                        Button("选择文件...") {
                                            selectCustomAudioFile()
                                        }
                                        .font(.system(size: 11))
                                    }
                                    Text("支持 MP3, M4A, FLAC, WAV, AAC, AIFF 等常见本地音乐格式")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            } else if appState.playerTarget == .youtubeMusic {
                                Text("将在响铃时优先唤醒 YouTube Music 客户端并发送播放指令")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else if appState.playerTarget == .appleMusic {
                                Text("将在响铃时通过系统 AppleScript 调度自带「音乐」App 播放")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 4. 唤醒时间与日程
                    GroupBox(label: Label("定时与日程", systemImage: "alarm.fill")) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("作息方案")
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { appState.repeatSchedule },
                                    set: { appState.repeatSchedule = $0 }
                                )) {
                                    ForEach(RepeatSchedule.allCases) { item in
                                        Text(item.rawValue).tag(item)
                                    }
                                }
                                .frame(width: 240)
                            }
                            
                            Divider()
                            
                            // 针对智能作息方案的双轨与节假日配置
                            if appState.repeatSchedule == .smartWorkday {
                                VStack(alignment: .leading, spacing: 10) {
                                    // 1. 工作日作息
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text("工作日唤醒时刻")
                                                    .fontWeight(.medium)
                                                Text("💼 工作日")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.blue.opacity(0.12))
                                                    .cornerRadius(3)
                                            }
                                            Text("周一至周五，以及调休补班的周末")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        TimeStepperView(hour: $appState.workdayHour, minute: $appState.workdayMinute, accentColor: .blue)
                                    }
                                    
                                    Divider()
                                    
                                    // 2. 周末与假期作息
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text("周末与节假日作息")
                                                        .fontWeight(.medium)
                                                    Text("🏖️ 慢晨")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.orange)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.orange.opacity(0.12))
                                                        .cornerRadius(3)
                                                }
                                                Text(appState.weekendEnabled ? "周六日及法定假期推迟唤醒，享受慢晨" : "周末与法定假期彻底静音，不打扰休息")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $appState.weekendEnabled)
                                                .toggleStyle(.switch)
                                        }
                                        
                                        if appState.weekendEnabled {
                                            HStack {
                                                Text("慢晨唤醒时刻")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                TimeStepperView(hour: $appState.weekendHour, minute: $appState.weekendMinute, accentColor: .orange)
                                            }
                                            .padding(.leading, 8)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // 3. 中国法定节假日智能调优
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("中国法定节假日与调休智能适配:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        
                                        Toggle("法定节假日自动休假 (按慢晨作息或静音)", isOn: $appState.smartHolidayEnabled)
                                            .font(.system(size: 11))
                                            .help("中秋、国庆、春节等法定假日，自动识别并不按工作日响铃")
                                        
                                        Toggle("调休上班日自动补响 (按工作日时刻唤醒)", isOn: $appState.smartWorkdayEnabled)
                                            .font(.system(size: 11))
                                            .help("因节假日调休需要上班的周六日，自动准时唤醒")
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    
                                    // 4. 今日状态小提示卡片
                                    let todayAttr = HolidayManager.shared.getDayAttribute(for: Date())
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundColor(.orange)
                                        Text("今日日历状态: \(todayAttr.badgeText) · 下次排期: \(appState.nextAlarmDayTitle) \(appState.nextAlarmDate != nil ? String(format: "%02d:%02d", appState.nextAlarmTargetHour, appState.nextAlarmTargetMinute) : "无") (\(appState.nextAlarmBadge))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 4)
                                }
                            } else {
                                // 传统固定响铃时间
                                HStack {
                                    Text("响铃时间")
                                    Spacer()
                                    TimeStepperView(hour: $appState.alarmHour, minute: $appState.alarmMinute, accentColor: .blue)
                                }
                                
                                // 自定义星期多选器
                                if appState.repeatSchedule == .custom {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("自定义响铃星期:")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            let weekDays: [(Int, String)] = [
                                                (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")
                                            ]
                                            ForEach(weekDays, id: \.0) { day, name in
                                                let isSelected = appState.customRepeatDays.contains(day)
                                                Button(action: {
                                                    toggleRepeatDay(day)
                                                }) {
                                                    Text(name)
                                                        .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 4)
                                                        .background(isSelected ? Color.orange : Color(NSColor.controlBackgroundColor))
                                                        .foregroundColor(isSelected ? .white : .primary)
                                                        .cornerRadius(6)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("小睡时长")
                                Spacer()
                                Picker("", selection: $appState.snoozeDurationMinutes) {
                                    Text("5 分钟").tag(5)
                                    Text("10 分钟 (推荐)").tag(10)
                                    Text("15 分钟").tag(15)
                                    Text("20 分钟").tag(20)
                                }
                                .frame(width: 140)
                            }
                        }
                        .padding(8)
                    }
                    
                    // 5. 音频淡入曲线与音量（默认 20% -> 90% 2 分钟）
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
                    
                    // 6. 系统开机项与兜底
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
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("系统通知与锁屏权限")
                                        .font(.system(size: 13))
                                    Text(notificationStatus)
                                        .font(.system(size: 10))
                                        .foregroundColor(isNotificationAuthorized ? .green : .orange)
                                }
                                Spacer()
                                if !isNotificationAuthorized {
                                    Button("去授权") {
                                        openNotificationSettings()
                                    }
                                    .font(.system(size: 11))
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 650)
        .onAppear {
            checkNotificationPermission()
        }
        .onDisappear {
            stopPreview()
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.isNotificationAuthorized = true
                    self.notificationStatus = "已开启 (锁屏交互已就绪)"
                case .denied:
                    self.isNotificationAuthorized = false
                    self.notificationStatus = "未授权 (无法呈现锁屏唤醒卡片)"
                default:
                    self.isNotificationAuthorized = false
                    self.notificationStatus = "未配置"
                }
            }
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func toggleAudioPreview() {
        if isPreviewPlaying {
            stopPreview()
        } else {
            guard !appState.customAudioPath.isEmpty else { return }
            do {
                let url = URL(fileURLWithPath: appState.customAudioPath)
                let player = try AVAudioPlayer(contentsOf: url)
                previewDelegate.onFinish = {
                    DispatchQueue.main.async {
                        self.stopPreview()
                    }
                }
                player.delegate = previewDelegate
                player.prepareToPlay()
                player.play()
                self.previewPlayer = player
                self.isPreviewPlaying = true
            } catch {
                print("[SettingsView] 试听失败: \(error)")
            }
        }
    }
    
    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewPlaying = false
    }
    
    private func toggleRepeatDay(_ day: Int) {
        var days = appState.customRepeatDays
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
        appState.customRepeatDays = days
    }
    
    private func selectCustomAudioFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        var types: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        if let aac = UTType(filenameExtension: "aac") { types.append(aac) }
        if let ogg = UTType(filenameExtension: "ogg") { types.append(ogg) }
        panel.allowedContentTypes = types
        
        if panel.runModal() == .OK, let url = panel.url {
            stopPreview()
            appState.customAudioPath = url.path
        }
    }
}

private final class AudioPreviewDelegate: NSObject, AVAudioPlayerDelegate, ObservableObject {
    var onFinish: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
