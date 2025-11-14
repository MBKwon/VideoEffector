//
//  BlurShader.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/2/25.
//

import AVFoundation
import Combine
import CoreVideo
import MetalKit
import MetalPerformanceShaders
import UIKit
import Vision

final class BlurShader {
    private let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?

    private weak var frameReceiver: VideoFrameReceiver?

    private var cancellables: Set<AnyCancellable> = .init()

    init(with pixelBufferProvider: PixelBufferProvider, receiver: VideoFrameReceiver,
         detect: @escaping (CVPixelBuffer) -> [VNDetectedObjectObservation]) {
        self.frameReceiver = receiver

        setupMetal()
        pixelBufferProvider.$pixelBuffer
            .compactMap { $0 }
            .sink { [weak self] pixelBuffer in
                self?.drawFrame(with: pixelBuffer, observations: detect(pixelBuffer))
            }
            .store(in: &cancellables)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupMetal() {
        guard let device = device else {
            assertionFailure("MTLDevice is nil")
            return
        }
        commandQueue = device.makeCommandQueue()
        var cache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        if cacheStatus != kCVReturnSuccess {
            print("CVMetalTextureCacheCreate failed: \(cacheStatus)")
        }
        textureCache = cache
    }

    @objc private func drawFrame(with pixelBuffer: CVPixelBuffer, observations: [VNDetectedObjectObservation]) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let textureCache = textureCache else { return }

        var cvTextureOut: CVMetalTexture?
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm,
            width, height, 0, &cvTextureOut
        )

        guard status == kCVReturnSuccess, let cvTextureOut = cvTextureOut else {
            print("CVMetalTextureCacheCreateTextureFromImage failed: \(status), size: \(width)x\(height)")
            return
        }
        guard let inputTexture = CVMetalTextureGetTexture(cvTextureOut) else { return }
        guard let device = device else {
            assertionFailure("MTLDevice is nil")
            return
        }

        let boundaries = observations
            .map(\.boundingBox)
            .map {
                var rect = VNImageRectForNormalizedRect($0, Int(width), Int(height))
                rect.origin.y = CGFloat(height) - rect.origin.y - rect.height
                return rect
            }

