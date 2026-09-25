import SwiftUI

struct FriendlyAuroraBackground: View {
  @State private var shifted = false

  var body: some View {
    ZStack {
      LinearGradient(
        colors: shifted
          ? [Color(red: 0.03, green: 0.12, blue: 0.28),
             Color(red: 0.06, green: 0.31, blue: 0.61),
             Color(red: 0.14, green: 0.48, blue: 0.76)]
          : [Color(red: 0.02, green: 0.10, blue: 0.24),
             Color(red: 0.08, green: 0.25, blue: 0.52),
             Color(red: 0.20, green: 0.56, blue: 0.78)],
        startPoint: shifted ? .topLeading : .bottomLeading,
        endPoint: shifted ? .bottomTrailing : .topTrailing
      )

      Circle()
        .fill(.cyan.opacity(0.26))
        .frame(width: 420, height: 420)
        .blur(radius: 110)
        .offset(x: shifted ? 160 : -160, y: shifted ? -300 : 220)

      Circle()
        .fill(Color(red: 0.20, green: 0.18, blue: 0.70).opacity(0.32))
        .frame(width: 360, height: 360)
        .blur(radius: 100)
        .offset(x: shifted ? -150 : 130, y: shifted ? 280 : -220)

      LinearGradient(
        colors: [.clear, .black.opacity(0.18)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .ignoresSafeArea()
    .onAppear {
      withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
        shifted = true
      }
    }
    .allowsHitTesting(false)
  }
}
