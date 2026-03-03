import SwiftUI

/// Rendered to an NSImage and used as the status bar button's image.
struct StatusBarBars: View {
    var title: String = ""
    let gpuUtils: [Int]
    var isDark: Bool = false
    var height: CGFloat = 22

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if !title.isEmpty {
                Text(title)
                    .foregroundStyle(isDark ? Color.white : Color.black)
            }

            HStack(spacing: Theme.StatusBar.barSpacing) {
                ForEach(Array(gpuUtils.enumerated()), id: \.offset) { _, util in
                    RoundedRectangle(cornerRadius: Theme.StatusBar.barCornerRadius)
                        .fill(isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                        .frame(width: 3, height: 14)
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: Theme.StatusBar.barCornerRadius)
                                .fill(Theme.utilizationColor(util))
                                .frame(height: max(2, CGFloat(util) / 100.0 * 14))
                        }
                }
            }
        }
        .frame(height: height)
        .padding(.horizontal, Theme.StatusBar.horizontalPadding)
        .fixedSize()
    }
}
