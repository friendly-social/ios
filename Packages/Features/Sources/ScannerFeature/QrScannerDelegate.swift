import AVFoundation

final class QrScannerDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
  let codes: AsyncStream<String>
  private let continuation: AsyncStream<String>.Continuation

  override init() {
    let stream = AsyncStream<String>.makeStream()
    codes = stream.stream
    continuation = stream.continuation
    super.init()
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let code = object.stringValue else { return }
    continuation.yield(code)
  }

  deinit {
    continuation.finish()
  }
}
