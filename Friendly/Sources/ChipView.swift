import SwiftUI

struct ChipView: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    init(
        text: String,
        isSelected: Bool = true,
        action: @escaping () -> Void = {},
    ) {
        self.text = text
        self.isSelected = isSelected
        self.action = action
    }

    @Environment(\.colorScheme) var colorScheme

    private var pastelColor: Color {
        let lightPastels = [
            Color(red: 1.0, green: 0.8, blue: 0.8),
            Color(red: 0.8, green: 0.9, blue: 1.0),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.7),
            Color(red: 0.95, green: 0.8, blue: 1.0),
        ]
        let darkPastels = [
            Color(red: 0.6, green: 0.3, blue: 0.3),
            Color(red: 0.3, green: 0.4, blue: 0.6),
            Color(red: 0.35, green: 0.45, blue: 0.35),
            Color(red: 0.6, green: 0.5, blue: 0.3),
            Color(red: 0.5, green: 0.3, blue: 0.6),
        ]
        let colors = colorScheme == .dark ? darkPastels : lightPastels
        let sum = text.unicodeScalars.reduce(0) { acc, scalar in
            acc + Int(scalar.value)
        }
        let index = abs(sum) % colors.count
        return colors[index]
    }

    var body: some View {
        Button(action: action) {
            if isSelected {
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(pastelColor)
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
            } else {
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(pastelColor.opacity(0.5))
                    .foregroundColor(.primary.opacity(0.5))
                    .clipShape(Capsule())
            }
        }
    }
}

