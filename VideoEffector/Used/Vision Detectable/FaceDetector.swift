//
//  FaceDetector.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/3/25.
//

import CoreVideo
import Vision

final class FaceDetector {
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private let requestHandler = VNSequenceRequestHandler()
}

extension FaceDetector: Detectable {
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNDetectedObjectObservation] {
        do {
            try requestHandler.perform([faceDetectionRequest], on: pixelBuffer)
            return faceDetectionRequest.results ?? []
        } catch {
            print("❌ Vision face detection failed:", error)
            return []
        }
    }
}
