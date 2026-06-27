//
//  ContentView.swift
//  ModelLab
//
//  Created by Ivan Milinkovic on 20. 6. 2026.
//

import SwiftUI

struct ContentView: View {
    
    enum Route {
        case chat, suggestion, tagging, vision
    }
    @State private var route: Route?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            List(selection: $route) {
                Section("Foundation Models") {
                    NavigationLink("Chat", value: Route.chat)
                    NavigationLink("Suggestions", value: Route.suggestion)
                    NavigationLink("Tagging", value: Route.tagging)
                }
                Section("Vision") {
                    NavigationLink("Vision", value: Route.vision)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Models Lab")
        } detail: {
            switch route {
            case .chat:
                ChatView()
            case .suggestion:
                SuggestionView()
            case .tagging:
                TaggingView()
            case .vision:
                VisionView()
            case .none:
                Text("Select an option from the sidebar")
            }
        }
        #if os(macOS)
        .navigationTitle("Models Lab")
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
