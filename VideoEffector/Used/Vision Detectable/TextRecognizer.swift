//
//  TextRecognizer.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 11/4/25.
//

import CoreVideo
import NaturalLanguage
import Vision

final class TextRecognizer {
    private let textRecognitionRequest = VNRecognizeTextRequest()
    private let requestHandler = VNSequenceRequestHandler()

    private var dominantLanguage: String?
    private var targetString: String {
        didSet {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(targetString)

            if let language = recognizer.dominantLanguage {
                dominantLanguage = language.rawValue
            } else {
                dominantLanguage = nil
            }
        }
    }

    init(with text: String) {
        targetString = text
    }

    func changeText(_ new: String) {
        targetString = new
    }
}

extension TextRecognizer: Detectable {
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [VNDetectedObjectObservation] {
        do {
            // 언어 및 정확도 옵션 설정
            textRecognitionRequest.recognitionLevel = .fast
            textRecognitionRequest.usesLanguageCorrection = true
            if let dominantLanguage = dominantLanguage {
                textRecognitionRequest.recognitionLanguages = [dominantLanguage]
            }

            try requestHandler.perform([textRecognitionRequest], on: pixelBuffer)
            return (textRecognitionRequest.results ?? []).filter {
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



