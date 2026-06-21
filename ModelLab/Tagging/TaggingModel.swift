//
//  TaggingModel.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import Foundation
import FoundationModels
import Observation

@Observable
final class TaggingModel {
    static let shared = TaggingModel()
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
