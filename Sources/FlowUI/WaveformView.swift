import SwiftUI

public struct WaveformView: View {
    @ObservedObject var state: WaveformState
    private let barWeights: [CGFloat]

    private static let widthScale: CGFloat = 1.2

    private static let barCount = 5
    private static let barWidth: CGFloat = 2.5 * widthScale
    private static let barSpacing: CGFloat = 3 * widthScale
    private static let horizontalPadding: CGFloat = 12 * widthScale
    private static let minBarHeight: CGFloat = 3
    private static let maxBarHeight: CGFloat = 16

    public init(state: WaveformState) {
        self.state = state
        let center = Double(Self.barCount - 1) / 2
        self.barWeights = (0..<Self.barCount).map { i in
            let distanceFromCenter = center > 0 ? abs(Double(i) - center) / center : 0
            let taper = 1.0 - distanceFromCenter * 0.45
            return CGFloat(taper * Double.random(in: 0.85...1.0))
        }
    }

    public var body: some View {
        Group {
            if let message = state.message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 4)
            } else {
                bars
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, 9)
        .fixedSize()
        .preferredColorScheme(.dark)
    }

    private var bars: some View {
        HStack(spacing: Self.barSpacing) {
            if state.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.trailing, 1)
            }

            ForEach(0..<barWeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: Self.barWidth / 2)
                    .fill(.white.opacity(0.9))
                    .frame(width: Self.barWidth, height: barHeight(at: index))
            }
        }
        .animation(.spring(response: 0.09, dampingFraction: 0.7), value: state.currentLevel)
    }

    private func barHeight(at index: Int) -> CGFloat {
        let level = CGFloat(state.currentLevel) * barWeights[index]
        return Self.minBarHeight + level * (Self.maxBarHeight - Self.minBarHeight)
    }
}
