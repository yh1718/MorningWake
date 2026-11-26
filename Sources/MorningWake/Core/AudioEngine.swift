import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation

public enum FadeCurve: String, CaseIterable, Identifiable {
    case smoothStep = "平滑 S 曲线 (推荐)"
    case logarithmic = "对数感知曲线"
    case linear = "线性均匀递增"
    
    public var id: String { rawValue }
    
    public func transform(t: Double) -> Double {
        let clamped = max(0.0, min(1.0, t))
        switch self {
        case .smoothStep:
            return clamped * clamped * (3.0 - 2.0 * clamped)
        case .logarithmic:
            return (pow(10.0, clamped) - 1.0) / 9.0
        case .linear:
            return clamped
        }
    }
}

public struct AudioDeviceInfo: Identifiable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String
    public let isBuiltIn: Bool
    public let supportsVolumeControl: Bool
    
    public init(id: AudioDeviceID, name: String, uid: String = "", isBuiltIn: Bool, supportsVolumeControl: Bool) {
        self.id = id
        self.name = name
        self.uid = uid
        self.isBuiltIn = isBuiltIn
        self.supportsVolumeControl = supportsVolumeControl
    }
    
    public var label: String {
        if isBuiltIn {
            return "\(name) (内置 · 支持平滑渐变)"
        } else if supportsVolumeControl {
            return "\(name) (支持调音)"
        } else {
            return "\(name) (外接输出 · 支持软件音量渐变)"
        }
    }
}

public final class AudioEngine: ObservableObject {
    public static let shared = AudioEngine()
    
    @Published public private(set) var isFading: Bool = false
    @Published public private(set) var currentFadingVolume: Float = 0.0
    @Published public private(set) var availableDevices: [AudioDeviceInfo] = []
    @Published public private(set) var lastVirtualVolume: Float = 0.5
    
    // BetterDisplay DDC 硬件音量桥接通道
    private let betterDisplayPath = "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
    private var isBetterDisplayAvailable: Bool {
        FileManager.default.fileExists(atPath: betterDisplayPath)
    }
    private var lastDDCExecutionTime: Date = .distantPast
    private var lastDDCSetVolume: Float = -1.0
    private let ddcQueue = DispatchQueue(label: "com.morningwake.ddc", qos: .userInteractive)
    
    private var fadeTimer: Timer?
    private var fadeStartTime: Date?
    private var fadeDuration: TimeInterval = 120.0
    private var startVol: Float = 0.2
    private var targetVol: Float = 0.9
    private var currentCurve: FadeCurve = .smoothStep
    private var lastAppliedVolume: Float = 0.0
    private var lastObservedSysVolume: Float = 0.0
    private var lastSetVolumeSucceeded: Bool = true
    private var fadeActivity: NSObjectProtocol?
    private var onProgressCallback: ((Float) -> Void)?
    private var onCompleteCallback: (() -> Void)?
    private var onInterventionCallback: (() -> Void)?
    private var consecutiveDiscrepancyCount: Int = 0
    
    private init() {
        refreshAudioDevices()
        setupDeviceListeners()
    }
    
