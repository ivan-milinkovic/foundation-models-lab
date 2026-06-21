//
//  SuggestionView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI
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
