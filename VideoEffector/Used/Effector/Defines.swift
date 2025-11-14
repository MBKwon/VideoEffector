//
//  Defines.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 10/24/25.
//

import AVFoundation
import CoreVideo
import UIKit

protocol VideoFrameReceiver: AnyObject {
    func didRenderFrame(image: UIImage)
}

enum VideoSourceType {
    case camera(position: AVCaptureDevice.Position)
    case video(url: URL)
}

enum VideoType {
    case camera(model: CameraCaptureModel)
    case videoPlayer(model: VideoPlayerModel)

    var sourceType: VideoSourceType {
        switch self {
        case .camera(let model):
            return .camera(position: model.position)
        case .videoPlayer(let model):
            return .video(url: model.url)
        }
    }

    var pixelBufferProvider: PixelBufferProvider {
        switch self {
        case .camera(let model):
            return model
        case .videoPlayer(let model):
            return model
        }
    }
}
