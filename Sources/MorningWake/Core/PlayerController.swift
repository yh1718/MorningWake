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
    private let appleScriptQueue = DispatchQueue(label: "com.morningwake.applescript", qos: .userInitiated)
    public private(set) var currentSoftwareVolume: Float = 1.0
    
    private init() {}
    
    // MARK: - Launch & Play Trigger
    
    public func startPlayback(
        target: PlayerTarget = .youtubeMusic,
        customAudioPath: String? = nil,
        forceFallbackIfFailed: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.isPlaying = true
        self.activePlayerName = target.rawValue
        
        switch target {
        case .youtubeMusic:
            launchYouTubeMusic(forceFallback: forceFallbackIfFailed) { [weak self] success in
                guard let self = self else { return }
                guard self.isPlaying else { return }
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
                guard self.isPlaying else { return }
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
    
    private func launchYouTubeMusic(forceFallback: Bool = true, completion: @escaping (Bool) -> Void) {
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
        
        // 核心阶梯 1：若已在后台运行，立即并发下发第一道原生 play 协议
        if isAlreadyRunning {
            sendYouTubeMusicProtocolCommand("play", appURL: validURL)
        }
        
        // 核心阶梯 2：通过 openApplication 触发系统级 reopen 事件解除后台节流
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false // 避免破坏性抢占焦点
        var launchEnv = ProcessInfo.processInfo.environment
        launchEnv.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        config.environment = launchEnv
        
        workspace.openApplication(at: validURL, configuration: config) { [weak self] runningApp, error in
            DispatchQueue.main.async {
                guard let self = self, error == nil, self.isPlaying else {
                    completion(false)
                    return
                }
                
                let triggerDelay: TimeInterval = isAlreadyRunning ? 0.6 : 2.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    // 核心阶梯 3：仅在音频流尚未激活时下发第二道幂等 play 协议，避免媒体键 Toggle 误暂停
                    if !AudioEngine.shared.isAudioOutputActive() {
                        self.sendYouTubeMusicProtocolCommand("play", appURL: validURL)
                    }
                }
                
                // 核心阶梯 4：再延时 1.0 秒检测音频流，未就绪则执行最后一次幂等播放加固
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay + 1.0)) { [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    if !AudioEngine.shared.isAudioOutputActive() {
                        self.sendYouTubeMusicProtocolCommand("play", appURL: validURL)
                    }
                }
                
                // 核心阶梯 6：音频输出流主动自愈看门狗 (Watchdog)
                // 若拉起 3.5 秒后系统仍未检测到音频输出流（例如网络断开、曲目空载或未能响应），自动无缝切入离线和弦音兜底！
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    if !AudioEngine.shared.isAudioOutputActive() {
                        if forceFallback {
                            print("[PlayerController] ⚠️ 警告：YouTube Music 唤醒 3.5 秒后未检测到音频流输出，自动无缝启动离线和弦音兜底！")
                            self.playFallbackAudio()
                        } else {
                            print("[PlayerController] ⚠️ 提示：YouTube Music 未检测到音频输出流，用户未启用备用音兜底")
                        }
                    } else {
                        print("[PlayerController] ✅ YouTube Music 播放成功，已侦测到活跃音频流！")
                    }
                }
                
                completion(true)
            }
        }
    }
    
    /// 向 YouTube Music 下发原生协议指令（如 "play", "pause", "next", "previous"）
    /// 采用多通道穿透：
    /// 1. 通过 Process 执行二进制命令行参数传递，直接触发 Electron 的 app.on("second-instance")，下发 songControls[cmd]()
    /// 2. 同时使用 LaunchServices NSWorkspace.open(URL) 触发系统级协议路由
    public func sendYouTubeMusicProtocolCommand(_ command: String, appURL: URL? = nil) {
        let uriString = "youtubemusic://\(command)"
        
        let resolvedAppURL = appURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: ytBundleId) ?? URL(fileURLWithPath: "/Applications/YouTube Music.app")
        let bundle = Bundle(url: resolvedAppURL)
        let execName = bundle?.infoDictionary?["CFBundleExecutable"] as? String ?? "YouTube Music"
        let execURL = resolvedAppURL.appendingPathComponent("Contents/MacOS/\(execName)")
        
        // 通道 1：定位二进制，通过 Process 命令行传递直接命中 Electron second-instance
        if FileManager.default.fileExists(atPath: execURL.path) {
            DispatchQueue.global(qos: .userInteractive).async {
                let proc = Process()
                proc.executableURL = execURL
                var env = ProcessInfo.processInfo.environment
                env.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
                proc.environment = env
                proc.arguments = [uriString]
                try? proc.run()
                proc.waitUntilExit()
            }
        }
        
        // 通道 2：通过 LaunchServices 打开 URL Scheme
        if let url = URL(string: uriString) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            if FileManager.default.fileExists(atPath: resolvedAppURL.path) {
                NSWorkspace.shared.open([url], withApplicationAt: resolvedAppURL, configuration: config, completionHandler: nil)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func launchAppleMusic(completion: @escaping (Bool) -> Void) {
        let script = "tell application \"Music\" to play"
        appleScriptQueue.async {
            var error: NSDictionary?
            let success = NSAppleScript(source: script)?.executeAndReturnError(&error) != nil && error == nil
            DispatchQueue.main.async {
                completion(success)
            }
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
    
    // MARK: - Software Volume Fade Support
    
    public func setSoftwareVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        self.currentSoftwareVolume = clamped
        fallbackAudioPlayer?.volume = clamped
        customAudioPlayer?.volume = clamped
        
        // 若当前是 Apple Music，通过后台队列执行 AppleScript 调节音量 (0~100)，避免阻塞主线程
        if activePlayerName == "Apple Music" {
            let appleMusicVol = Int(clamped * 100)
            let script = "if application \"Music\" is running then tell application \"Music\" to set sound volume to \(appleMusicVol)"
            appleScriptQueue.async {
                var err: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&err)
            }
        }
    }
    
    // MARK: - Fallback Audio
    
    public func playFallbackAudio(initialVolume: Float? = nil) {
        stopFallbackAudio()
        if let initVol = initialVolume {
            self.currentSoftwareVolume = max(0.0, min(1.0, initVol))
        }
        
        if let soundURL = Bundle.module.url(forResource: "fallback_alarm", withExtension: "wav") {
            do {
                fallbackAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                fallbackAudioPlayer?.numberOfLoops = -1
                fallbackAudioPlayer?.volume = currentSoftwareVolume
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
    
    public func playCustomAudio(filePath: String, initialVolume: Float? = nil) -> Bool {
        stopFallbackAudio()
        stopCustomAudio()
        if let initVol = initialVolume {
            self.currentSoftwareVolume = max(0.0, min(1.0, initVol))
        }
        
        let url = URL(fileURLWithPath: filePath)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = currentSoftwareVolume
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
        self.isPlaying = false
        self.activePlayerName = "已停止"
        
        stopFallbackAudio()
        stopCustomAudio()
        
        switch target {
        case .youtubeMusic:
            // 原生幂等纯暂停协议指令，后台直接注入，不抢占前台焦点且绝不触发媒体键 Toggle 误重播
            sendYouTubeMusicProtocolCommand("pause")
            
        case .appleMusic:
            let script = "if application \"Music\" is running then tell application \"Music\" to pause"
            appleScriptQueue.async {
                var err: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&err)
            }
            
        case .localFile, .fallbackOnly:
            break
        }
    }
}
