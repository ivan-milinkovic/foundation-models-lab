//
//  ChatModel.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import Foundation
import FoundationModels
import Observation

@Observable
final class ChatModel {
    static let shared = ChatModel()
    @ObservationIgnored private let model: SystemLanguageModel
    @ObservationIgnored private let session: LanguageModelSession
    @ObservationIgnored private var task: Task<Void, Never>?
    private(set) var isResponding = false
    private(set) var messages: [Message] = []
    
    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        let content: String
    }
    
    enum Role {
        case user, model
    }
    
    init() {
        model = SystemLanguageModel.default
        var errorMessage: String?
        switch model.availability {
        case .available:
            break
        case .unavailable(let unavailableReason):
            errorMessage = "Model unavailable: \(unavailableReason)"
        }
        
        session = LanguageModelSession(
            model: model,
            tools: [],
            instructions: nil
        )
        
        if let errorMessage {
            messages.append(Message(role: .model, content: errorMessage))
        }
        
        session.prewarm()
    }
    
    let generationOptions = GenerationOptions(sampling: .none, temperature: 1.0, maximumResponseTokens: 1024)
    
    func prompt(_ prompt: String) {
        isResponding = true
        task = Task {
            defer { isResponding = false }
            messages.append(Message(role: .user, content: prompt))
            messages.append(Message(role: .model, content: ""))
            
            // let stream = session.streamResponse(to: prompt)
            let stream = session.streamResponse(to: prompt, options: generationOptions)
            do {
                for try await partial in stream {
                    guard let lastMsg = messages.last,
                          lastMsg.role == .model,
                          let lastIndex = messages.indices.last
                    else {
                        fatalError("Last message must be a model message with model role")
                    }
                    let updatedMessage = Message(role: .model, content: partial.content)
                    messages[lastIndex] = updatedMessage
                    // if Task.isCancelled { break } // not reachable, on Task cancellation the stream just ends the loop
                }
            } catch {
                messages.append(Message(role: .model, content: "Error: " + error.localizedDescription))
            }
        }
    }
    
    func cancel() {
        task?.cancel()
    }
}

