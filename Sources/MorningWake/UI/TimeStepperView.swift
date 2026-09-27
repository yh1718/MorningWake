import SwiftUI

/// 专为 macOS 打造的紧凑型时分微调器组件
/// 内部采用 IOSTimePickerView 紧凑模式实现
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
        IOSTimePickerView(
            hour: $hour,
            minute: $minute,
            accentColor: accentColor,
            style: .compact
        )
    }
}
