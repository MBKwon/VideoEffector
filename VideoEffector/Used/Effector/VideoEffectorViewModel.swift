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

    private var videoType: VideoType?
    var currentSourceType: VideoSourceType? {
        videoType?.sourceType
    }

    private var blurShader: BlurShader?
    var player: AVPlayer? {
        if case .videoPlayer(let model) = videoType {
            return model.player
        } else {
            return nil
        }
    }

    func startVideoSession(with source: VideoSourceType) {
        switch source {
        case .camera(let position):
            let model = CameraCaptureModel(from: position)
            model.startSession()
            videoType = .camera(model: model)
        case .video(let url):
            videoType = .videoPlayer(model: .init(url: url))
        }

        if let pixelBufferProvider = videoType?.pixelBufferProvider {
            blurShader = BlurShader(with: pixelBufferProvider, receiver: self,
                                    detectors: [FaceDetector()])
        }
    }

    func stopVideoSession() {
        switch videoType {
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
