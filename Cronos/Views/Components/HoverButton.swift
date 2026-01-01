import SwiftUI

/// Reusable button with standardized hover effect
struct HoverButton: View {
    let systemImage: String
    var iconSize: CGFloat = 12
    var help: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: LayoutConstants.buttonCornerRadius)
                .fill(Color.primary.opacity(isHovered ? HoverOpacity.standard : 0))
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: AnimationDurations.fast), value: isHovered)
        .help(help ?? "")
    }
}
