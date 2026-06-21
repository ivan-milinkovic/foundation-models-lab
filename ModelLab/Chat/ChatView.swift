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
                Text(model.history + model.inProgressAnswer)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxWidth: .infinity)
            .scrollDismissesKeyboard(.interactively)
            
            TextField("", text: $input, axis: .vertical)
                .font(.system(size: 16))
                .focused($focused)
                .lineLimit(1...4)
                .keyboardType(.default)
                .padding(14)
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
