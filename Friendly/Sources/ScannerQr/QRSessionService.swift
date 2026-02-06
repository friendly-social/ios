//
//  QRSessionService.swift
//  Friendly
//
//  Created by Konstantin on 05.02.2026.
//

import AVFoundation

enum CameraSessionError: Error, Equatable {
    case permissionDenied
    case noBackCamera
    case cannotAddInput
    case cannotAddOutput
    case configurationFailed
}

final class QRSessionService {
    private let sessionQueue = DispatchQueue(label: "qr.session.queue")
    private let permissionService: CameraPermissionService

    init(permissionService: CameraPermissionService = .init()) {
        self.permissionService = permissionService
    }

    private func runOnSessionQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

extension QRSessionService {
    func makeSession(
        metadataOutput: AVCaptureMetadataOutput,
        delegate: AVCaptureMetadataOutputObjectsDelegate,
        delegateQueue: DispatchQueue = .main
    ) async throws -> AVCaptureSession {

        switch permissionService.status() {
        case .authorized:
            break
        case .notDetermined:
            let granted = await permissionService.request()
            if !granted { throw CameraSessionError.permissionDenied }
        case .denied, .restricted:
            throw CameraSessionError.permissionDenied
        @unknown default:
            throw CameraSessionError.permissionDenied
        }

        return try await runOnSessionQueue {
            let session = AVCaptureSession()
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            session.sessionPreset = .high

            guard let device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            ).devices.first else {
                throw CameraSessionError.noBackCamera
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraSessionError.cannotAddInput
            }
            session.addInput(input)

            guard session.canAddOutput(metadataOutput) else {
                throw CameraSessionError.cannotAddOutput
            }
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(delegate, queue: delegateQueue)
            metadataOutput.metadataObjectTypes = [.qr]

            return session
        }
    }

    func startRunning(_ session: AVCaptureSession) {
        sessionQueue.async {
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stopRunning(_ session: AVCaptureSession) {
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}
