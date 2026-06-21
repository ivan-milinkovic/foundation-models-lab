//
//  TaggingView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI

struct TaggingView: View {
    
    @State private var input: String = ""
    @State private var model = TaggingModel.shared
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack {
            ScrollView {
                Text(model.history)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            
            TextEditor(text: $input)
                .font(.system(size: 16))
                .focused($focused)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.25))
                }
                .frame(height: 100)
            
            HStack {
                if model.isResponding {
                    ProgressView()
                        .frame(width: 24, height: 24)
                }
                Button("Send") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isResponding)
            }
        }
        .navigationTitle("Tagging")
        .padding()
        .task {
            focused = true
        }
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
    TaggingView()
}
