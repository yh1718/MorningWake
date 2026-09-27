import Cocoa

func drawMorningWakeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let iconRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    
    // 1. 柔和环境阴影
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.03), blur: size * 0.08, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. 主卡片渐变背景：深邃晨空至晨曦破晓
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.16, green: 0.12, blue: 0.32, alpha: 1.0).cgColor, // 深晨紫
        NSColor(red: 0.42, green: 0.22, blue: 0.48, alpha: 1.0).cgColor, // 霞紫
        NSColor(red: 0.88, green: 0.38, blue: 0.28, alpha: 1.0).cgColor, // 晨橘
        NSColor(red: 0.98, green: 0.68, blue: 0.32, alpha: 1.0).cgColor  // 朝阳金
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.45, 0.8, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
            end: CGPoint(x: iconRect.midX, y: iconRect.minY),
            options: []
        )
    }
    
    // 3. 破晓太阳与光晕
    let sunCenterX = iconRect.midX
    let sunCenterY = iconRect.minY + iconRect.height * 0.38
    let sunRadius = iconRect.width * 0.22
    
    // 太阳外晕
    let glowColors = [
        NSColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 0.45).cgColor,
        NSColor(red: 1.0, green: 0.65, blue: 0.3, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: sunCenterX, y: sunCenterY),
            startRadius: sunRadius * 0.4,
            endCenter: CGPoint(x: sunCenterX, y: sunCenterY),
            endRadius: sunRadius * 2.2,
            options: []
        )
    }
    
    // 太阳本体
    let sunColors = [
        NSColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 1.0).cgColor,
        NSColor(red: 1.0, green: 0.68, blue: 0.28, alpha: 1.0).cgColor
    ] as CFArray
    if let sunGradient = CGGradient(colorsSpace: colorSpace, colors: sunColors, locations: [0.0, 1.0]) {
        let sunRect = CGRect(x: sunCenterX - sunRadius, y: sunCenterY - sunRadius, width: sunRadius * 2, height: sunRadius * 2)
        ctx.saveGState()
        ctx.addEllipse(in: sunRect)
        ctx.clip()
        ctx.drawLinearGradient(
            sunGradient,
            start: CGPoint(x: sunCenterX, y: sunRect.maxY),
            end: CGPoint(x: sunCenterX, y: sunRect.minY),
            options: []
        )
        ctx.restoreGState()
    }
    
    // 4. 音乐韵律声波弧线（象征渐进式音律唤醒）
    ctx.setLineCap(.round)
    let waveRadii: [CGFloat] = [0.42, 0.56, 0.70]
    let waveAlphas: [CGFloat] = [0.75, 0.50, 0.30]
    let waveWidths: [CGFloat] = [size * 0.024, size * 0.020, size * 0.016]
    
    for i in 0..<waveRadii.count {
        let r = iconRect.width * waveRadii[i]
        let wavePath = CGMutablePath()
        // 上升弧度：从 30度 到 150度
        let startAngle: CGFloat = .pi * 0.2
        let endAngle: CGFloat = .pi * 0.8
        wavePath.addArc(
            center: CGPoint(x: sunCenterX, y: sunCenterY),
            radius: r,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        ctx.saveGState()
        ctx.addPath(wavePath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(waveAlphas[i]).cgColor)
        ctx.setLineWidth(waveWidths[i])
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // 5. 地平线微光
    let horizonY = sunCenterY - sunRadius * 0.2
    let horizonPath = CGMutablePath()
    horizonPath.move(to: CGPoint(x: iconRect.minX, y: horizonY))
    horizonPath.addLine(to: CGPoint(x: iconRect.maxX, y: horizonY))
    ctx.saveGState()
    ctx.addPath(horizonPath)
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.4).cgColor)
    ctx.setLineWidth(size * 0.012)
    ctx.strokePath()
    ctx.restoreGState()
    
    // 6. 内边缘高光边框（提升现代感）
    let strokePath = CGPath(roundedRect: iconRect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(strokePath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.setLineWidth(1.0)
    ctx.strokePath()
    
    ctx.restoreGState()
    image.unlockFocus()
    return image
}

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconsetDir = scriptDir.appendingPathComponent("AppIcon.iconset")
let icnsOutput = scriptDir.appendingPathComponent("AppIcon.icns")

try? fileManager.removeItem(at: iconsetDir)
try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, s) in sizes {
    let img = drawMorningWakeIcon(size: s)
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
        if let png = rep.representation(using: .png, properties: [:]) {
            let fileURL = iconsetDir.appendingPathComponent(name)
            try? png.write(to: fileURL)
        }
    }
}

// 转换生成 .icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsOutput.path]
try? task.run()
task.waitUntilExit()

try? fileManager.removeItem(at: iconsetDir)

if fileManager.fileExists(atPath: icnsOutput.path) {
    print("成功生成 macOS 原生图标: \(icnsOutput.path)")
} else {
    print("生成图标失败")
}
