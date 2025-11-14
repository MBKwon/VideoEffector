//
//  ContentView.swift
//  VideoEffector
//
//  Created by Moonbeom KWON on 10/24/25.
//
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var vm = VideoEffectorViewModel()
    @State private var isSessionAlive = false

    @State private var selectedURL: URL? = nil
    @State private var saveProgress: Double = 0.0

    @State private var position: Int = 0
    @State private var shaderType: Int = 0
    @State private var detectorType: Int = 0

    @State private var showWordSheet = false
    @State private var targetWord: String = ""

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                if let image = vm.previewImage, isSessionAlive {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(alignment: .center)
                        .cornerRadius(40)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.3)))
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .frame(height: 300, alignment: .center)
                        .overlay(Text("라이브 세션을 시작하세요").foregroundColor(.secondary))
                        .cornerRadius(12)
                }
            }

            Spacer()

            Picker("Camera Position", selection: $position) {
                Text("Front").tag(0)
                Text("Rear").tag(1)
            }
            .pickerStyle(.segmented)

            Picker("Shader", selection: $shaderType) {
                Text("Blur").tag(0)
                Text("Hightlight").tag(1)
            }
            .pickerStyle(.segmented)

            Picker("Detector Type", selection: $detectorType) {
                Text("Face").tag(0)
                Text("Charactor").tag(1)
                Text("Word").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: detectorType.self, initial: true) { oldValue, newValue in
                switch newValue {
                case 0:
                    self.vm.detectors = [FaceDetector()]
                case 1:
                    self.vm.detectors = [TextDetector()]
                case 2:
                    self.vm.detectors = [TextRecognizer(with: $targetWord)]
                    showWordSheet = true
                default:
                    self.vm.detectors = []
                }
            }

            HStack(spacing: 12) {
                Button("라이브 시작") {
                    isSessionAlive = true
                    vm.startVideoSession(with: .camera(position: .back))
                }
                .buttonStyle(.bordered)

                Button("라이브 종료") {
                    isSessionAlive = false
                    vm.stopVideoSession()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .sheet(isPresented: $showWordSheet) {
            ZStack {
                Color(white: 44.0/255.0).edgesIgnoringSafeArea(.all)
                TextField(text: $targetWord) {
                    Text("type a word")
                }
                .padding(.horizontal, 20.0)
            }.presentationDetents([.height(100.0)])
        }
        .onChange(of: selectedURL) { oldValue, newValue in
            if let url = newValue {
                vm.startVideoSession(with: .video(url: url))
            }
        }
    }
}
