//
//  VisionView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 27. 6. 2026.
//

import SwiftUI
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
                case .face: facePoints
                case .pose: bodyPosePoints
                case .eyes: eyeLines
                }
            }
    }
    
    @ViewBuilder private var bodyPosePoints: some View {
        Canvas { ctx, size in
            for (i, group) in viewModel.bodyPoseGroups.enumerated() {
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
    
    @ViewBuilder private var facePoints: some View {
        let dotSize = 7.0
        Canvas { ctx, size in
            for (i, group) in viewModel.faceGroups.enumerated() {
                let color = colors[i % colors.count]
                for point in group.points {
                    let x = point.coords.x * size.width
                    let y = (1 - point.coords.y) * size.height
                    let r = CGRect(x: x-dotSize/2, y: y-dotSize/2, width: dotSize, height: dotSize)
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
    
    @ViewBuilder private var eyeLines: some View {
        Canvas { ctx, size in
            let color = colors[1]
            
            let eyePoint = CGPoint(x: viewModel.eyePoint.x * size.width,
                                   y: (1-viewModel.eyePoint.y) * size.height)
            let r = CGRect(origin: eyePoint,
                           size: CGSize(width: 8, height: 8))
            ctx.fill(Path(ellipseIn: r), with: .color(color))
                     
            var path = Path()
            path.move(to: eyePoint)
            for (_, point) in viewModel.eyeHistory.enumerated() {
               let x = point.x * size.width
               let y = (1 - point.y) * size.height
               path.addLine(to: .init(x: x, y: y))
            }
            ctx.stroke(path, with: .color(color), style: .init(lineWidth: 8))
        }
    }
    
    private let colors: [Color] = [.orange, .blue, .purple, .yellow]
}

#Preview {
    VisionView()
}
