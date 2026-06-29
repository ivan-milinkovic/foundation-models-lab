//
//  VisionViewModel.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 29. 6. 2026.
//

import Foundation
import Observation
import Vision
@preconcurrency import AVFoundation

@Observable @MainActor final class VisionViewModel {
    @ObservationIgnored let cameraService = CameraService()
    @ObservationIgnored var detectionRequest: VNImageBasedRequest?
    @ObservationIgnored var orientation = CGImagePropertyOrientation.leftMirrored
    var session: AVCaptureSession?
    var message: String?
    var detectionType: DetectionType = .face
    
    var bodyPoseGroups: [DetectionGroup] = []
    var faceGroups: [DetectionGroup] = []
    
    var eyePoint: CGPoint = .zero
    var eyeHistory: [CGPoint] = .init(repeating: .zero, count: 64)
    let eyesHistoryDeltaTime: TimeInterval = 0.033
    var eyesLastHistoryDate: Date = Date()
    
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
        bodyPoseGroups = try observations
            .filter { $0.confidence > 0.4 }
            .map {
                let dict = try $0.recognizedPoints(.all)
                let points = dict.map { (k,v) in DetectionPoint(name: k.rawValue.rawValue, coords: v.location) }
                return DetectionGroup(points: points)
            }
    }
    
    func processFaceLandmarks(_ observations: [VNFaceObservation]) {
        faceGroups = observations.compactMap { face in
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
        guard let face = observations.first(where: { $0.landmarks?.leftEye != nil }),
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
        eyePoint = leftEyeCentroid
        
        if Date().timeIntervalSince(eyesLastHistoryDate) >= eyesHistoryDeltaTime
            // && (abs(leftEyeCentroid.x - eyeHistory[0].x) > 5 || abs(leftEyeCentroid.y - eyeHistory[0].y) > 5)
        {
            for i in 0..<eyeHistory.count-1 {
                eyeHistory[i+1] = eyeHistory[i]
            }
            eyeHistory[0] = leftEyeCentroid
            eyesLastHistoryDate = Date()
        }
        
    }
    
    func start() async {
        await cameraService.start()
    }
    
    func stop() async {
        await cameraService.stop()
    }
    
}
