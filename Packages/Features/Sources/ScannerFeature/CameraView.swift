import AVFoundation
import SwiftUI
import UIKit

struct CameraView: UIViewRepresentable {
  private let session: AVCaptureSession

  init(session: AVCaptureSession) {
    self.session = session
  }

  func makeUIView(context: Context) -> Preview {
    let view = Preview()
    view.cameraLayer.videoGravity = .resizeAspectFill
    view.cameraLayer.session = session
    return view
  }

  func updateUIView(_ view: Preview, context: Context) {
    if view.cameraLayer.session !== session { view.cameraLayer.session = session }
  }

  final class Preview: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  }
}

private extension CameraView.Preview {
  var cameraLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
