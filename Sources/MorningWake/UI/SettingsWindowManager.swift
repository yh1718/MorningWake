import AppKit
import SwiftUI

public final class SettingsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showSettings() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = SettingsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // 智能定位：避开右上角菜单栏浮窗 (预留 380px 浮窗空间)，防止窗口与菜单栏浮窗相互重叠压盖
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let freeWidth = vf.width - 480 - 380
            let xPos: CGFloat = freeWidth > 0 ? (vf.minX + freeWidth * 0.45) : (vf.minX + 30)
            let yPos: CGFloat = vf.minY + max(20, (vf.height - 640) / 2)
            newWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        } else {
            newWindow.center()
        }
        
        newWindow.title = "MorningWake 偏好设置"
        newWindow.contentViewController = hostingController
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
