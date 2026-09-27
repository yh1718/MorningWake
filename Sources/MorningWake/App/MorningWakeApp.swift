import SwiftUI
import UserNotifications

public final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        AppDelegate.updateNotificationCategory(snoozeMinutes: AppState.shared.snoozeDurationMinutes)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    public static func updateNotificationCategory(snoozeMinutes: Int) {
        guard NSClassFromString("XCTestCase") == nil,
              !(Bundle.main.bundleIdentifier?.contains("xctest") ?? false),
              Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let keepAction = UNNotificationAction(
            identifier: "ACTION_KEEP",
            title: "我已清醒 (保持播放)",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "ACTION_SNOOZE",
            title: "小睡 \(snoozeMinutes) 分钟",
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: "ACTION_STOP",
            title: "完全关闭音乐",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "MORNING_ALARM_CATEGORY",
            actions: [keepAction, snoozeAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([category])
    }
    
    // 监听锁屏或通知中心的操作响应
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case "ACTION_KEEP":
                AppState.shared.keepPlaying()
            case "ACTION_SNOOZE":
                AppState.shared.snooze()
            case "ACTION_STOP":
                AppState.shared.stopAlarm()
            default:
                break
            }
        }
        completionHandler()
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge])
    }
}

@main
struct MorningWakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: appState.isAlarmEnabled ? "sun.horizon.fill" : "sun.horizon")
                if appState.isAlarmRinging || appState.isTestRunning {
                    Text("\(appState.currentVolumePercent)%")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
