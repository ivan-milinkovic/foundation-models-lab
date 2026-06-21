//
//  TaggingView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
import FoundationModels
import Observation
import Combine

struct TaggingView: View {
    
    @State private var input: String = ""
    @State private var model = ContentTaggingModel.shared
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack {
            ScrollView {
                Text(model.history)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            
            TextEditor(text: $input)
                .font(.system(size: 16))
                .focused($focused)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.25))
                }
            
            HStack {
                if model.isResponding {
                    ProgressView()
                        .frame(width: 24, height: 24)
                }
                Button("Send") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isResponding)
            }
        }
        .navigationTitle("Tagging")
        .padding()
        .task {
            focused = true
        }
    }
    
    func submit() {
        Task {
            let ok = await model.prompt(input)
            if ok {
                input = ""
            }
        }
    }
    
}

#Preview {
    TaggingView()
}

@Observable
final class ContentTaggingModel {
    static let shared = ContentTaggingModel()
    @ObservationIgnored private let model: SystemLanguageModel
    @ObservationIgnored private let session: LanguageModelSession
    private(set) var history = ""
    private(set) var isResponding = false
    
    init() {
        model = SystemLanguageModel(useCase: .contentTagging)
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
    
    let generationOptions = GenerationOptions(sampling: nil, temperature: 1.0, maximumResponseTokens: 1024)
    
    func prompt(_ prompt: String) async -> Bool {
        isResponding = true
        defer { isResponding = false }
        do {
            // let response = try await session.respond(to: prompt)
            let response = try await session.respond(to: prompt, options: generationOptions)
            history += "Q: " + prompt + "\n"
            history += "A: " + response.content + "\n"
            return true
        } catch {
            history += "Error: " + error.localizedDescription + "\n"
            return false
        }
    }
}
