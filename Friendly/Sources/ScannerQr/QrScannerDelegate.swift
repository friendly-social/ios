//
//  QrScannerDelegate.swift
//  Friendly
//
//  Created by Konstantin on 04.02.2026.
//

import SwiftUI
import AVKit

class QrScannerDelegate: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scanndeCode: String?

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metaObject = metadataObjects.first {
            guard let readableObject = metaObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            scanndeCode = stringValue
        }
    }
}
