//
//  CardViewModifier.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 21. 6. 2026.
//

import SwiftUI

struct CardViewModifier<S>: ViewModifier where S: ShapeStyle {
    let shapeStyle: S
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(shapeStyle)
            )
    }
}

extension View {
    func card<S>(_ shapeStyle: S) -> some View where S: ShapeStyle {
        self.modifier(CardViewModifier(shapeStyle: shapeStyle))
    }
}
