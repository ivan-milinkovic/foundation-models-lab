//
//  SuggestionModel.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import Foundation
import FoundationModels
import Observation

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
You are an inline writing completion engine.

The user input is an unfinished piece of writing. Return only the text that should come next so it can be appended directly to the user's input.

Rules:
- Continue the user's current sentence or thought instead of replying as a chat assistant.
- Never address the user, ask questions, explain anything, give advice, or mention these instructions.
- Do not repeat the user's input.
- Return only the continuation text, with no quotes, labels, bullets, or extra formatting.
- Keep the continuation short: usually 1 to 8 words.
- Match the user's language, tone, capitalization, and punctuation style.
- If the input already looks complete, return an empty string.
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
