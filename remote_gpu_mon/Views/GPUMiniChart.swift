import SwiftUI

struct GPUMiniChart: View {
    let history: [(date: Date, metrics: GPUMetrics)]
    let timeWindow: TimeInterval

    var body: some View {
        Canvas { context, size in
            guard !history.isEmpty else { return }

            let now = Date()
            let startTime = now.addingTimeInterval(-timeWindow)
            let barWidth: CGFloat = max(2, size.width / CGFloat(max(1, history.count)))

            // Utilization bars
            for (_, point) in history.enumerated() {
                let timeFraction = point.date.timeIntervalSince(startTime) / timeWindow
                guard timeFraction >= 0, timeFraction <= 1 else { continue }

                let x = timeFraction * size.width
                let utilFraction = CGFloat(point.metrics.utilizationPercent) / 100.0
                let barHeight = utilFraction * size.height

                let rect = CGRect(
                    x: x - barWidth / 2,
                    y: size.height - barHeight,
                    width: max(1, barWidth - 1),
                    height: barHeight
                )
                context.fill(
                    Path(rect),
                    with: .color(Theme.utilizationColor(point.metrics.utilizationPercent).opacity(Theme.Chart.barOpacity))
                )
            }

            // Memory line
            guard history.count > 1 else { return }
            var memPath = Path()
            var started = false

            for point in history {
                let timeFraction = point.date.timeIntervalSince(startTime) / timeWindow
                guard timeFraction >= 0 else { continue }

                let x = timeFraction * size.width
                let memFraction = point.metrics.memoryPercent / 100.0
                let y = size.height - memFraction * size.height

                if !started {
                    memPath.move(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    memPath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(memPath, with: .color(.blue.opacity(0.8)), lineWidth: Theme.Chart.memoryLineWidth)
        }
        .frame(height: Theme.Chart.height)
        .background(Color(nsColor: .controlBackgroundColor).opacity(Theme.Chart.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Chart.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.Chart.cornerRadius).stroke(Color.primary.opacity(0.1)))
    }
}
