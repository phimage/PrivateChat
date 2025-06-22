//
//  ContentView.swift
//  PrivateChat
//
//  Main content view with sidebar and chat interface
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var selectedSessionId: UUID?
    @State private var showingNewSessionSheet = false
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar with chat sessions
            SidebarView(
                sessions: chatManager.sessions,
                selectedSessionId: $selectedSessionId,
                onNewSession: { showingNewSessionSheet = true },
                onDeleteSession: { sessionId in
                    chatManager.deleteSession(sessionId)
                    if selectedSessionId == sessionId {
                        selectedSessionId = chatManager.sessions.first?.id
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Main chat view
            if let sessionId = selectedSessionId,
               let session = chatManager.sessions.first(where: { $0.id == sessionId }) {
                ChatView(session: session, chatManager: chatManager)
            } else {
                // Welcome view when no session is selected
                WelcomeView {
                    showingNewSessionSheet = true
                }
            }
        }
        .onAppear {
            // If no sessions exist, show the new session sheet
            if chatManager.sessions.isEmpty {
                showingNewSessionSheet = false
            } else if selectedSessionId == nil {
                // Select the first session if available
                selectedSessionId = chatManager.sessions.first?.id
            }
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionView(isPresented: $showingNewSessionSheet) { systemInstructions in
                let newSession = chatManager.createNewSession(systemInstructions: systemInstructions)
                selectedSessionId = newSession.id
            }
        }
    }
}

#Preview {
    ContentView()
}
