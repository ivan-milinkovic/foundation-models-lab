//
//  TaggingModel.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import Foundation
import FoundationModels
import Observation

@Generable
struct TaggingResult {
    @Guide(description: "3-5 words describing the content")
    let tags: [String]
}

@Observable @MainActor
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
            let response = try await session.respond(to: prompt, generating: TaggingResult.self, options: generationOptions)
            history += "Q: " + prompt + "\n\n"
            let res = response.content
            let tagsStr = res.tags.joined(separator: ", ")
            history += "A: " + tagsStr + "\n\n\n"
            return true
        } catch {
            history += "Error: " + error.localizedDescription + "\n"
            return false
        }
    }
}
