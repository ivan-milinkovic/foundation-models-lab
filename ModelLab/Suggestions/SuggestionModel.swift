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
