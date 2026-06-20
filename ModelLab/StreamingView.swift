//
//  StreamingView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
import FoundationModels
import Observation
import Combine

struct StreamingView: View {
    
    @State private var input: String = ""
    @State private var model = StreamingModel.shared
    @State private var outHeight: CGFloat = 0
    
    var body: some View {
        VStack {
            Text("Streaming Answer")
                .font(.title2)
            ScrollView {
                Text(model.history)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newValue in
                        self.outHeight = min(newValue, 200)
                    }
            }
            .defaultScrollAnchor(.bottom)
            .frame(height: outHeight)
            .frame(maxWidth: .infinity)
            
            if !model.inProgressAnswer.isEmpty {
                ScrollView {
                    Text(model.inProgressAnswer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
                .frame(maxHeight: 100)
                .frame(maxWidth: .infinity)
            }
            
            TextEditor(text: $input)
                .font(.system(size: 16))
                .frame(height: 50)
                .border(Color(white: 0.25))
            
            if model.isResponding {
                HStack {
                    ProgressView()
                        .frame(width: 24, height: 24)
                    Button("Stop") { model.cancel() }
                }
            } else {
                Button("Send") { submit() }
                    // .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
    }
    
    func submit() {
        model.prompt(input)
        input = ""
    }
    
}

#Preview {
    StreamingView()
}

@Observable
final class StreamingModel {
    static let shared = StreamingModel()
    @ObservationIgnored private let model: SystemLanguageModel
    @ObservationIgnored private let session: LanguageModelSession
    @ObservationIgnored private var task: Task<Void, Never>?
    private(set) var history = ""
    private(set) var inProgressAnswer = ""
    private(set) var isResponding = false
    
    init() {
        model = SystemLanguageModel.default
        // model = SystemLanguageModel(useCase: .contentTagging)
        switch model.availability {
        case .available:
            break
        case .unavailable(let unavailableReason):
            print("Model unavailable: \(unavailableReason)")
        }
        
        session = LanguageModelSession(
            model: model,
            tools: [],
            instructions: nil
        )
        
        session.prewarm()
    }
    
    func prompt(_ prompt: String) {
        isResponding = true
        task = Task {
            defer { isResponding = false }
            history += "Q: " + prompt + "\n"
            let stream = session.streamResponse(to: prompt)
            do {
                for try await partial in stream {
                    inProgressAnswer = partial.content
                    // if Task.isCancelled { break } // not reachable, on Task cancellation the stream just ends the loop
                }
            } catch {
                inProgressAnswer += "Error: " + error.localizedDescription + "\n"
            }
            history += "A: " + inProgressAnswer + "\n"
            inProgressAnswer = ""
        }
    }
    
    func cancel() {
        task?.cancel()
    }
}
