//
//  QRScannerPermissionViewModel.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import CameraPermissionService
import Dependencies
import Observation

@MainActor @Observable
final class QRScannerPermissionViewModel {

    var showScanner = false
    var showSettingsAlert = false

    @ObservationIgnored @Dependency(CameraPermissionService.self) private var cameraPermissionService

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

            }
        }
    }
}
