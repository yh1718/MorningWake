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
        
        let targetURL: URL? = FileManager.default.fileExists(atPath: appPath) ? appURL : workspace.urlForApplication(withBundleIdentifier: ytBundleId)
        
        guard let validURL = targetURL else {
            completion(false)
            return
        }
        
        // 核心阶梯 1：若已在后台运行（包括最小化至 Dock、隐藏或红叉关闭窗口），立即并发下发第一道原生 play 协议
        // 通过第二实例 IPC 直接注入应用底层，直接触发应用内置的 $9.playVideo()，无需前台焦点
        if isAlreadyRunning {
            sendYouTubeMusicProtocolCommand("play", appURL: validURL)
        }
        
        // 核心阶梯 2：通过 openApplication 触发系统级 reopen 事件
        // 恢复最小化窗口，解除 Chromium 内核对后台页面的渲染与音频节流 (Unthrottle)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        workspace.openApplication(at: validURL, configuration: config) { [weak self] runningApp, error in
            DispatchQueue.main.async {
                guard let self = self, error == nil else {
                    completion(false)
                    return
                }
                
                // 确保窗口解除隐藏并置顶
                runningApp?.unhide()
                if #available(macOS 14.0, *) {
                    runningApp?.activate()
                } else {
                    runningApp?.activate(options: .activateIgnoringOtherApps)
                }
                
                // 根据后台运行还是冷启动分配最佳等待延时：
                // - 后台运行：窗口已在内存，给予 0.6 秒让 Dock 恢复动画与 DOM 渲染就绪
                // - 冷启动：给予 2.0 秒 Web 页面与登录态加载缓冲
                let triggerDelay: TimeInterval = isAlreadyRunning ? 0.6 : 2.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                    guard let self = self else { return }
                    // 核心阶梯 3：窗口就绪后，下发第二道幂等 play 协议（绝对防误暂停）
                    self.sendYouTubeMusicProtocolCommand("play", appURL: validURL)
                    
                    // 核心阶梯 4：辅以系统全局媒体键保底，兼顾非 th-ch 版本客户端
                    self.simulatePlayMediaKey()
                }
                
                // 核心阶梯 5：再延时 1.0 秒执行最后一次幂等播放加固
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay + 1.0)) { [weak self] in
                    self?.sendYouTubeMusicProtocolCommand("play", appURL: validURL)
                }
                
                // 4.5 秒后安全检测出声与存活状态：若应用异常崩溃退出，自动无缝切入离线和弦备用音
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay + 2.5)) { [weak self] in
                    guard let self = self else { return }
                    let currentYtApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.ytBundleId)
                    if currentYtApps.isEmpty {
                        print("[PlayerController] YouTube Music 异常退出，立即切入离线备用音")
                        self.playFallbackAudio()
                    } else if !AudioEngine.shared.isAudioOutputActive() {
                        print("[PlayerController] 未检测到活跃音频流输出，启动离线备用音兜底")
                        self.playFallbackAudio()
                    } else {
                        print("[PlayerController] YouTube Music 播放链路闭环完成，音频流正常！")
                    }
                }
                
                completion(true)
            }
        }
    }
    
    /// 向 YouTube Music 下发原生协议指令（如 "play", "pause", "next", "previous"）
    /// 采用多通道穿透技术：
    /// 1. 通过后台 Process 启动 CLI 参数传递，直接命中 Electron 的 app.on("second-instance")，直接触发 $9.playVideo()
    /// 2. 同时使用 NSWorkspace.shared.open(URL) 触发系统协议路由
    public func sendYouTubeMusicProtocolCommand(_ command: String, appURL: URL? = nil) {
        let uriString = "youtubemusic://\(command)"
        
        // 通道 1：通过 NSWorkspace 打开协议
        if let url = URL(string: uriString) {
            NSWorkspace.shared.open(url)
        }
        
        // 通道 2：定位 YouTube Music 二进制可执行文件，通过后台进程直接投递命令行参数
        let resolvedAppURL = appURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: ytBundleId) ?? URL(fileURLWithPath: "/Applications/YouTube Music.app")
        let bundle = Bundle(url: resolvedAppURL)
        let execName = bundle?.infoDictionary?["CFBundleExecutable"] as? String ?? "YouTube Music"
        let execURL = resolvedAppURL.appendingPathComponent("Contents/MacOS/\(execName)")
        
        if FileManager.default.fileExists(atPath: execURL.path) {
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = execURL
                proc.arguments = [uriString]
                try? proc.run()
                proc.waitUntilExit()
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
            // 优先下发原生幂等纯暂停协议指令（绝不会像空格键或 Toggle 媒体键那样反向误开播放）
            sendYouTubeMusicProtocolCommand("pause")
            
            let ytRunningApps = NSRunningApplication.runningApplications(withBundleIdentifier: ytBundleId)
            if let app = ytRunningApps.first {
                if #available(macOS 14.0, *) {
                    app.activate()
                } else {
                    app.activate(options: .activateIgnoringOtherApps)
                }
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
