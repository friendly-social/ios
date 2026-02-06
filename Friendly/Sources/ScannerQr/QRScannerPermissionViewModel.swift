//
//  QRScannerPermissionViewModel.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import AVFoundation

final class CameraPermissionService {
    enum CameraAccessState: Equatable {
        case authorized
        case notDetermined
        case denied
        case restricted
    }

    func status() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

// Если нужно будет проверить доступы камеры до перехода на экран сканирования
@MainActor
final class QRScannerPermissionViewModel: ObservableObject {

    @Published var showScanner = false
    @Published var showSettingsAlert = false

    private let cameraPermissionService = CameraPermissionService()

    func handleScanTap() {
        Task {
            switch cameraPermissionService.status() {
            case .authorized:
                showScanner = true

            case .notDetermined:
                let granted = await cameraPermissionService.request()
                if granted {
                    showScanner = true
                } else {
                    showSettingsAlert = true
                }

            case .denied, .restricted:
                showSettingsAlert = true

            @unknown default:
                showSettingsAlert = true
            }
        }
    }
}
