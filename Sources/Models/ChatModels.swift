//
//  ChatModels.swift
//  PrivateChat
//
//  Data models for chat functionality
//

import Foundation
import FoundationModels
import Combine

/// Represents a chat message
///
nonisolated struct ChatMessage: Identifiable, Codable { // https://github.com/swiftlang/swift/pull/81934
    @MainActor let id: UUID
    @MainActor let content: String
    @MainActor let isFromUser: Bool
    @MainActor let timestamp: Date
    
    init(content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

/// Represents a chat session
@MainActor
class ChatSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String
    @Published var messages: [ChatMessage] = []
    @Published var systemInstructions: String = "You are a helpful assistant."
    @Published var temperature: Double = 0.7
    @Published var maximumResponseTokens: Int?
    @Published var enabledToolNames: Set<String> = []
    
    // Internal session state
    var languageModelSession: LanguageModelSession?
    var tools: [any FoundationModels.Tool] = []
    
    init(title: String = "New Chat", messages: [ChatMessage] = []) {
        self.title = title
        self.messages = messages
    }
    
    func addMessage(_ message: ChatMessage) {
        self.messages.append(message)
        
        // Update title based on first user message if still default
        if self.title == "New Chat" && message.isFromUser && !message.content.isEmpty {
            let words = message.content.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            self.title = Array(words.prefix(4)).joined(separator: " ")
            if words.count > 4 {
                self.title += "..."
            }
        }
    }
    
    func clearMessages() {
        self.messages.removeAll()
    }
}

