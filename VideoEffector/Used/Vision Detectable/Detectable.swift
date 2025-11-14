//
//  Detectable.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/3/25.
//

import CoreVideo
import Vision

protocol Detectable {
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNDetectedObjectObservation]
}
