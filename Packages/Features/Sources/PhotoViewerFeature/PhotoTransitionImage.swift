import SwiftUI

struct PhotoTransitionImage: View {
  let image: Image
  let size: CGSize
  let cornerRadius: CGFloat
  let fillsSource: Bool

  var body: some View {
    image.resizable()
      .aspectRatio(contentMode: fillsSource ? .fill : .fit)
      .frame(width: size.width, height: size.height)
      .clipShape(.rect(cornerRadius: cornerRadius))
  }
}
