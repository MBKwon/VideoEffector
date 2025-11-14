//
//  VideoEffectorViewModel.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 10/24/25.
//

import AVFoundation
import Combine
import CoreImage
import SwiftUI

final class VideoEffectorViewModel: NSObject, ObservableObject {
    
    @Published var previewImage: UIImage?
    
    var detectors: [Detectable] = []
    private var videoProvider: VideoProviderType?
    var currentSourceType: VideoSourceType? {
        videoProvider?.sourceType
    }

    private var blurShader: BlurShader?
    var player: AVPlayer? {
        if case .videoPlayer(let model) = videoProvider {
            return model.player
        } else {
            return nil
        }
    }

    func startVideoSession(with source: VideoSourceType) {
        videoProvider = source.videoProvider
        if let pixelBufferProvider = videoProvider?.pixelBufferProvider {
            blurShader = BlurShader(with: pixelBufferProvider, receiver: self) { [weak self] pixelBuffer in
                guard let self else { return [] }
                return self.detectors.flatMap {
                    $0.detectObjects(pixelBuffer: pixelBuffer)
                }
            }
        }
    }

    func stopVideoSession() {
        switch videoProvider {
        case .camera(let model):
            model.stopSession()
        case .videoPlayer(let model):
            model.player.pause()
        case .none:
            break
        }
    }
}

extension VideoEffectorViewModel: VideoFrameReceiver {
    func didRenderFrame(image: UIImage) {
        DispatchQueue.main.async {
            self.previewImage = image
        }
    }
}
