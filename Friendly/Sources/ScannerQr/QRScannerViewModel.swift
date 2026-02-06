//
//  QRScannerViewModel.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import SwiftUI
import AVFoundation

@MainActor
final class QRScannerViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case running
        case noPermission
        case ioError
    }

    @Published var state: State = .idle
    @Published var session: AVCaptureSession?

    let qrOutput = AVCaptureMetadataOutput()

    private let service = QRSessionService()
    private let qrDelegate: AVCaptureMetadataOutputObjectsDelegate
    private let onDismiss: (String?) -> Void

    init(qrDelegate: AVCaptureMetadataOutputObjectsDelegate,
         onDismiss: @escaping (String?) -> Void) {
        self.qrDelegate = qrDelegate
        self.onDismiss = onDismiss
    }

    var sessionBinding: Binding<AVCaptureSession> {
        Binding(
            get: { self.session ?? AVCaptureSession() },
            set: { _ in /* session не меняем из View */ }
        )
    }

    func prepare() {
        Task {
            state = .loading
            do {
                let configuredSession = try await service.makeSession(
                    metadataOutput: qrOutput,
                    delegate: qrDelegate,
                    delegateQueue: .main
                )
                self.session = configuredSession
                service.startRunning(configuredSession)
                state = .running
            } catch let err as CameraSessionError {
                switch err {
                case .permissionDenied:
                    state = .noPermission
                default:
                    state = .ioError
                }
            } catch {
                state = .ioError
            }
        }
    }

    func stop() {
        guard let session else { return }
        service.stopRunning(session)
    }

    func didScan(code: String) {
        stop()
        onDismiss(code)
    }

    func onDismiss(code: String?) {
        stop()
        onDismiss(code)
    }
}
