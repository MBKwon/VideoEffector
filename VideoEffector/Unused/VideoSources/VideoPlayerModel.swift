//
//  VideoPlayerModel.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/2/25.
//

import AVFoundation
import Combine
import CoreVideo

class VideoPlayerModel: PixelBufferProvider {

    private(set) var url: URL
    private(set) var player: AVPlayer
    private(set) var videoOutput: AVPlayerItemVideoOutput?

    private var displayLink: CADisplayLink?

    init(url: URL) {
        self.url = url
        self.player = AVPlayer(url: url)
        super.init()

        setupVideo(from: self.player)
        self.player.play()
    }

    private func setupVideo(from player: AVPlayer) {
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        self.videoOutput = output

        if let item = player.currentItem {
            item.add(output)
        } else {
            print("No currentItem on player when adding videoOutput")
        }

        // 렌더링 루프
        let link = CADisplayLink(target: self, selector: #selector(updatePixelBuffer))
        link.add(to: .main, forMode: .default)
        self.displayLink = link
    }

    @objc private func updatePixelBuffer() {
        guard let videoOutput = self.videoOutput else { return }

        // 호스트 시간 기반으로 itemTime 계산 (동기화 강화)
        let hostTime = CACurrentMediaTime()
        let itemTime = videoOutput.itemTime(forHostTime: hostTime)

        guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime) else { return }
        pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
    }
}
