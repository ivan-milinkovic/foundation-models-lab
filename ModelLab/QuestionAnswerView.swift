//
//  QuestionAnswerView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
import FoundationModels
import Observation
import Combine

struct QuestionAnswerView: View {
    
    @State private var input: String = ""
    @State private var model = QuestionAnswerModel.shared
    @State private var outHeight: CGFloat = 0
    
    var body: some View {
        VStack {
            Text("Question - Answer")
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
            
            TextEditor(text: $input)
                .font(.system(size: 16))
                .frame(height: 50)
                .border(Color(white: 0.25))
            
            if model.isResponding {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Button("Send") { submit() }
                    // .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .disabled(model.isResponding)
        .padding()
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
    QuestionAnswerView()
}

@Observable
final class QuestionAnswerModel {
    static let shared = QuestionAnswerModel()
    @ObservationIgnored private let model: SystemLanguageModel
    @ObservationIgnored private let session: LanguageModelSession
    private(set) var history = ""
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
    
    func prompt(_ prompt: String) async -> Bool {
        isResponding = true
        defer { isResponding = false }
        do {
            let response = try await session.respond(to: prompt)
            history += "Q: " + prompt + "\n"
            history += "A: " + response.content + "\n"
            return true
        } catch {
            history += "Error: " + error.localizedDescription + "\n"
            return false
        }
    }
}
