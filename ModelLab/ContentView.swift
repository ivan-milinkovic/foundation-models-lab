//
//  ContentView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI

struct ContentView: View {
    
    enum Route {
        case chat, suggestion, tagging
    }
    @State private var route: Route?

    var body: some View {
        NavigationSplitView {
            List(selection: $route) {
                NavigationLink("Chat", value: Route.chat)
                NavigationLink("Suggestions", value: Route.suggestion)
                NavigationLink("Tagging", value: Route.tagging)
            }
            .listStyle(.sidebar)
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Foundation Models Lab")
                        .font(.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            #endif // os(iOS)
        } detail: {
            switch route {
            case .chat:
                ChatView()
            case .suggestion:
                SuggestionView()
            case .tagging:
                TaggingView()
            case .none:
                Text("Select from the sidebar")
            }
        }
        #if os(macOS)
        .navigationTitle("Foundation Models Lab")
        #endif
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
