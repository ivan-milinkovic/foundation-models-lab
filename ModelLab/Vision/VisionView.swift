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
                camera(session: captureSession)
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
                    Text("Eyes").tag(VisionViewModel.DetectionType.eyes)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private func camera(session: AVCaptureSession) -> some View {
        CameraPreview(session: session)
            .overlay {
                switch viewModel.detectionType {
                case .face: points
                case .pose: points
                case .eyes: linesHistory
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
    
    @ViewBuilder private var pointsHistory: some View {
        Canvas { ctx, size in
            let dotSize = 4.0
            let color = colors[1]
            for (i, point) in viewModel.eyeHistory.enumerated() {
                let opacity = 0.5 * (1 - Double(i) / Double(viewModel.eyeHistory.count))
                let x = point.x * size.width
                let y = (1 - point.y) * size.height
                let r = CGRect(x: x-dotSize/2, y: y-dotSize/2, width: dotSize, height: dotSize)
                ctx.fill(Path(ellipseIn: r), with: .color(color.opacity(opacity)))
            }
        }
    }
    
    @ViewBuilder private var linesHistory: some View {
        Canvas { ctx, size in
            let color = colors[1]
            var path = Path()
            for (i, point) in viewModel.eyeHistory.enumerated() {
                let x = point.x * size.width
                let y = (1 - point.y) * size.height
                if i == 0 {
                    path.move(to: .init(x: x, y: y))
                } else {
                    path.addLine(to: .init(x: x, y: y))
                }
            }
            ctx.stroke(path, with: .color(color), style: .init(lineWidth: 8))
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
    
    var detectionGroups: [DetectionGroup] = []
    var eyeHistory: [CGPoint] = .init(repeating: .zero, count: 16)
    
    enum DetectionType: CaseIterable {
        case face, pose, eyes
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
        
        detectionRequest = makeRequest()
        defer { detectionRequest = nil}
        do {
            let imageHandler = VNImageRequestHandler(cmSampleBuffer: buffer.value, orientation: orientation)
            try imageHandler.perform([detectionRequest!])
            guard let observations = detectionRequest?.results else { return }
            try handle(observations: observations)
        } catch {
            message = error.localizedDescription
        }
    }
    
    private func makeRequest() -> VNImageBasedRequest {
        switch detectionType {
        case .pose:
            VNDetectHumanBodyPoseRequest()
        case .face, .eyes:
            VNDetectFaceLandmarksRequest()
        }
    }
    
    private func handle(observations: [VNObservation]) throws {
        switch detectionType {
        case .pose:
            try processBodyPose(observations as! [VNHumanBodyPoseObservation])
        case .face:
            processFaceLandmarks(observations as! [VNFaceObservation])
        case .eyes:
            processEyesLandmarks(observations as! [VNFaceObservation])
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
    
    func processBodyPose(_ observations: [VNHumanBodyPoseObservation]) throws {
        detectionGroups = try observations
            .filter { $0.confidence > 0.4 }
            .map {
                let dict = try $0.recognizedPoints(.all)
                let points = dict.map { (k,v) in DetectionPoint(name: k.rawValue.rawValue, coords: v.location) }
                return DetectionGroup(points: points)
            }
    }
    
    let dtBetweenSnapshots: TimeInterval = 0.04
    var lastSnapshotDate: Date = Date()
    let onePoint = false
    
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
    
    func processEyesLandmarks(_ observations: [VNFaceObservation]) {
        guard let face = observations.first,
              let leftEye: VNFaceLandmarkRegion2D = face.landmarks?.leftEye else { return }
        
        let points = leftEye.normalizedPoints
        guard !points.isEmpty else { return }
        let bbox = face.boundingBox
        let centroid = points.reduce(CGPoint.zero) { acc, point in
            CGPoint(x: acc.x + point.x,
                    y: acc.y + point.y)
        }
        let normalizedCentroid = CGPoint(
            x: centroid.x / CGFloat(points.count),
            y: centroid.y / CGFloat(points.count)
        )
        let leftEyeCentroid = CGPoint(
            x: bbox.minX + normalizedCentroid.x * bbox.width,
            y: bbox.minY + normalizedCentroid.y * bbox.height
        )
        
        eyeHistory.move(fromOffsets: IndexSet(integersIn: 0..<eyeHistory.count-1), toOffset: 1)
        eyeHistory[0] = leftEyeCentroid
    }
    
    func start() async {
        await cameraService.start()
    }
    
    func stop() async {
        await cameraService.stop()
    }
    
}

