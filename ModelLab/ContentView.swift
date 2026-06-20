//
//  ContentView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            QuestionAnswerView().card()
            StreamingView().card()
            SuggestionView().card()
        }
        .frame(minHeight: 700)
        .padding()
    }
}

#Preview {
    ContentView()
}

struct CardViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.gray)
            )
    }
}

extension View {
    func card() -> some View {
        self.modifier(CardViewModifier())
    }
}
