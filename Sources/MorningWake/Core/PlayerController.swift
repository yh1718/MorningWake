import Foundation
import AppKit
import AVFoundation

public enum PlayerTarget: String, CaseIterable, Identifiable {
    case youtubeMusic = "YouTube Music"
    case appleMusic = "Apple Music (系统自带)"
    case localFile = "自定义本地音频文件"
    case fallbackOnly = "内置自然和弦唤醒声"
    
    public var id: String { rawValue }
}

public final class PlayerController: ObservableObject {
    public static let shared = PlayerController()
    
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var activePlayerName: String = "未播放"
    
    private var fallbackAudioPlayer: AVAudioPlayer?
    private var customAudioPlayer: AVAudioPlayer?
    private let ytBundleId = "com.github.th-ch.youtube-music"
    
    private init() {}
    
    // MARK: - Launch & Play Trigger
    
    public func startPlayback(
        target: PlayerTarget = .youtubeMusic,
        customAudioPath: String? = nil,
        forceFallbackIfFailed: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        switch target {
        case .youtubeMusic:
            launchYouTubeMusic { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.isPlaying = true
                    self.activePlayerName = "YouTube Music"
                    completion?(true)
                } else if forceFallbackIfFailed {
                    print("[PlayerController] YouTube Music 启动异常，自动切换离线唤醒兜底")
                    self.playFallbackAudio()
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
            
        case .appleMusic:
            launchAppleMusic { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.isPlaying = true
                    self.activePlayerName = "Apple Music"
                    completion?(true)
                } else if forceFallbackIfFailed {
                    self.playFallbackAudio()
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
            
        case .localFile:
            if let path = customAudioPath, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                let success = playCustomAudio(filePath: path)
                if success {
                    completion?(true)
                    return
                }
            }
            if forceFallbackIfFailed {
                print("[PlayerController] 自定义音频加载失败，回退至内置唤醒音")
                playFallbackAudio()
                completion?(true)
            } else {
                completion?(false)
            }
            
        case .fallbackOnly:
            playFallbackAudio()
            completion?(true)
        }
    }
    
    private func launchYouTubeMusic(completion: @escaping (Bool) -> Void) {
        let appPath = "/Applications/YouTube Music.app"
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: appPath)
        
        let ytRunningApps = NSRunningApplication.runningApplications(withBundleIdentifier: ytBundleId)
        let isAlreadyRunning = !ytRunningApps.isEmpty
        
        // 核心：无论后台运行还是冷启动，都使用 openApplication(activates = true)
        // 在 macOS 规范中，对已在后台运行的应用调用 openApplication 会触发系统级 reopen 事件：
        // 1. 自动将最小化至 Dock 的窗口恢复弹出；
        // 2. 自动恢复被关闭(红叉)的主窗口；
        // 3. 将应用置于最前台并激活输入焦点，使 Web 页面 DOM 完全唤醒并就绪响应按键。
        let targetURL: URL? = FileManager.default.fileExists(atPath: appPath) ? appURL : workspace.urlForApplication(withBundleIdentifier: ytBundleId)
        
        guard let validURL = targetURL else {
            completion(false)
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true // 强制激活置顶拉起窗口
        
        workspace.openApplication(at: validURL, configuration: config) { [weak self] runningApp, error in
            DispatchQueue.main.async {
                guard let self = self, error == nil else {
                    completion(false)
                    return
                }
                
                // 确保焦点精准锁定在 YouTube Music 上
                runningApp?.activate(options: .activateIgnoringOtherApps)
                
                // 根据后台运行还是冷启动分配最佳等待延时：
                // - 后台运行：窗口已在内存，给予 0.8 秒让 Dock 恢复动画与 DOM 渲染就绪
                // - 冷启动：给予 2.5 秒 Web 页面与登录态加载缓冲
                let triggerDelay: TimeInterval = isAlreadyRunning ? 0.8 : 2.5
                
                DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                    self?.triggerAutoPlayCommand()
                }
                
                // 4.5 秒后安全检测出声状态：若依旧无音频流输出（列表空/离线），自动无缝切入离线和弦备用音
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay + 3.0)) { [weak self] in
                    guard let self = self else { return }
                    if !AudioEngine.shared.isAudioOutputActive() {
                        print("[PlayerController] YouTube Music 拉起后未检测到音频流输出（可能未就绪/无活跃曲目），启动离线备用音兜底")
                        self.playFallbackAudio()
                    } else {
                        print("[PlayerController] YouTube Music 自动播放成功，音频流正常！")
                    }
                }
                
                completion(true)
            }
        }
    }
    
    /// 触发自动播放指令（硬件媒体键 + 空格键双阶智能补偿，确保无需点击直接播放）
    private func triggerAutoPlayCommand() {
        // 1. 发送系统硬件媒体播放键 (NX_KEYTYPE_PLAY)
        simulatePlayMediaKey()
        
        // 2. 0.4 秒后检查：若系统音频流尚未激活（某些后台场景硬件媒体键未被网页捕获），向当前前台窗口补充发送一次网页通用播放键（空格键 keyCode 49）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !AudioEngine.shared.isAudioOutputActive() {
                print("[PlayerController] 媒体键尚未出声，向当前窗口发送空格键激活播放...")
                let src = CGEventSource(stateID: .hidSystemState)
                if let down = CGEvent(keyboardEventSource: src, virtualKey: 49, keyDown: true),
                   let up = CGEvent(keyboardEventSource: src, virtualKey: 49, keyDown: false) {
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            }
        }
    }
    
    private func launchAppleMusic(completion: @escaping (Bool) -> Void) {
        let script = "tell application \"Music\" to play"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            completion(error == nil)
        } else {
            completion(false)
        }
    }
    
    // MARK: - Simulate Media Key
    
    public func simulatePlayMediaKey() {
        func postKey(key: Int32, down: Bool) {
            let state: Int32 = down ? 0xa00 : 0xb00
            let data1 = (key << 16) | state
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int(data1),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        
        // 16 is NX_KEYTYPE_PLAY
        postKey(key: 16, down: true)
        postKey(key: 16, down: false)
    }
    
    // MARK: - Fallback Audio
    
    public func playFallbackAudio() {
        stopFallbackAudio()
        
        if let soundURL = Bundle.module.url(forResource: "fallback_alarm", withExtension: "wav") {
            do {
                fallbackAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                fallbackAudioPlayer?.numberOfLoops = -1
                fallbackAudioPlayer?.prepareToPlay()
                fallbackAudioPlayer?.play()
                self.isPlaying = true
                self.activePlayerName = "离线备用晨鸣声"
                return
            } catch {
                print("[PlayerController] 无法加载本地音频: \(error)")
            }
        }
        
        NSSound(named: "Glass")?.play()
        self.isPlaying = true
        self.activePlayerName = "系统提示音"
    }
    
    public func stopFallbackAudio() {
        fallbackAudioPlayer?.stop()
        fallbackAudioPlayer = nil
    }
    
    // MARK: - Custom Audio File Playback
    
    public func playCustomAudio(filePath: String) -> Bool {
        stopFallbackAudio()
        stopCustomAudio()
        
        let url = URL(fileURLWithPath: filePath)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            self.customAudioPlayer = player
            self.isPlaying = true
            self.activePlayerName = url.lastPathComponent
            print("[PlayerController] 正在播放自定义音频: \(url.lastPathComponent)")
            return true
        } catch {
            print("[PlayerController] 自定义音频文件播放失败: \(error.localizedDescription)")
            return false
        }
    }
    
    public func stopCustomAudio() {
        customAudioPlayer?.stop()
        customAudioPlayer = nil
    }
    
    // MARK: - Stop Playback
    
    public func stopPlayback(for target: PlayerTarget = .youtubeMusic) {
        stopFallbackAudio()
        stopCustomAudio()
        
        switch target {
        case .youtubeMusic:
            let ytRunningApps = NSRunningApplication.runningApplications(withBundleIdentifier: ytBundleId)
            if let app = ytRunningApps.first {
                app.activate(options: .activateIgnoringOtherApps)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.simulatePlayMediaKey()
                }
            } else {
                simulatePlayMediaKey()
            }
            
        case .appleMusic:
            let script = "if application \"Music\" is running then tell application \"Music\" to pause"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            
        case .localFile, .fallbackOnly:
            break
        }
        
        isPlaying = false
        activePlayerName = "已停止"
    }
}
