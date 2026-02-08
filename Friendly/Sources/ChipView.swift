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
            Color(red: 1.0, green: 0.7, blue: 0.7),
            Color(red: 1.0, green: 0.85, blue: 0.6),
            Color(red: 1.0, green: 0.95, blue: 0.7),
            Color(red: 0.8, green: 1.0, blue: 0.7),
            Color(red: 0.7, green: 1.0, blue: 0.85),
            Color(red: 0.7, green: 0.9, blue: 1.0),
            Color(red: 0.8, green: 0.75, blue: 1.0),
            Color(red: 0.95, green: 0.75, blue: 1.0),
            Color(red: 1.0, green: 0.75, blue: 0.9),
            Color(red: 0.9, green: 0.85, blue: 0.75),
        ]

        let darkPastels = [
            Color(red: 0.6, green: 0.25, blue: 0.25),
            Color(red: 0.6, green: 0.4, blue: 0.2),
            Color(red: 0.55, green: 0.5, blue: 0.2),
            Color(red: 0.35, green: 0.5, blue: 0.25),
            Color(red: 0.25, green: 0.5, blue: 0.4),
            Color(red: 0.25, green: 0.4, blue: 0.6),
            Color(red: 0.35, green: 0.3, blue: 0.55),
            Color(red: 0.5, green: 0.3, blue: 0.55),
            Color(red: 0.6, green: 0.3, blue: 0.45),
            Color(red: 0.5, green: 0.4, blue: 0.3),
        ]
        let colors = colorScheme == .dark ? darkPastels : lightPastels
        let sum = text.utf8.reduce(0) { acc, byte in
            (acc &* 31 &+ Int(byte)) & 0x7FFFFFFF
        }
        let index = sum % colors.count
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

