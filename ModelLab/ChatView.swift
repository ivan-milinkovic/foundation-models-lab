//
//  ChatView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
import FoundationModels
import Observation
import Combine

struct ChatView: View {
    
    @State private var input: String = ""
    @State private var model = ChatModel.shared
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack {
            ScrollView {
                Text(model.history)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
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
                .focused($focused)
                .frame(height: 50)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.25))
                }
            
            if model.isResponding {
                HStack {
                    ProgressView()
                        .frame(width: 24, height: 24)
                    Button("Stop") { model.cancel() }
                        .keyboardShortcut(".", modifiers: .command)
                }
            } else {
                Button("Send") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .navigationTitle("Chat")
        .padding()
        .task {
            focused = true
        }
    }
    
    func submit() {
        model.prompt(input)
        input = ""
    }
    
}

#Preview {
    ChatView()
}

@Observable
final class ChatModel {
    static let shared = ChatModel()
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
            history = "Model unavailable: \(unavailableReason)"
        }
        
        session = LanguageModelSession(
            model: model,
            tools: [],
            instructions: nil
        )
        
        session.prewarm()
    }
    
    let generationOptions = GenerationOptions(sampling: .none, temperature: 1.0, maximumResponseTokens: 1024)
    
    func prompt(_ prompt: String) {
        isResponding = true
        task = Task {
            defer { isResponding = false }
            history += "Q: " + prompt + "\n"
            // let stream = session.streamResponse(to: prompt)
            let stream = session.streamResponse(to: prompt, options: generationOptions)
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
