import SwiftUI

/// 专为 macOS 打造的紧凑型时分微调器组件
/// 彻底替代弹出 60 行超长下拉菜单的默认 Picker，实现零弹窗、零遮挡、零重叠
public struct TimeStepperView: View {
    @Binding public var hour: Int
    @Binding public var minute: Int
    public var accentColor: Color = .blue
    
    public init(hour: Binding<Int>, minute: Binding<Int>, accentColor: Color = .blue) {
        self._hour = hour
        self._minute = minute
        self.accentColor = accentColor
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            // 小时微调单元
            singleUnitControl(
                value: $hour,
                range: 0...23,
                label: "时"
            )
            
            Text(":")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            // 分钟微调单元
            singleUnitControl(
                value: $minute,
                range: 0...59,
                label: "分",
                step: 5 // 辅助按键或快速步进支持
            )
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
    
    private func singleUnitControl(
        value: Binding<Int>,
        range: ClosedRange<Int>,
        label: String,
        step: Int = 1
    ) -> some View {
        HStack(spacing: 2) {
            // 数字展示卡片
            Text(String(format: "%02d", value.wrappedValue))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 22, alignment: .center)
            
            // 紧凑上下微调按钮组 (Stepper 风格)
            VStack(spacing: 1) {
                Button(action: {
                    increment(value: value, in: range)
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 9)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    decrement(value: value, in: range)
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
    
    private func increment(value: Binding<Int>, in range: ClosedRange<Int>) {
        if value.wrappedValue >= range.upperBound {
            value.wrappedValue = range.lowerBound
        } else {
            value.wrappedValue += 1
        }
    }
    
    private func decrement(value: Binding<Int>, in range: ClosedRange<Int>) {
        if value.wrappedValue <= range.lowerBound {
            value.wrappedValue = range.upperBound
        } else {
            value.wrappedValue -= 1
        }
    }
}
