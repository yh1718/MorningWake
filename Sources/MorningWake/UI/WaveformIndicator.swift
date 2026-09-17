import SwiftUI

public struct WaveformIndicator: View {
    let isActive: Bool
    @State private var animating = false
    
    public init(isActive: Bool) {
        self.isActive = isActive
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: animating && isActive ? barHeight(for: index) : 4)
                    .animation(
                        isActive
                        ? Animation.easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08)
                        : .default,
                        value: animating
                    )
            }
        }
        .frame(height: 18)
        .onAppear {
            animating = true
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: return 12
        case 1: return 18
        case 2: return 14
        case 3: return 16
        default: return 10
        }
    }
}
