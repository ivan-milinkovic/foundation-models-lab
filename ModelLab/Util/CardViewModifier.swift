//
//  CardViewModifier.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import SwiftUI

struct CardViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
            )
    }
}

extension View {
    func card() -> some View {
        self.modifier(CardViewModifier())
    }
}
