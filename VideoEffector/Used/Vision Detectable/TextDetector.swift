//
//  TextDetector.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/3/25.
//

import CoreVideo
import Vision

final class TextDetector {
    private let textDetectionRequest = {
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = true
        return request
    }()
    private let requestHandler = VNSequenceRequestHandler()
}

extension TextDetector: Detectable {
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNDetectedObjectObservation] {
        do {
            try requestHandler.perform([textDetectionRequest], on: pixelBuffer)
            return textDetectionRequest.results ?? []
        } catch {
            print("❌ Vision face detection failed:", error)
            return []
        }
    }
}

