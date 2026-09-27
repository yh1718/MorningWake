import SwiftUI

/// iOS 手机闹钟风格的时间调整与选择组件
/// 支持：
/// 1. `.expanded`：仿 iOS 闹钟编辑页的双方块大卡片 `[ 07 ] : [ 35 ]`
///    - 支持鼠标点击直接键盘输入（纯数字键入、双位数自动切焦、自动限制 0~23/0~59）
///    - 搭配上下微调步进器与快捷 ±5m / ±10m 增减胶囊
/// 2. `.compact`：仿 iOS 设置项的紧凑型时分胶囊 `[ 07 : 35 ]`
///    - 同样支持点击键盘直接输入与微调
public struct IOSTimePickerView: View {
    public enum Style {
        case expanded   // iOS 闹钟编辑页大卡片样式
        case compact    // iOS 设置行紧凑胶囊样式
    }
    
    private enum Field: Hashable {
        case hour
        case minute
    }
    
    @Binding public var hour: Int
    @Binding public var minute: Int
    public var accentColor: Color
    public var style: Style
    public var showQuickButtons: Bool
    
    @FocusState private var focusedField: Field?
    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    
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
        Group {
            switch style {
            case .expanded:
                expandedPicker
            case .compact:
                compactPicker
            }
        }
        .onAppear {
            syncFromBindings()
        }
        .onChange(of: hour) { newH in
            if focusedField != .hour {
                hourText = String(format: "%02d", newH)
            }
        }
        .onChange(of: minute) { newM in
            if focusedField != .minute {
                minuteText = String(format: "%02d", newM)
            }
        }
        .onChange(of: focusedField) { newField in
            if newField == nil {
                commitHour()
                commitMinute()
            } else if newField == .minute {
                commitHour()
            } else if newField == .hour {
                commitMinute()
            }
        }
    }
    
    // MARK: - 1. iOS 闹钟编辑页大卡片样式 (Expanded)
    private var expandedPicker: some View {
        VStack(spacing: 12) {
            // 核心时分双方块大输入卡片
            HStack(spacing: 12) {
                // 小时输入卡片
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        TextField("", text: $hourText)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .hour)
                            .frame(width: 48, height: 44)
                            .background(Color(NSColor.textBackgroundColor).opacity(focusedField == .hour ? 0.95 : 0.6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .hour ? accentColor : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: hourText) { val in
                                handleHourTextChange(val)
                            }
                            .onSubmit {
                                commitHour()
                                focusedField = .minute
                            }
                        
                        // 垂直上下微调步进按钮
                        VStack(spacing: 2) {
                            Button(action: {
                                incrementHour()
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
                                decrementHour()
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
                            .stroke(focusedField == .hour ? accentColor.opacity(0.8) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    
                    Text("小时 (0~23)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(focusedField == .hour ? accentColor : .secondary)
                }
                
                // 冒号分隔符
                Text(":")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                
                // 分钟输入卡片
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        TextField("", text: $minuteText)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .minute)
                            .frame(width: 48, height: 44)
                            .background(Color(NSColor.textBackgroundColor).opacity(focusedField == .minute ? 0.95 : 0.6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .minute ? accentColor : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: minuteText) { val in
                                handleMinuteTextChange(val)
                            }
                            .onSubmit {
                                commitMinute()
                                focusedField = nil
                            }
                        
                        // 垂直上下微调步进按钮
                        VStack(spacing: 2) {
                            Button(action: {
                                incrementMinute()
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
                                decrementMinute()
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
                            .stroke(focusedField == .minute ? accentColor.opacity(0.8) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    
                    Text("分钟 (0~59)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(focusedField == .minute ? accentColor : .secondary)
                }
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
        hourText = String(format: "%02d", hour)
        minuteText = String(format: "%02d", minute)
    }
    
    // MARK: - 2. iOS 紧凑时分胶囊样式 (Compact)
    private var compactPicker: some View {
        HStack(spacing: 5) {
            // 小时输入单元
            HStack(spacing: 2) {
                TextField("", text: $hourText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .hour)
                    .frame(width: 24, alignment: .center)
                    .onChange(of: hourText) { val in
                        handleHourTextChange(val)
                    }
                    .onSubmit {
                        commitHour()
                        focusedField = .minute
                    }
                
                VStack(spacing: 1) {
                    Button(action: { incrementHour() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 9)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { decrementHour() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 9)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text(":")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            // 分钟输入单元
            HStack(spacing: 2) {
                TextField("", text: $minuteText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .minute)
                    .frame(width: 24, alignment: .center)
                    .onChange(of: minuteText) { val in
                        handleMinuteTextChange(val)
                    }
                    .onSubmit {
                        commitMinute()
                        focusedField = nil
                    }
                
                VStack(spacing: 1) {
                    Button(action: { incrementMinute() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 9)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { decrementMinute() }) {
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
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(focusedField != nil ? accentColor.opacity(0.6) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - 逻辑辅助方法
    
    private func syncFromBindings() {
        hourText = String(format: "%02d", hour)
        minuteText = String(format: "%02d", minute)
    }
    
    private func handleHourTextChange(_ text: String) {
        let filtered = text.filter { $0.isNumber }
        let trimmed = String(filtered.prefix(2))
        if trimmed != text {
            hourText = trimmed
        }
        if let val = Int(trimmed) {
            if val >= 0 && val <= 23 {
                hour = val
            }
        }
        // 当输入满 2 位且在有效范围内，自动切焦到分钟，体验与 iOS 闹钟一致
        if trimmed.count == 2 {
            focusedField = .minute
        }
    }
    
    private func handleMinuteTextChange(_ text: String) {
        let filtered = text.filter { $0.isNumber }
        let trimmed = String(filtered.prefix(2))
        if trimmed != text {
            minuteText = trimmed
        }
        if let val = Int(trimmed) {
            if val >= 0 && val <= 59 {
                minute = val
            }
        }
        // 当分钟输入满 2 位，自动完成输入并取消聚焦
        if trimmed.count == 2 {
            focusedField = nil
        }
    }
    
    private func commitHour() {
        if let val = Int(hourText) {
            let clamped = max(0, min(23, val))
            hour = clamped
            hourText = String(format: "%02d", clamped)
        } else {
            hourText = String(format: "%02d", hour)
        }
    }
    
    private func commitMinute() {
        if let val = Int(minuteText) {
            let clamped = max(0, min(59, val))
            minute = clamped
            minuteText = String(format: "%02d", clamped)
        } else {
            minuteText = String(format: "%02d", minute)
        }
    }
    
    private func incrementHour() {
        hour = (hour + 1) % 24
        hourText = String(format: "%02d", hour)
    }
    
    private func decrementHour() {
        hour = (hour - 1 + 24) % 24
        hourText = String(format: "%02d", hour)
    }
    
    private func incrementMinute() {
        minute = (minute + 1) % 60
        minuteText = String(format: "%02d", minute)
    }
    
    private func decrementMinute() {
        minute = (minute - 1 + 60) % 60
        minuteText = String(format: "%02d", minute)
    }
}
