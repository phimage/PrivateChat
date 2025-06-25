//
//  SidebarView.swift
//  PrivateChat
//
//  Sidebar view showing chat sessions
//

import SwiftUI

struct SidebarView: View {
    let sessions: [ChatSession]
    @Binding var selectedSessionId: UUID?
    let onNewSession: () -> Void
    let onDeleteSession: (UUID) -> Void
    let onShowSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with New Chat button
            HStack {
                Text("Chats")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onNewSession) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("New Chat")
            }
            .padding()
            
            Divider()
                .padding()
            
            // Sessions list
            List(sessions, id: \.id, selection: $selectedSessionId) { session in
                SessionRowView(
                    session: session,
                    isSelected: selectedSessionId == session.id,
                    onDelete: { onDeleteSession(session.id) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.sidebar)
            
            // Footer with settings button
            VStack {
                Divider()
                
                HStack {
                    Button(action: onShowSettings) {
                        HStack {
                            Image(systemName: "gearshape")
                                .font(.title3)
                            Text("Settings")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("App Settings")
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct SessionRowView: View {
    let session: ChatSession
    let isSelected: Bool
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let lastMessage = session.messages.last {
                    Text(lastMessage.content)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Delete Chat")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    SidebarView(
        sessions: [
            ChatSession(title: "Sample Chat 1"),
            ChatSession(title: "Sample Chat 2")
        ],
        selectedSessionId: .constant(nil),
        onNewSession: {},
        onDeleteSession: { _ in },
        onShowSettings: {}
    )
    .frame(width: 250)
}
