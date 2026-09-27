import SwiftUI

/// iOS 手机闹钟风格的时间调整与选择组件
/// 支持：
/// 1. `.expanded`：仿 iOS 闹钟编辑页的双方块大卡片 `[ 07 ] : [ 35 ]` + 上下微调 + 快捷 ±5m / ±10m 胶囊
/// 2. `.compact`：仿 iOS 设置项的紧凑型时分胶囊 `[ 07 : 35 ]`
public struct IOSTimePickerView: View {
    public enum Style {
        case expanded   // iOS 闹钟编辑页大卡片样式
        case compact    // iOS 设置行紧凑胶囊样式
    }
    
    @Binding public var hour: Int
    @Binding public var minute: Int
    public var accentColor: Color
    public var style: Style
    public var showQuickButtons: Bool
    
    public init(
        hour: Binding<Int>,
        minute: Binding<Int>,
        accentColor: Color = .blue,
        style: Style = .compact,
        showQuickButtons: Bool = true
    ) {
        self._hour = hour
        self._minute = minute
        self.accentColor = accentColor
        self.style = style
        self.showQuickButtons = showQuickButtons
    }
    
    public var body: some View {
        switch style {
        case .expanded:
            expandedPicker
        case .compact:
            compactPicker
        }
    }
    
    // MARK: - 1. iOS 闹钟编辑页大卡片样式 (Expanded)
    private var expandedPicker: some View {
        VStack(spacing: 12) {
            // 核心时分双方块大输入卡片
            HStack(spacing: 12) {
                // 小时卡片
                timeUnitCard(
                    value: $hour,
                    range: 0...23,
                    label: "小时"
                )
                
                // 冒号分隔符
                Text(":")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 14)
                
                // 分钟卡片
                timeUnitCard(
                    value: $minute,
                    range: 0...59,
                    label: "分钟"
                )
            }
            
            // iOS 快捷增减胶囊按钮组
            if showQuickButtons {
                HStack(spacing: 8) {
                    quickDeltaButton(delta: -10, title: "-10分")
                    quickDeltaButton(delta: -5, title: "-5分")
                    quickDeltaButton(delta: 5, title: "+5分")
                    quickDeltaButton(delta: 10, title: "+10分")
                }
                .padding(.top, 2)
            }
        }
    }
    
    private func timeUnitCard(
        value: Binding<Int>,
        range: ClosedRange<Int>,
        label: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // 大号数字展示
                Text(String(format: "%02d", value.wrappedValue))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                
                // 垂直上下微调步进按钮
                VStack(spacing: 2) {
                    Button(action: {
                        stepValue(value: value, delta: 1, range: range)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 18)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        stepValue(value: value, delta: -1, range: range)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 18)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private func quickDeltaButton(delta: Int, title: String) -> some View {
        Button(action: {
            applyMinuteDelta(delta)
        }) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func applyMinuteDelta(_ delta: Int) {
        var totalMinutes = hour * 60 + minute + delta
        if totalMinutes < 0 {
            totalMinutes += 24 * 60
        }
        totalMinutes = totalMinutes % (24 * 60)
        hour = totalMinutes / 60
        minute = totalMinutes % 60
    }
    
    // MARK: - 2. iOS 紧凑时分胶囊样式 (Compact)
    private var compactPicker: some View {
        HStack(spacing: 5) {
            // 小时单元
            compactUnitControl(value: $hour, range: 0...23)
            
            Text(":")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            // 分钟单元
            compactUnitControl(value: $minute, range: 0...59)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
    
    private func compactUnitControl(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 2) {
            Text(String(format: "%02d", value.wrappedValue))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 22, alignment: .center)
            
            VStack(spacing: 1) {
                Button(action: {
                    stepValue(value: value, delta: 1, range: range)
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 9)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    stepValue(value: value, delta: -1, range: range)
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 9)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func stepValue(value: Binding<Int>, delta: Int, range: ClosedRange<Int>) {
        var newVal = value.wrappedValue + delta
        if newVal > range.upperBound {
            newVal = range.lowerBound
        } else if newVal < range.lowerBound {
            newVal = range.upperBound
        }
        value.wrappedValue = newVal
    }
}
