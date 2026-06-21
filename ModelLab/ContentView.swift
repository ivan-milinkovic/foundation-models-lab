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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            List(selection: $route) {
                NavigationLink("Chat", value: Route.chat)
                NavigationLink("Suggestions", value: Route.suggestion)
                NavigationLink("Tagging", value: Route.tagging)
            }
            .listStyle(.sidebar)
        } detail: {
            switch route {
            case .chat:
                ChatView()
            case .suggestion:
                SuggestionView()
            case .tagging:
                TaggingView()
            case .none:
                Text("Select an option from the sidebar")
            }
        }
        #if os(macOS)
        .navigationTitle("Foundation Models Lab")
        #endif
        .task {
            if horizontalSizeClass == .regular {
                route = .chat
            }
        }
    }
}

#Preview {
    ContentView()
}