    private func setupDeviceListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshAudioDevices()
        }
        
        var defaultDevAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDevAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshAudioDevices()
        }
    }
    
    // MARK: - Mac mini M4 Audio Device Enumeration
    
    public func refreshAudioDevices() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return
        }
        
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return
        }
        
        var result: [AudioDeviceInfo] = []
        for id in ids {
            // 过滤无输出流的设备
            var streamsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize = UInt32(0)
            let s = AudioObjectGetPropertyDataSize(id, &streamsAddress, 0, nil, &streamSize)
            guard s == noErr && streamSize > 0 else { continue }
            
            // 设备名称
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var devName = "未知设备"
            if AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &cfName) == noErr, let unmanaged = cfName {
                devName = unmanaged.takeRetainedValue() as String
            }
            
            // 设备 UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfUid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var devUid = ""
            if AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &cfUid) == noErr, let unmanaged = cfUid {
                devUid = unmanaged.takeRetainedValue() as String
            }
            
            // 传输类型判断内置扬声器（或包含 Mac mini 扬声器关键字）
            var transAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transSize = UInt32(MemoryLayout<UInt32>.size)
            let isBuiltIn = (AudioObjectGetPropertyData(id, &transAddress, 0, nil, &transSize, &transport) == noErr && transport == kAudioDeviceTransportTypeBuiltIn) || devName.contains("Mac mini")
            
            // 音量可调性检查（规避 DisplayPort/HDMI 显示器不可调问题）
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var isSettable: DarwinBoolean = false
            let settableStatus = AudioObjectIsPropertySettable(id, &volAddress, &isSettable)
            let supportsVolume = (settableStatus == noErr && isSettable.boolValue)
            
            result.append(AudioDeviceInfo(
                id: id,
                name: devName,
                uid: devUid,
                isBuiltIn: isBuiltIn,
                supportsVolumeControl: supportsVolume
            ))
        }
        
        if Thread.isMainThread {
            self.availableDevices = result
        } else {
            DispatchQueue.main.async {
                self.availableDevices = result
            }
        }
    }
    
    // MARK: - CoreAudio Device Management
    
    public func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }
    
    @discardableResult
    public func setDefaultOutputDevice(id: AudioDeviceID) -> Bool {
        var defaultDevID = id
        var setDefaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &setDefaultAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &defaultDevID
        )
        return status == noErr
    }
    
    public func getDeviceID(forUID uid: String) -> AudioDeviceID? {
        refreshAudioDevices()
        return availableDevices.first(where: { $0.uid == uid })?.id
    }
    
    public func getDeviceID(forName name: String) -> AudioDeviceID? {
        refreshAudioDevices()
        return availableDevices.first(where: { $0.name == name || $0.name.localizedCaseInsensitiveContains(name) })?.id
    }
    
    @discardableResult
    public func switchToDevice(uidOrName: String) -> Bool {
        refreshAudioDevices()
        if let dev = availableDevices.first(where: { $0.uid == uidOrName || $0.name == uidOrName || $0.name.localizedCaseInsensitiveContains(uidOrName) }) {
            print("[AudioEngine] 切换输出设备至: \(dev.name) (ID: \(dev.id), UID: \(dev.uid))")
            return setDefaultOutputDevice(id: dev.id)
        }
        return false
    }
    
    @discardableResult
    public func switchToBuiltInSpeaker() -> Bool {
        refreshAudioDevices()
        // 优先锁定内置扬声器
        if let miniSpeaker = availableDevices.first(where: { $0.isBuiltIn }) {
            print("[AudioEngine] 锁定内置扬声器: \(miniSpeaker.name) (ID: \(miniSpeaker.id))")
            return setDefaultOutputDevice(id: miniSpeaker.id)
        }
        return false
    }
    
    // 检查当前输出设备状态，外接显示器/音响通道（DisplayPort/HDMI）通过软件音量协同渐变，不再强行切走设备
    public func ensureSettableOutputDevice() {
        guard let currentID = getDefaultOutputDeviceID() else { return }
        refreshAudioDevices()
        if let currentInfo = availableDevices.first(where: { $0.id == currentID }) {
            if !currentInfo.supportsVolumeControl {
                print("[AudioEngine] 当前音频输出设备 [\(currentInfo.name)] 为外接输出通道，已启用软件音量协同渐变")
            }
        }
    }
    
    public func setDDCVolume(_ volume: Float, force: Bool = false) {
        guard isBetterDisplayAvailable else { return }
        let clamped = max(0.0, min(1.0, volume))
        
        ddcQueue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            let timeDiff = now.timeIntervalSince(self.lastDDCExecutionTime)
            let volDiff = abs(clamped - self.lastDDCSetVolume)
            
            // 节流机制：非强制更新时，若间隔小于 0.2 秒且音量变化小于 0.02，则跳过中间高频采样
            if !force && timeDiff < 0.2 && volDiff < 0.02 {
                return
            }
            
            self.lastDDCExecutionTime = now
            self.lastDDCSetVolume = clamped
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: self.betterDisplayPath)
            var env = ProcessInfo.processInfo.environment
            env.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
            proc.environment = env
            proc.arguments = ["set", String(format: "-volume=%.3f", clamped)]
            try? proc.run()
            proc.waitUntilExit()
        }
    }
    
    public func getVolume() -> Float {
        guard let deviceID = getDefaultOutputDeviceID() else { return lastVirtualVolume }
        
        // 若当前设备属于外接显示器/音响通道（不支持原生系统调音），返回最近设置的虚拟/DDC 音量
        if let devInfo = availableDevices.first(where: { $0.id == deviceID }), !devInfo.supportsVolumeControl {
            return lastVirtualVolume
        }
        
        var volume: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &volume
        )
        return status == noErr ? volume : lastVirtualVolume
    }
    
    @discardableResult
    public func setVolume(_ volume: Float, on deviceID: AudioDeviceID? = nil) -> Bool {
        let clamped = max(0.0, min(1.0, volume))
        self.lastVirtualVolume = clamped
        guard let targetDeviceID = deviceID ?? getDefaultOutputDeviceID() else { return false }
        
        var isSupported = true
        if let devInfo = availableDevices.first(where: { $0.id == targetDeviceID }) {
            isSupported = devInfo.supportsVolumeControl
        }
        
        if isSupported {
            var vol = clamped
            let propertySize = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectSetPropertyData(
                targetDeviceID,
                &address,
                0,
                nil,
                propertySize,
                &vol
            )
            return status == noErr
        } else {
            // 设备不支持系统 CoreAudio 硬件音量控制（如 Mi Monitor / DisplayPort 外接音响通道）
            // 通过 BetterDisplay DDC/CI 硬件协议直接调节显示器硬件音频输出音量
            setDDCVolume(clamped)
            return true
        }
    }
    
    public func unmute() {
        guard let deviceID = getDefaultOutputDeviceID() else { return }
        var muted: UInt32 = 0
        let propertySize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            propertySize,
            &muted
        )
    }
    
    // MARK: - Smooth Volume Fade
    
    public func startFade(
        from start: Float,
        to target: Float,
        duration: TimeInterval,
        curve: FadeCurve = .smoothStep,
        onProgress: ((Float) -> Void)? = nil,
        onIntervention: (() -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        stopFade()
        
        // 渐变前确保设备支持音量调节
        ensureSettableOutputDevice()
        self.unmute()
        
        self.startVol = max(0.0, min(1.0, start))
        self.targetVol = max(0.0, min(1.0, target))
        self.fadeDuration = max(1.0, duration)
        self.currentCurve = curve
        self.onProgressCallback = onProgress
        self.onInterventionCallback = onIntervention
        self.onCompleteCallback = onComplete
        self.consecutiveDiscrepancyCount = 0
        self.fadeStartTime = Date()
        self.isFading = true
        
        // 防止锁屏或后台状态下 macOS App Nap 对渐变定时器进行节流挂起
        self.fadeActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "MorningWake smooth volume fade"
        )
        
        self.lastSetVolumeSucceeded = self.setVolume(self.startVol)
        self.setDDCVolume(self.startVol, force: true)
        self.lastAppliedVolume = self.startVol
        self.lastObservedSysVolume = self.getVolume()
        self.currentFadingVolume = self.startVol
        onProgress?(self.startVol)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickFade()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.fadeTimer = timer
    }
    
    /// 判断系统音量与预期音量的偏差是否属于外部主动干预（而非锁屏/系统限制导致音量停滞未动）
    internal static func shouldTreatAsExternalIntervention(
        currentSysVol: Float,
        lastObservedSysVol: Float,
        lastAppliedVolume: Float,
        startVol: Float,
        targetVol: Float,
        lastSetSucceeded: Bool
    ) -> Bool {
        // 若上次系统音量写入直接返回失败，说明是系统通道受限，而非用户接管
        guard lastSetSucceeded else { return false }
        
        let diffFromApplied = abs(currentSysVol - lastAppliedVolume)
        guard diffFromApplied > 0.08 else { return false }
        
        let deltaFromObserved = currentSysVol - lastObservedSysVol
        let isIncreasingFade = targetVol >= startVol
        
        // 若系统音量几乎停在原地没动（锁屏/驱动限制写入未生效），且方向未反向，不判定为外部干预
        if abs(deltaFromObserved) < 0.01 {
            let isStalledBehindTarget = isIncreasingFade
                ? (currentSysVol <= lastAppliedVolume)
                : (currentSysVol >= lastAppliedVolume)
            if isStalledBehindTarget {
                return false
            }
        }
        
        // 若系统音量只是顺着渐变方向滞后追赶（尚未超过预期音量），属于硬件步进/延迟追赶，不判定为干预
        if isIncreasingFade && deltaFromObserved >= -0.02 && currentSysVol <= lastAppliedVolume + 0.06 {
            return false
        }
        if !isIncreasingFade && deltaFromObserved <= 0.02 && currentSysVol >= lastAppliedVolume - 0.06 {
            return false
        }
        
        // 若当前是渐增，而系统音量反而明显下降（或渐减时反而明显上升），属于明确外部干预
        if isIncreasingFade && deltaFromObserved < -0.04 {
            return true
        }
        if !isIncreasingFade && deltaFromObserved > 0.04 {
            return true
        }
        
        // 其余情况（例如系统音量突然跳变超越预期目标方向）按偏差判定
        return true
    }
    
    private func tickFade() {
        guard let startTime = fadeStartTime else { return }
        
        // 仅在当前设备支持硬件主音量控制时，才进行外部物理音量按键干预检测
        if let currentDevID = getDefaultOutputDeviceID(),
           let devInfo = availableDevices.first(where: { $0.id == currentDevID }),
           devInfo.supportsVolumeControl {
            let currentSysVol = getVolume()
            let diff = abs(currentSysVol - lastAppliedVolume)
            let isExternalIntervention = Self.shouldTreatAsExternalIntervention(
                currentSysVol: currentSysVol,
                lastObservedSysVol: lastObservedSysVolume,
                lastAppliedVolume: lastAppliedVolume,
                startVol: startVol,
                targetVol: targetVol,
                lastSetSucceeded: lastSetVolumeSucceeded
            )
            
            // 容差过滤：单个音量阶梯约为 0.0625。若确认是外部调整且单次偏差 > 0.15 或连续 2 个周期 > 0.08，则判定为物理键/用户接管
            if isExternalIntervention && diff > 0.15 {
                print("[AudioEngine] 检测到显著外部音量调整 (\(currentSysVol) vs \(lastAppliedVolume))，退出渐变")
                let intervention = onInterventionCallback
                stopFade()
                intervention?()
                return
            } else if isExternalIntervention && diff > 0.08 {
                consecutiveDiscrepancyCount += 1
                if consecutiveDiscrepancyCount >= 2 {
                    print("[AudioEngine] 连续检测到外部音量干预 (\(currentSysVol) vs \(lastAppliedVolume))，退出渐变")
                    let intervention = onInterventionCallback
                    stopFade()
                    intervention?()
                    return
                }
            } else {
                consecutiveDiscrepancyCount = 0
            }
            self.lastObservedSysVolume = currentSysVol
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let normalizedProgress = min(1.0, elapsed / fadeDuration)
        
        let curveFactor = Float(currentCurve.transform(t: normalizedProgress))
        let newVolume = startVol + (targetVol - startVol) * curveFactor
        
        self.lastSetVolumeSucceeded = setVolume(newVolume)
        self.lastAppliedVolume = newVolume
        self.currentFadingVolume = newVolume
        onProgressCallback?(newVolume)
        
        if normalizedProgress >= 1.0 {
            setDDCVolume(targetVol, force: true)
            stopFade()
            onCompleteCallback?()
        }
    }
    
    public func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        isFading = false
        if let activity = fadeActivity {
            ProcessInfo.processInfo.endActivity(activity)
            fadeActivity = nil
        }
    }
    
    /// 检测当前默认输出设备是否有音频流正在运行（即是否有应用正在播放声音）
    public func isAudioOutputActive() -> Bool {
        guard let devID = getDefaultOutputDeviceID(), devID != kAudioDeviceUnknown else { return false }
        
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(devID, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }
}
