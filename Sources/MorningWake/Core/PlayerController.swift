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
        let ytRunningApps = NSRunningApplication.runningApplications(withBundleIdentifier: ytBundleId)
        
        // 场景 A：YouTube Music 已处于打开运行状态 (针对用户提问的实际场景)
        if let existingApp = ytRunningApps.first {
            print("[PlayerController] 检测到 YouTube Music 处于打开运行状态 (PID: \(existingApp.processIdentifier))，激活焦点并启动播放...")
            
            // 激活应用，确保音频与媒体按键焦点准确落在 YouTube Music 身上，防止被前台其他应用截获
            existingApp.activate(options: .activateIgnoringOtherApps)
            
            // 给予 0.4 秒焦点就绪微延迟，发送【单次】播放指令（绝不发送第 2 次 Toggle 避免误暂停）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.simulatePlayMediaKey()
            }
            
            // 延迟 4.0 秒进行出声与音频流输出检测：如果未发出声音（如列表空或断网），自动无缝切入离线备用音
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self else { return }
                let isActive = AudioEngine.shared.isAudioOutputActive()
                if !isActive {
                    print("[PlayerController] YouTube Music 打开但未检测到音频流输出（可能未就绪/无活跃曲目），启动离线备用音")
                    self.playFallbackAudio()
                } else {
                    print("[PlayerController] YouTube Music 音频流输出正常！")
                }
            }
            
            completion(true)
            return
        }
        
        // 场景 B：YouTube Music 未运行（冷启动）
        let appPath = "/Applications/YouTube Music.app"
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: appPath)
        
        let handleColdLaunchSuccess: () -> Void = { [weak self] in
            // 冷启动给予 2.5 秒 Web 页面渲染与音频上下文初始化缓冲，发送单次播放按键
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self?.simulatePlayMediaKey()
            }
            // 5 秒后安全检测出声状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                if !AudioEngine.shared.isAudioOutputActive() {
                    print("[PlayerController] 冷启动 5 秒未检测到音频流，自动回退备用唤醒音")
                    self.playFallbackAudio()
                }
            }
            completion(true)
        }
        
        if FileManager.default.fileExists(atPath: appPath) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            workspace.openApplication(at: appURL, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if error == nil {
                        handleColdLaunchSuccess()
                    } else {
                        completion(false)
                    }
                }
            }
        } else if let targetURL = workspace.urlForApplication(withBundleIdentifier: ytBundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.openApplication(at: targetURL, configuration: config) { _, err in
                DispatchQueue.main.async {
                    if err == nil {
                        handleColdLaunchSuccess()
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            completion(false)
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
