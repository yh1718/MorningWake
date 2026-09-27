import Foundation
import IOKit.pwr_mgt

public final class PowerManager {
    public static let shared = PowerManager()
    
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion: Bool = false
    private var hasDisplayAssertion: Bool = false
    private var currentScheduledWakeDate: Date?
    
    private init() {}
    
    // MARK: - Schedule Power Wake Event (硬件休眠定时唤醒)
    
    @discardableResult
    public func scheduleWake(at date: Date) -> Bool {
        // 先取消上一次已经排期的硬件唤醒，避免旧事件残留
        if let existing = currentScheduledWakeDate {
            cancelWake(at: existing)
        }
        
        let timeUntilWake = date.timeIntervalSinceNow
        // 若目标时间距离当前不足 70 秒，系统已处于工作状态，跳过提前 60 秒的休眠唤醒事件
        guard timeUntilWake >= 70.0 else {
            print("[PowerManager] 距离响铃仅 \(Int(timeUntilWake)) 秒，当前系统已处于活跃运行状态，跳过休眠预热注册")
            self.currentScheduledWakeDate = nil
            return true
        }
        
        // Mac mini 交流供电模式下，在设定时间提前 60 秒硬件预热
        let wakeDate = date.addingTimeInterval(-60.0) as CFDate
        let name = "com.morningwake.alarm" as CFString
        let eventType = kIOPMAutoWake as CFString
        
        let status = IOPMSchedulePowerEvent(wakeDate, name, eventType)
        if status == kIOReturnSuccess {
            self.currentScheduledWakeDate = date
            print("[PowerManager] 成功注册 Mac mini 硬件级休眠定时唤醒: \(date)")
            return true
        } else {
            print("[PowerManager] 注册唤醒事件状态码: \(status)")
            return false
        }
    }
    
    public func cancelWake(at date: Date) {
        let wakeDate = date.addingTimeInterval(-60.0) as CFDate
        let name = "com.morningwake.alarm" as CFString
        let eventType = kIOPMAutoWake as CFString
        IOPMCancelScheduledPowerEvent(wakeDate, name, eventType)
        if currentScheduledWakeDate == date {
            currentScheduledWakeDate = nil
        }
    }
    
    public func cancelCurrentWake() {
        if let current = currentScheduledWakeDate {
            cancelWake(at: current)
        }
    }
    
    // MARK: - Wake Display & Prevent Sleep (点亮显示器与防休眠)
    
    public func wakeDisplayAndPreventSleep() {
        // 1. 模拟用户活动事件，立刻唤醒黑屏/睡眠中的 Mac mini 外接显示器 (DisplayPort / HDMI)
        var userActivityID: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity(
            "MorningWake.WakeDisplay" as CFString,
            kIOPMUserActiveLocal,
            &userActivityID
        )
        
        // 2. 阻止系统进入空闲睡眠
        if !hasSystemAssertion {
            let reason = "MorningWake 晨间唤醒：音乐播放与音量渐变中" as CFString
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &systemAssertionID
            )
            hasSystemAssertion = (status == kIOReturnSuccess)
        }
        
        // 3. 阻止显示器休眠灭屏（保持屏幕点亮，展示卡片与自然光照）
        if !hasDisplayAssertion {
            let reason = "MorningWake 晨间唤醒：屏幕点亮以展示唤醒通知" as CFString
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
            hasDisplayAssertion = (status == kIOReturnSuccess)
        }
    }
    
    public func allowSleep() {
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
        }
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
        }
    }
}
