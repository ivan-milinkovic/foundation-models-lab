//
//  VisionView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 27. 6. 2026.
//

import SwiftUI
import Observation
@preconcurrency import AVFoundation

struct VisionView: View {
    
    @State var viewModel = VisionViewModel()
    
    var body: some View {
        VStack {
            if let captureSession = viewModel.session {
                CameraPreview(session: captureSession)
                    .overlay(points)
                    .ignoresSafeArea()
            } else {
                ProgressView()
            }
            if let message = viewModel.message {
                Text(message)
            }
        }
        .task {
            await viewModel.setup()
        }
        .onAppear {
            Task { await viewModel.start() }
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Picker("", selection: $viewModel.detectionType) {
                    Text("Face").tag(VisionViewModel.DetectionType.face)
                    Text("Pose").tag(VisionViewModel.DetectionType.pose)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    @ViewBuilder private var points: some View {
        Canvas { ctx, size in
            for (i, group) in viewModel.detectionGroups.enumerated() {
                let color = colors[i % colors.count]
                for point in group.points {
                    let x = point.coords.x * size.width
                    let y = (1 - point.coords.y) * size.height
                    let r = CGRect(x: x-5, y: y-5, width: 10, height: 10)
                    ctx.fill(Path(ellipseIn: r), with: .color(color))
                    let r2 = CGRect(x: x-5, y: y-10, width: 200, height: 50)
                    ctx.draw(Text(point.name), in: r2)
                }
            }
        }
    }
    
    private let colors: [Color] = [.orange, .blue, .purple, .yellow]
}

#Preview {
    VisionView()
}


import Vision

@Observable @MainActor final class VisionViewModel {
    @ObservationIgnored let cameraService = CameraService()
    @ObservationIgnored var detectionRequest: VNImageBasedRequest?
    @ObservationIgnored var orientation = CGImagePropertyOrientation.leftMirrored
    var session: AVCaptureSession?
    var message: String?
    var detectionType: DetectionType = .face
    
    enum DetectionType: CaseIterable {
        case face, pose
    }
    
    func setup() async {
        do {
            try await cameraService.setup()
            self.session = await cameraService.getSession()?.value
            await cameraService.setCallback { buffer in
                Task { @Sendable in
                    await MainActor.run {
                        self.handleBuffer(buffer)
                    }
                }
            }
            await cameraService.start()
        } catch {
            message = error.localizedDescription
        }
    }
    
    func handleBuffer(_ buffer: SendableWrapper<CMSampleBuffer>) {
        guard detectionRequest == nil else {
            return
        }
        
        switch detectionType {
        case .pose:
            detectionRequest = VNDetectHumanBodyPoseRequest()
        case .face:
            detectionRequest = VNDetectFaceLandmarksRequest()
        }
        defer { detectionRequest = nil}
        
        let imageHandler = VNImageRequestHandler(cmSampleBuffer: buffer.value, orientation: orientation)
        do {
            try imageHandler.perform([detectionRequest!])
            guard let observations = detectionRequest?.results else { return }
            
            if let observations = observations as? [VNHumanBodyPoseObservation] {
                try processBodyPose(observations)
            } else if let observations = observations as? [VNFaceObservation] {
                processFaceLandmarks(observations)
            }
        } catch {
            message = error.localizedDescription
        }
    }
    
    struct DetectionGroup: Identifiable {
        let id = UUID()
        let points: [DetectionPoint]
    }
    
    struct DetectionPoint: Identifiable {
        let id = UUID()
        let name: String
        let coords: CGPoint
    }
    
    var detectionGroups: [DetectionGroup] = []
    
    func processBodyPose(_ observations: [VNHumanBodyPoseObservation]) throws {
        detectionGroups = try observations
            .filter { $0.confidence > 0.4 }
            .map {
                let dict = try $0.recognizedPoints(.all)
                let points = dict.map { (k,v) in DetectionPoint(name: k.rawValue.rawValue, coords: v.location) }
                return DetectionGroup(points: points)
            }
    }
    
    func processFaceLandmarks(_ observations: [VNFaceObservation]) {
        detectionGroups = observations.compactMap { face in
        guard let landmarks = face.landmarks,
              let allPoints = landmarks.allPoints else { return nil }
        let box = face.boundingBox
        let points = allPoints.normalizedPoints.map { pt in
            let imageX = box.minX + pt.x * box.width
            let imageY = box.minY + pt.y * box.height
            return DetectionPoint(name: "", coords: CGPoint(x: imageX, y: imageY))
        }
        return DetectionGroup(points: points)
    }
    }
    
    func start() async {
        await cameraService.start()
    }
    
    func stop() async {
        await cameraService.stop()
    }
    
}

