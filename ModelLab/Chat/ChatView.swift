//
//  ChatView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI

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
