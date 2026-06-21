//
//  SuggestionView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
import FoundationModels
import Observation
import Combine

struct SuggestionView: View {
    
    @State private var input: String = ""
    @State private var model = SuggestionModel.shared
    @State private var inputHandler = InputHandler()
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack {
            TextEditor(text: $input)
                .font(.system(size: 16))
                .focused($focused)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.25))
                }
            
            HStack {
                Button(model.suggestion) {
                    input += " " + model.suggestion
                }
                .frame(height: 40)
                .keyboardShortcut(.return, modifiers: .command)
                
                Spacer()
                
                if model.isResponding {
                    ProgressView()
                        .frame(width: 24, height: 24)
                }
            }
        }
        .navigationTitle("Suggestions")
        .padding()
        .onChange(of: input, { oldValue, newValue in
            inputHandler.subject.send(input)
        })
        .onReceive(inputHandler.debounced) { input in
            model.prompt(input)
        }
        .task {
            focused = true
        }
    }
    
    final class InputHandler {
        private(set) var subject = PassthroughSubject<String, Never>()
        private(set) var debounced: AnyPublisher<String, Never>
        
        init() {
            subject = PassthroughSubject<String, Never>()
            debounced = subject.debounce(for: .seconds(1), scheduler: DispatchQueue.main).eraseToAnyPublisher()
        }
    }
}

#Preview {
    SuggestionView()
}

@Observable
final class SuggestionModel {
    
    static let shared = SuggestionModel()
    
    @ObservationIgnored private let model: SystemLanguageModel
    @ObservationIgnored private let session: LanguageModelSession
    
    private(set) var suggestion = ""
    private(set) var isResponding = false
    
    init() {
        model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let unavailableReason):
            print("Model unavailable: \(unavailableReason)")
            suggestion = "Model unavailable: \(unavailableReason)"
        }
        
        session = LanguageModelSession(
            model: model,
            tools: [],
            instructions: 
                """
Your role is to help user type, by providing typing suggestions based on user input. Your output should be a string of text that completes the input. Do not ask for clarifications, and do not repeat input, but only provide the next word or phrase. Limit to only a few words.
"""
        )
        
        session.prewarm()
    }
    
    let generationOptions = GenerationOptions(sampling: .none, temperature: 1.0, maximumResponseTokens: 256)
    
    func prompt(_ prompt: String) {
        guard !prompt.isEmpty else {
            suggestion = ""
            return
        }
        guard !isResponding else { return }
        isResponding = true
        Task {
            defer { isResponding = false }
            do {
                 // let response = try await session.respond(to: prompt)
                 let response = try await session.respond(to: prompt, options: generationOptions)
                 suggestion = response.content
            } catch {
                suggestion = error.localizedDescription
            }
        }
    }
}
