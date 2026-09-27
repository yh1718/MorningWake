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
    public let isBuiltIn: Bool
    public let supportsVolumeControl: Bool
    
    public var label: String {
        if isBuiltIn {
            return "\(name) (内置 · 支持平滑渐变)"
        } else if supportsVolumeControl {
            return "\(name) (支持调音)"
        } else {
            return "\(name) (不支持系统音量调谐)"
        }
    }
}

public final class AudioEngine: ObservableObject {
    public static let shared = AudioEngine()
    
    @Published public private(set) var isFading: Bool = false
    @Published public private(set) var currentFadingVolume: Float = 0.0
    @Published public private(set) var availableDevices: [AudioDeviceInfo] = []
    
    private var fadeTimer: Timer?
    private var fadeStartTime: Date?
    private var fadeDuration: TimeInterval = 120.0
    private var startVol: Float = 0.2
    private var targetVol: Float = 0.9
    private var currentCurve: FadeCurve = .smoothStep
    private var lastAppliedVolume: Float = 0.0
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
    
    @discardableResult
    public func switchToBuiltInSpeaker() -> Bool {
        refreshAudioDevices()
        // 优先锁定 Mac mini 内置扬声器
        if let miniSpeaker = availableDevices.first(where: { $0.isBuiltIn && $0.supportsVolumeControl }) {
            print("[AudioEngine] 锁定 Mac mini 内置扬声器: \(miniSpeaker.name) (ID: \(miniSpeaker.id))")
            return setDefaultOutputDevice(id: miniSpeaker.id)
        }
        return false
    }
    
    // 检查当前输出设备，如果遇到如显示器 (DisplayPort) 等不可调设备，自动平滑切回 Mac mini 扬声器
    public func ensureSettableOutputDevice() {
        guard let currentID = getDefaultOutputDeviceID() else { return }
        refreshAudioDevices()
        if let currentInfo = availableDevices.first(where: { $0.id == currentID }), !currentInfo.supportsVolumeControl {
            print("[AudioEngine] 当前默认音频设备 [\(currentInfo.name)] 不支持系统音量渐变，自动切换为 Mac mini 扬声器")
            switchToBuiltInSpeaker()
        }
    }
    
    public func getVolume() -> Float {
        guard let deviceID = getDefaultOutputDeviceID() else { return 0.5 }
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
        return status == noErr ? volume : 0.5
    }
    
    public func setVolume(_ volume: Float) {
        guard let deviceID = getDefaultOutputDeviceID() else { return }
        var vol = max(0.0, min(1.0, volume))
        let propertySize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            propertySize,
            &vol
        )
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
        
        self.setVolume(self.startVol)
        self.lastAppliedVolume = self.startVol
        self.currentFadingVolume = self.startVol
        onProgress?(self.startVol)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickFade()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.fadeTimer = timer
    }
    
    private func tickFade() {
        guard let startTime = fadeStartTime else { return }
        
        let currentSysVol = getVolume()
        let diff = abs(currentSysVol - lastAppliedVolume)
        
        // 容差过滤：单个音量阶梯约为 0.0625。若偏差 > 0.08 且连续 2 个周期或单次 > 0.15，则判定为物理键/用户接管
        if diff > 0.15 {
            print("[AudioEngine] 检测到显著外部音量调整 (\(currentSysVol) vs \(lastAppliedVolume))，退出渐变")
            let intervention = onInterventionCallback
            stopFade()
            intervention?()
            return
        } else if diff > 0.08 {
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
        
        let elapsed = Date().timeIntervalSince(startTime)
        let normalizedProgress = min(1.0, elapsed / fadeDuration)
        
        let curveFactor = Float(currentCurve.transform(t: normalizedProgress))
        let newVolume = startVol + (targetVol - startVol) * curveFactor
        
        setVolume(newVolume)
        self.lastAppliedVolume = newVolume
        self.currentFadingVolume = newVolume
        onProgressCallback?(newVolume)
        
        if normalizedProgress >= 1.0 {
            stopFade()
            onCompleteCallback?()
        }
    }
    
    public func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        isFading = false
    }
}
