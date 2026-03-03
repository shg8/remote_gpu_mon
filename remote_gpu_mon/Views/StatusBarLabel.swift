import SwiftUI

/// Rendered to an NSImage and used as the status bar button's image.
struct StatusBarBars: View {
    let gpuUtils: [Int]

    var body: some View {
        HStack(spacing: Theme.StatusBar.barSpacing) {
            ForEach(Array(gpuUtils.enumerated()), id: \.offset) { _, util in
                RoundedRectangle(cornerRadius: Theme.StatusBar.barCornerRadius)
                    .fill(Theme.utilizationColor(util))
                    .frame(
                        width: 4,
                        height: max(2, CGFloat(util) / 100.0 * 14)
                    )
                    .frame(height: 16, alignment: .bottom)
            }
        }
        .padding(.horizontal, Theme.StatusBar.horizontalPadding)
        .fixedSize()
    }
}
