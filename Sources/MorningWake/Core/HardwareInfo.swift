import Foundation

public struct HardwareInfo {
    public static let shared = HardwareInfo()
    
    public let modelIdentifier: String
    public let chipName: String
    public let isMacMini: Bool
    public let formattedDisplayName: String
    
    private init() {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelStr = String(cString: model)
        self.modelIdentifier = modelStr
        
        var cpuSize: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &cpuSize, nil, 0)
        var cpu = [CChar](repeating: 0, count: cpuSize)
        sysctlbyname("machdep.cpu.brand_string", &cpu, &cpuSize, nil, 0)
        let chipStr = String(cString: cpu)
        self.chipName = chipStr
        
        // 识别是否为 Mac mini 系列（如 Mac16,10 / Mac16,11 / Macmini 等）
        self.isMacMini = modelStr.contains("Mac16,") || modelStr.lowercased().contains("mini")
        
        if isMacMini {
            self.formattedDisplayName = "Mac mini (\(chipStr))"
        } else {
            self.formattedDisplayName = "\(modelStr) (\(chipStr))"
        }
    }
}
