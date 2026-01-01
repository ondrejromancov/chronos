import SwiftUI

// MARK: - Layout Constants

enum LayoutConstants {
    // Popup dimensions
    static let popupWidth: CGFloat = 280

    // Margins & spacing
    static let horizontalMargin: CGFloat = 12
    static let verticalMargin: CGFloat = 10
    static let itemSpacing: CGFloat = 4
    static let sectionSpacing: CGFloat = 8

    // Corner radius
    static let panelCornerRadius: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 6
    static let cellCornerRadius: CGFloat = 6

    // Item heights
    static let listItemHeight: CGFloat = 28
    static let headerHeight: CGFloat = 40
}

// MARK: - Animation Durations

enum AnimationDurations {
    static let instant: TimeInterval = 0.1
    static let fast: TimeInterval = 0.15
    static let normal: TimeInterval = 0.2
    static let slow: TimeInterval = 0.3
}

// MARK: - Opacity Values

enum HoverOpacity {
    static let standard: Double = 0.08
    static let selected: Double = 0.12
    static let subtle: Double = 0.05
}
