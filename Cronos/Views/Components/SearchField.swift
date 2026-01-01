import SwiftUI

struct SearchField: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Search jobs..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.buttonCornerRadius))
    }
}
