import AVFoundation
import CameraPermissionService
import Foundation
import UIKit

struct CameraPermissionServiceLive {
  func status() -> CameraPermissionService.AccessState {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: .authorized
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .restricted: .restricted
    @unknown default: .denied
    }
  }

  func request() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }

  func settingsURL() -> URL? { URL(string: UIApplication.openSettingsURLString) }
}
