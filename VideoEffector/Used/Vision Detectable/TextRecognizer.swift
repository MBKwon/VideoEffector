//
//  TextRecognizer.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/4/25.
//

import CoreVideo
import NaturalLanguage
import SwiftUI
import Vision

final class TextRecognizer {
    private let textRecognitionRequest = VNRecognizeTextRequest()
    private let requestHandler = VNSequenceRequestHandler()
    private var textBinding: Binding<String>

    init(with text: Binding<String>) {
        textBinding = text
    }
}

extension TextRecognizer: Detectable {
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNDetectedObjectObservation] {
        do {
            let targetString = textBinding.wrappedValue
            let dominantLanguage = NLLanguageRecognizer
                .dominantLanguage(for: targetString)?.rawValue

            // 언어 및 정확도 옵션 설정
            textRecognitionRequest.recognitionLevel = .fast
            textRecognitionRequest.usesLanguageCorrection = true
            if let dominantLanguage = dominantLanguage {
                textRecognitionRequest.recognitionLanguages = [dominantLanguage]
            }

            try requestHandler.perform([textRecognitionRequest], on: pixelBuffer)
            return (textRecognitionRequest.results ?? []).filter {
                print($0.topCandidates(5).map(\.string).joined(separator: " / "))
                guard let candidate = $0.topCandidates(1).first else { return false }
                let recognizedText = candidate.string
                return recognizedText.contains(targetString)
            }
        } catch {
            print("❌ Vision face detection failed:", error)
            return []
        }
    }
}



