import SwiftUI

extension UIImage {
    func resize(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio,
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
