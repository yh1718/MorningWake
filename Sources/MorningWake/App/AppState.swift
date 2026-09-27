import Foundation
import SwiftUI
import Combine
import UserNotifications
import ServiceManagement
import CoreAudio

public enum RepeatSchedule: String, CaseIterable, Identifiable {
    case everyday = "每天"
    case weekdays = "仅工作日 (周一至周五)"
    case weekends = "仅周末"
    case custom = "自定义星期"
    
    public var id: String { rawValue }
}

public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // MARK: - Persisted Settings
    
    @AppStorage("isAlarmEnabled") public var isAlarmEnabled: Bool = true {
        didSet { reschedule() }
    }
    
    @AppStorage("alarmHour") public var alarmHour: Int = 7 {
        didSet { reschedule() }
    }
    
    @AppStorage("alarmMinute") public var alarmMinute: Int = 35 {
        didSet { reschedule() }
    }
    
    @AppStorage("repeatScheduleRaw") private var repeatScheduleRaw: String = RepeatSchedule.everyday.rawValue {
        didSet { reschedule() }
    }
    
    public var repeatSchedule: RepeatSchedule {
        get { RepeatSchedule(rawValue: repeatScheduleRaw) ?? .everyday }
        set { repeatScheduleRaw = newValue.rawValue }
    }
    
    // 存储自定义选中的星期集合（1: 周日, 2: 周一 ... 7: 周六）
    @AppStorage("customRepeatDaysRaw") public var customRepeatDaysRaw: String = "2,3,4,5,6" {
        didSet { reschedule() }
    }
    
    public var customRepeatDays: Set<Int> {
        get {
            let parts = customRepeatDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return Set(parts)
        }
        set {
            customRepeatDaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
            reschedule()
        }
    }
    
    public var repeatScheduleSummary: String {
        switch repeatSchedule {
        case .everyday:
            return "每天"
        case .weekdays:
            return "仅工作日 (周一至五)"
        case .weekends:
            return "仅周末 (周六日)"
        case .custom:
            let days = customRepeatDays
            if days.count == 7 { return "每天" }
            if days.isEmpty { return "未选日期" }
            let nameMap: [Int: String] = [2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六", 1: "日"]
            let sorted = [2, 3, 4, 5, 6, 7, 1].filter { days.contains($0) }
            return "周" + sorted.compactMap { nameMap[$0] }.joined(separator: "、")
        }
    }
    
    @AppStorage("startVolume") public var startVolume: Double = 0.2
    @AppStorage("targetVolume") public var targetVolume: Double = 0.9
    @AppStorage("fadeDuration") public var fadeDuration: Double = 120.0
    
    @AppStorage("fadeCurveRaw") private var fadeCurveRaw: String = FadeCurve.smoothStep.rawValue
    public var fadeCurve: FadeCurve {
        get { FadeCurve(rawValue: fadeCurveRaw) ?? .smoothStep }
        set { fadeCurveRaw = newValue.rawValue }
    }
    
    @AppStorage("playerTargetRaw") private var playerTargetRaw: String = PlayerTarget.youtubeMusic.rawValue
    public var playerTarget: PlayerTarget {
        get { PlayerTarget(rawValue: playerTargetRaw) ?? .youtubeMusic }
        set { playerTargetRaw = newValue.rawValue }
    }
    
    @AppStorage("customAudioPath") public var customAudioPath: String = ""
    @AppStorage("snoozeDurationMinutes") public var snoozeDurationMinutes: Int = 10 {
        didSet {
            AppDelegate.updateNotificationCategory(snoozeMinutes: snoozeDurationMinutes)
        }
    }
    
    @AppStorage("forceBuiltInSpeaker") public var forceBuiltInSpeaker: Bool = true
    @AppStorage("fallbackSoundEnabled") public var fallbackSoundEnabled: Bool = true
    @AppStorage("restorePreviousDevice") public var restorePreviousDevice: Bool = true
    
    // 记录跳过当天的 UNIX 时间戳
    @AppStorage("skippedDayTimestamp") private var skippedDayTimestamp: Double = 0.0
    
    // MARK: - Runtime States
    
    @Published public var isAlarmRinging: Bool = false
    @Published public var isTestRunning: Bool = false
    @Published public var isSnoozing: Bool = false
    @Published public var isManualVolumeOverridden: Bool = false
    @Published public var nextAlarmDate: Date?
    @Published public var countdownString: String = "计算中..."
    @Published public var currentVolumePercent: Int = 0
    @Published public var launchAtLogin: Bool = false
    
    private var previousAudioDeviceID: AudioDeviceID?
    
    public var isSkippedToday: Bool {
        guard skippedDayTimestamp > 0 else { return false }
        let skippedDate = Date(timeIntervalSince1970: skippedDayTimestamp)
        return Calendar.current.isDateInToday(skippedDate)
    }
    
    private var schedulerTimer: Timer?
    private var countdownTimer: Timer?
    private var autoStopTimer: Timer?
    private var originalVolumeBeforeTest: Float = 0.5
    
    private init() {
        setupTimers()
        updateLaunchAtLoginStatus()
        reschedule()
    }
    
    // MARK: - Launch at Login (macOS 13+)
    
    public func updateLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    public func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            } catch {
                print("[AppState] 开机启动项设置失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Scheduling Logic
    
    public func reschedule() {
        objectWillChange.send()
        
        guard isAlarmEnabled else {
            nextAlarmDate = nil
            countdownString = "已暂停"
            isSnoozing = false
            PowerManager.shared.cancelCurrentWake()
            return
        }
        
        // 如果处于小睡中，不重新覆盖小睡排期
        if isSnoozing, let snoozeDate = nextAlarmDate, snoozeDate > Date() {
            updateCountdown()
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = alarmHour
        targetComponents.minute = alarmMinute
        targetComponents.second = 0
        
        guard var candidateDate = calendar.date(from: targetComponents) else { return }
        
        if candidateDate <= now || isSkippedToday {
            candidateDate = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
        }
        
        var loopCount = 0
        while !matchesSchedule(candidateDate) && loopCount < 14 {
            candidateDate = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
            loopCount += 1
        }
        
        if loopCount >= 14 {
            // 用户自定义星期未勾选任何日期
            self.nextAlarmDate = nil
            self.countdownString = "未勾选响铃日期"
            PowerManager.shared.cancelCurrentWake()
            return
        }
        
        self.nextAlarmDate = candidateDate
        self.isSnoozing = false
        PowerManager.shared.scheduleWake(at: candidateDate)
        updateCountdown()
    }
    
    private func matchesSchedule(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch repeatSchedule {
        case .everyday:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6
        case .weekends:
            return weekday == 1 || weekday == 7
        case .custom:
            return customRepeatDays.contains(weekday)
        }
    }
    
    private func setupTimers() {
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAlarmTrigger()
        }
        RunLoop.main.add(schedulerTimer!, forMode: .common)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    private func updateCountdown() {
        guard isAlarmEnabled, let next = nextAlarmDate else {
            countdownString = isAlarmEnabled ? "未安排" : "已关闭"
            return
        }
        
        let diff = next.timeIntervalSince(Date())
        if diff <= 0 {
            countdownString = isSnoozing ? "小睡即将结束..." : "即将响铃..."
            return
        }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        let prefix = isSnoozing ? "小睡中 · " : ""
        if hours > 0 {
            countdownString = "\(prefix)\(hours)小时\(minutes)分后"
        } else if minutes > 0 {
            countdownString = "\(prefix)\(minutes)分\(seconds)秒后"
        } else {
            countdownString = "\(prefix)\(seconds)秒后"
        }
    }
    
    private func checkAlarmTrigger() {
        guard isAlarmEnabled, !isAlarmRinging, !isTestRunning, let next = nextAlarmDate else { return }
        
        let now = Date()
        let diff = now.timeIntervalSince(next)
        
        if diff >= 0 && diff < 900 {
            triggerMorningAlarm()
        } else if diff >= 900 {
            print("[AppState] 开机时间错过闹钟超过 15 分钟，自动推进至下次排期")
            isSnoozing = false
            reschedule()
        }
    }
    
    // MARK: - Alarm Execution
    
    public func triggerMorningAlarm() {
        isAlarmRinging = true
        isSnoozing = false
        isManualVolumeOverridden = false
        skippedDayTimestamp = 0.0
        
        // 记录触发前的原音频输出设备（以便关闭后能无缝恢复至显示器或耳机）
        self.previousAudioDeviceID = AudioEngine.shared.getDefaultOutputDeviceID()
        
        // 点亮外接显示器并保持防休眠
        PowerManager.shared.wakeDisplayAndPreventSleep()
        
        if forceBuiltInSpeaker {
            AudioEngine.shared.switchToBuiltInSpeaker()
        }
        
        PlayerController.shared.startPlayback(
            target: playerTarget,
            customAudioPath: customAudioPath,
            forceFallbackIfFailed: fallbackSoundEnabled
        )
        
        AudioEngine.shared.startFade(
            from: Float(startVolume),
            to: Float(targetVolume),
            duration: fadeDuration,
            curve: fadeCurve,
            onProgress: { [weak self] vol in
                DispatchQueue.main.async {
                    self?.currentVolumePercent = Int(vol * 100)
                }
            },
            onIntervention: { [weak self] in
                DispatchQueue.main.async {
                    self?.isManualVolumeOverridden = true
                    print("[AppState] 用户物理/手动接管音量，保持当前音量播音")
                }
            },
            onComplete: {
                print("[AppState] 晨间音量淡入完成！")
            }
        )
        
        sendInteractiveWakeNotification()
        
        // 30分钟安全熔断保护
        autoStopTimer?.invalidate()
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 1800.0, repeats: false) { [weak self] _ in
            print("[AppState] 闹钟触发 30 分钟无应答，安全熔断自动释放")
            self?.stopAlarm()
        }
        
        reschedule()
    }
    
    private var isNotificationSupportedEnvironment: Bool {
        NSClassFromString("XCTestCase") == nil &&
        !(Bundle.main.bundleIdentifier?.contains("xctest") ?? false) &&
        Bundle.main.bundleIdentifier != nil
    }
    
    public func keepPlaying() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        isAlarmRinging = false
        isSnoozing = false
        isManualVolumeOverridden = false
        AudioEngine.shared.stopFade()
        PowerManager.shared.allowSleep()
        if isNotificationSupportedEnvironment {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["morningwake.ringing"])
        }
        reschedule()
    }
    
    public func stopAlarm() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        isAlarmRinging = false
        isSnoozing = false
        isManualVolumeOverridden = false
        AudioEngine.shared.stopFade()
        PlayerController.shared.stopPlayback(for: playerTarget)
        PowerManager.shared.allowSleep()
        if isNotificationSupportedEnvironment {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["morningwake.ringing"])
        }
        
        // 恢复触发前的原始音频设备（例如切回显示器或耳机）
        if restorePreviousDevice, let originalID = previousAudioDeviceID {
            print("[AppState] 闹钟停止，恢复原有音频输出设备: \(originalID)")
            AudioEngine.shared.setDefaultOutputDevice(id: originalID)
            self.previousAudioDeviceID = nil
        }
        
        reschedule()
    }
    
    public func snooze(minutes: Int? = nil) {
        let actualMinutes = minutes ?? snoozeDurationMinutes
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        AudioEngine.shared.stopFade()
        PlayerController.shared.stopPlayback(for: playerTarget)
        isAlarmRinging = false
        isManualVolumeOverridden = false
        PowerManager.shared.allowSleep()
        if isNotificationSupportedEnvironment {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["morningwake.ringing"])
        }
        
        let snoozeDate = Date().addingTimeInterval(TimeInterval(actualMinutes * 60))
        self.nextAlarmDate = snoozeDate
        self.isSnoozing = true
        self.isAlarmEnabled = true
        PowerManager.shared.scheduleWake(at: snoozeDate)
        updateCountdown()
    }
    
    public func cancelSnooze() {
        guard isSnoozing else { return }
        isSnoozing = false
        PowerManager.shared.cancelCurrentWake()
        reschedule()
    }
    
    public func toggleSkipToday() {
        if isSkippedToday {
            skippedDayTimestamp = 0.0
        } else {
            skippedDayTimestamp = Date().timeIntervalSince1970
        }
        objectWillChange.send()
        reschedule()
    }
    
    // MARK: - Test Run (试跑功能)
    
    public func startTestRun() {
        guard !isTestRunning && !isAlarmRinging else { return }
        isTestRunning = true
        isManualVolumeOverridden = false
        originalVolumeBeforeTest = AudioEngine.shared.getVolume()
        
        if forceBuiltInSpeaker {
            AudioEngine.shared.switchToBuiltInSpeaker()
        }
        
        PlayerController.shared.startPlayback(
            target: playerTarget,
            customAudioPath: customAudioPath,
            forceFallbackIfFailed: true
        )
        
        AudioEngine.shared.startFade(
            from: Float(startVolume),
            to: Float(targetVolume),
            duration: 6.0,
            curve: fadeCurve,
            onProgress: { [weak self] vol in
                DispatchQueue.main.async {
                    self?.currentVolumePercent = Int(vol * 100)
                }
            },
            onIntervention: { [weak self] in
                DispatchQueue.main.async {
                    self?.isManualVolumeOverridden = true
                }
            },
            onComplete: { [weak self] in
                print("[AppState] 试跑淡入完成，2秒后自动复位...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.stopTestRun()
                }
            }
        )
    }
    
    public func stopTestRun() {
        guard isTestRunning else { return }
        isTestRunning = false
        isManualVolumeOverridden = false
        AudioEngine.shared.stopFade()
        PlayerController.shared.stopPlayback(for: playerTarget)
        AudioEngine.shared.setVolume(originalVolumeBeforeTest)
    }
    
    // MARK: - Interactive Notification
    
    private func sendInteractiveWakeNotification() {
        guard isNotificationSupportedEnvironment else { return }
        let content = UNMutableNotificationContent()
        content.title = "早安！晨间音乐已开启 🎵"
        content.body = "正在为您平滑淡入，轻点操作卡片选择清醒或小睡 \(snoozeDurationMinutes) 分钟。"
        content.categoryIdentifier = "MORNING_ALARM_CATEGORY"
        
        let request = UNNotificationRequest(
            identifier: "morningwake.ringing",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