        if let blurredTex = blurTexture(device: device, commandBuffer: commandBuffer,
                                        sourceTexture: inputTexture, blurSigma: 10.0,
                                        boundaries: boundaries) {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            if let image = blurredTex.image {
                // delegate에 프레임 전달
                frameReceiver?.didRenderFrame(image: image)
            }
        }
    }
    
    private func blurTexture(device: MTLDevice,
                             commandBuffer: MTLCommandBuffer,
                             sourceTexture: MTLTexture,
                             blurSigma: Float = 10.0,
                             boundaries: [CGRect] = [],
                             tileSize: Int = 1024) -> MTLTexture? {

        // Destination texture (same size/format as source)
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: sourceTexture.pixelFormat,
            width: sourceTexture.width,
            height: sourceTexture.height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        guard let outputTexture = device.makeTexture(descriptor: desc) else { return nil }

        // MPS Gaussian blur kernel
        let blurKernel = MPSImageGaussianBlur(device: device, sigma: blurSigma)
        blurKernel.edgeMode = .clamp

        if boundaries.count > 0 {

            // Compute boundaries
            for rect in boundaries {

                print(rect)

                // 1️⃣ 전체 이미지를 복사
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()
                let fullSize = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1)
                blitEncoder?.copy(from: sourceTexture,
                                  sourceSlice: 0, sourceLevel: 0,
                                  sourceOrigin: .init(x: 0, y: 0, z: 0),
                                  sourceSize: fullSize,
                                  to: outputTexture,
                                  destinationSlice: 0, destinationLevel: 0,
                                  destinationOrigin: .init(x: 0, y: 0, z: 0))
                blitEncoder?.endEncoding()

                let intWidth = Int(rect.width)
                let intHeight = Int(rect.height)
                guard intWidth > 0,  intHeight > 0 else { continue }

                // 2️⃣ ROI 부분만 블러 처리
                let roiDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm,
                    width: intWidth,
                    height: intHeight,
                    mipmapped: false
                )
                roiDescriptor.usage = [.shaderRead, .shaderWrite]

                guard let roiSrcTexture = device.makeTexture(descriptor: roiDescriptor),
                      let roiDestTexture = device.makeTexture(descriptor: roiDescriptor) else { return nil }

                let originX = max(0, Int(rect.origin.x))
                let originY = max(0, Int(rect.origin.y))

                let srcWidth: Int
                let srcHeight: Int

                if sourceTexture.width < originX + intWidth {
                    srcWidth = min(sourceTexture.width, sourceTexture.width - originX)
                } else {
                    srcWidth = intWidth
                }

                if sourceTexture.height < originY + intHeight {
                    srcHeight = min(sourceTexture.height, sourceTexture.height - originY)
                } else {
                    srcHeight = intHeight
                }

                let roiOrigin = MTLOrigin(x: originX, y: originY, z: 0)
                let roiSize = MTLSize(width: srcWidth, height: srcHeight, depth: 1)

                let copyEncoder = commandBuffer.makeBlitCommandEncoder()
                copyEncoder?.copy(from: sourceTexture,
                                  sourceSlice: 0,
                                  sourceLevel: 0,
                                  sourceOrigin: roiOrigin,
                                  sourceSize: roiSize,
                                  to: roiSrcTexture,
                                  destinationSlice: 0,
                                  destinationLevel: 0,
                                  destinationOrigin: .init(x: 0, y: 0, z: 0))
                copyEncoder?.endEncoding()

                // 블러 적용
                blurKernel.encode(commandBuffer: commandBuffer,
                                  sourceTexture: roiSrcTexture,
                                  destinationTexture: roiDestTexture)

                // 3️⃣ 블러된 ROI를 다시 출력 텍스처에 합성
                let mergeEncoder = commandBuffer.makeBlitCommandEncoder()
                mergeEncoder?.copy(from: roiDestTexture,
                                   sourceSlice: 0,
                                   sourceLevel: 0,
                                   sourceOrigin: .init(x: 0, y: 0, z: 0),
                                   sourceSize: roiSize,
                                   to: outputTexture,
                                   destinationSlice: 0,
                                   destinationLevel: 0,
                                   destinationOrigin: roiOrigin)
                mergeEncoder?.endEncoding()
            }

        } else {

            // Compute tile grid
            let cols = (sourceTexture.width + tileSize - 1) / tileSize
            let rows = (sourceTexture.height + tileSize - 1) / tileSize

            // Compute overlap radius from sigma. A common rule of thumb is ~3*sigma for Gaussian support.
            let overlap: Int = max(0, Int(ceil(3.0 * Double(blurSigma))))

            for y in 0..<rows {
                for x in 0..<cols {
                    // Core (non-overlapped) tile region in source/dest
                    let coreOriginX = x * tileSize
                    let coreOriginY = y * tileSize
                    let coreWidth = min(tileSize, sourceTexture.width - coreOriginX)
                    let coreHeight = min(tileSize, sourceTexture.height - coreOriginY)

                    // Expanded (padded) source region including overlap, clamped to image bounds
                    let srcOriginX = max(0, coreOriginX - overlap)
                    let srcOriginY = max(0, coreOriginY - overlap)
                    let srcEndX = min(sourceTexture.width, coreOriginX + coreWidth + overlap)
                    let srcEndY = min(sourceTexture.height, coreOriginY + coreHeight + overlap)
                    let srcWidth = max(0, srcEndX - srcOriginX)
                    let srcHeight = max(0, srcEndY - srcOriginY)

                    // Create temporary textures for padded tile src/dst
                    let paddedDesc = MTLTextureDescriptor.texture2DDescriptor(
                        pixelFormat: sourceTexture.pixelFormat,
                        width: srcWidth,
                        height: srcHeight,
                        mipmapped: false
                    )
                    paddedDesc.usage = [.shaderRead, .shaderWrite]

                    guard srcWidth > 0, srcHeight > 0,
                          let tileSrc = device.makeTexture(descriptor: paddedDesc),
                          let tileDst = device.makeTexture(descriptor: paddedDesc) else { continue }

                    // Copy padded region from source into tileSrc
                    if let tileBlitEncoder = commandBuffer.makeBlitCommandEncoder() {
                        tileBlitEncoder.copy(
                            from: sourceTexture,
                            sourceSlice: 0, sourceLevel: 0,
                            sourceOrigin: MTLOrigin(x: srcOriginX, y: srcOriginY, z: 0),
                            sourceSize: MTLSize(width: srcWidth, height: srcHeight, depth: 1),
                            to: tileSrc,
                            destinationSlice: 0, destinationLevel: 0,
                            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
                        )
                        tileBlitEncoder.endEncoding()
                    }

                    // Run Gaussian blur on the padded tile
                    blurKernel.encode(commandBuffer: commandBuffer, sourceTexture: tileSrc, destinationTexture: tileDst)

                    // Now copy only the core (non-overlapped) subregion from tileDst back into the correct place in dest
                    // Compute the core region's origin inside the padded texture
                    let coreInPaddedOriginX = coreOriginX - srcOriginX
                    let coreInPaddedOriginY = coreOriginY - srcOriginY

                    if let destBlitEncoder = commandBuffer.makeBlitCommandEncoder() {
                        destBlitEncoder.copy(
                            from: tileDst,
                            sourceSlice: 0, sourceLevel: 0,
                            sourceOrigin: MTLOrigin(x: coreInPaddedOriginX, y: coreInPaddedOriginY, z: 0),
                            sourceSize: MTLSize(width: coreWidth, height: coreHeight, depth: 1),
                            to: outputTexture,
                            destinationSlice: 0, destinationLevel: 0,
                            destinationOrigin: MTLOrigin(x: coreOriginX, y: coreOriginY, z: 0)
                        )
                        destBlitEncoder.endEncoding()
                    }
                }
            }
        }

        return outputTexture
    }
}

private extension MTLTexture {
    var image: UIImage? {
        let width = self.width
        let height = self.height
        let rowBytes = width * 4
        let length = rowBytes * height
        var rawData = [UInt8](repeating: 0, count: length)

        let region = MTLRegionMake2D(0, 0, width, height)
        self.getBytes(&rawData, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // ✅ BGRA 포맷에 맞게 bitmapInfo 설정
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedFirst.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue
        )

        guard let ctx = CGContext(data: &rawData,
                                  width: width, height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: rowBytes,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue),
              let cgImage = ctx.makeImage() else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
