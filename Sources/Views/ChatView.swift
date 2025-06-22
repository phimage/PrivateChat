//
//  ChatView.swift
//  PrivateChat
//
//  Main chat interface view
//

import SwiftUI

struct ChatView: View {
    let session: ChatSession
    let chatManager: ChatManager
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(session.messages, id: \.id) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Assistant is typing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.messages.count) {
                    // Auto-scroll to bottom when new messages arrive
                    if let lastMessage = session.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .secondary : .accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .onAppear {
            isInputFocused = true
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Clear Chat") {
                        chatManager.clearSession(session.id)
                    }
                    
                    Divider()
                    
                    Button("Settings...") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ChatSettingsView(
                session: session,
                toolManager: chatManager.sharedToolManager,
                chatManager: chatManager,
                isPresented: $showingSettings
            )
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty && !isLoading else { return }
        
        messageText = ""
        isLoading = true
        
        Task {
            await chatManager.sendMessage(text, to: session.id)
            await MainActor.run {
                isLoading = false
                isInputFocused = true
            }
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
}

#Preview {
    ChatView(
        session: ChatSession(title: "Preview Chat", messages: [
            ChatMessage(content: "Hello, how can I help you today?", isFromUser: false),
            ChatMessage(content: "I need help with SwiftUI", isFromUser: true),
            ChatMessage(content: "I'd be happy to help you with SwiftUI! What specific aspect would you like to learn about?", isFromUser: false)
        ]),
        chatManager: ChatManager()
    )
}
