//
//  CameraCaptureModel.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/2/25.
//

import AVFoundation
import Combine
import CoreVideo
import UIKit

final class CameraCaptureModel: PixelBufferProvider {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private(set) var position: AVCaptureDevice.Position = .back

    private override init() { super.init() }
    init(from position: AVCaptureDevice.Position) {
        super.init()
        setupCamera(from: position)
    }

    func startSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

private extension CameraCaptureModel {
    func setupCamera(from position: AVCaptureDevice.Position) {
        captureSession.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: position),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("❌ Failed to create AVCaptureDeviceInput")
            return
        }

        // Add input
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Configure video output to deliver CVPixelBuffers
        let queue = DispatchQueue(label: "camera.queue")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        // Pixel format — CVPixelBuffer will have this format
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                NSNumber(value: kCVPixelFormatType_32BGRA)
        ]

        // Add output
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Configure connection orientation and mirroring
        if let connection = videoOutput.connection(with: .video) {
            let deviceOrientation = UIDevice.current.orientation
            switch deviceOrientation {
            case .portrait:
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            case .landscapeLeft: break
            case .landscapeRight: break
            case .portraitUpsideDown: break
            default: break
            }

            if position == .front, connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }
}

extension CameraCaptureModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Extract CVPixelBuffer here
        // At this point you can send the CVPixelBuffer to:
        self.pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    }
}
