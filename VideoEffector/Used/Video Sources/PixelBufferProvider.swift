//
//  PixelBufferProvider.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/14/25.
//

import Combine
import CoreVideo

class PixelBufferProvider: NSObject {
    @Published var pixelBuffer: CVPixelBuffer?
}
