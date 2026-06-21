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
                ForEach(model.messages) { msg in
                    Text(prepareContent(msg.content))
                        .textSelection(.enabled)
                        .card()
                        .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
                }
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
    
    func prepareContent(_ content: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let astr = try? AttributedString(markdown: content, options: opts) {
            return astr
        } else {
            return AttributedString(stringLiteral: content)
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
