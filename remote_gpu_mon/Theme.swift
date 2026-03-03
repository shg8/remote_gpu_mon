import SwiftUI

enum Theme {

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Chart

    enum Chart {
        static let height: CGFloat = 32
        static let barOpacity: Double = 0.7
        static let memoryLineWidth: CGFloat = 2.0
        static let backgroundOpacity: Double = 0.35
        static let cornerRadius: CGFloat = 4
    }

    // MARK: - Card

    enum Card {
        static let activeOpacity: Double = 0.10
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = Spacing.sm
    }

    // MARK: - StatusBar

    enum StatusBar {
        static let barSpacing: CGFloat = 2
        static let barCornerRadius: CGFloat = 1.5
        static let horizontalPadding: CGFloat = 3
    }

    // MARK: - Popover

    enum Popover {
        static let width: CGFloat = 360
        static let height: CGFloat = 420
        static let maxScrollHeight: CGFloat = 460
    }

    // MARK: - Settings

    enum Settings {
        static let width: CGFloat = 480
        static let minHeight: CGFloat = 400
        static let idealHeight: CGFloat = 500
    }

    // MARK: - Shared Colors

    static func utilizationColor(_ util: Int) -> Color {
        if util >= 80 { return .red }
        if util >= 50 { return .yellow }
        return .green
    }
}
