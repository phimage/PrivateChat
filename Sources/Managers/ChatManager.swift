//
//  ChatManager.swift
//  PrivateChat
//
//  Manages chat sessions and language model interactions
//

import Foundation
import FoundationModels
import Logging
import MCPUtils
import Combine

@MainActor
class ChatManager: ObservableObject {
    
    @Published var sessions: [ChatSession] = []
    private let logger = Logger(label: "ChatManager")
    private let toolManager: ToolManager
    
    init(toolManager: ToolManager = ToolManager()) {
        self.toolManager = toolManager
        // Don't create initial session automatically
        // Let the user create the first session with custom instructions
        
        // Load tools once when ChatManager is initialized
        Task {
            await toolManager.loadToolsIfNeeded()
        }
    }
    
    @discardableResult
    func createNewSession(systemInstructions: String? = nil, temperature: Double? = nil, enabledToolNames: Set<String>? = nil) -> ChatSession {
        let session = ChatSession()
        
        // Set custom system instructions if provided
        if let instructions = systemInstructions {
            session.systemInstructions = instructions
        }
        
        // Set custom temperature if provided
        if let temp = temperature {
            session.temperature = temp
        }
        
        // Set the enabled tools for this session if provided
        if let toolNames = enabledToolNames {
            session.enabledToolNames = toolNames
        }
        
        sessions.append(session)
        
        // Initialize the session asynchronously
        Task {
            await initializeSession(session)
        }
        
        return session
    }
    
    func deleteSession(_ sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        
        // Don't automatically create a new session - let the UI handle empty state
    }
    
    func clearSession(_ sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            session.clearMessages()
        }
    }
    
    func sendMessage(_ content: String, to sessionId: UUID) async {
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            logger.error("Session not found: \(sessionId)")
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(content: content, isFromUser: true)
        session.addMessage(userMessage)
        
        // Get AI response
        await getAIResponse(for: sessionId, userMessage: content)
    }
    
    func getAIResponse(for sessionId: UUID, userMessage: String) async {
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            logger.error("Session not found: \(sessionId)")
            return
        }
        
        // Get AI response
        do {
            let response = try await getAIResponse(for: session, userInput: userMessage)
            let assistantMessage = ChatMessage(content: response, isFromUser: false)
            session.addMessage(assistantMessage)
        } catch {
            logger.error("Error getting AI response: \(error)")
            let errorMessage = ChatMessage(
                content: "I apologize, but I encountered an error processing your request. Please try again.",
                isFromUser: false
            )
            session.addMessage(errorMessage)
        }
    }
    
    /// Provides access to the shared tool manager
    var sharedToolManager: ToolManager {
        return toolManager
    }
    
    /// Reinitialize a session (useful when tool settings change)
    func reinitializeSession(_ sessionId: UUID) async {
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            logger.error("Session not found for reinitialization: \(sessionId)")
            return
        }
        
        await initializeSession(session)
    }
    
    /// Update the enabled tools for a specific session
    func updateSessionTools(_ sessionId: UUID, enabledToolNames: Set<String>) async {
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            logger.error("Session not found for tool update: \(sessionId)")
            return
        }
        
        session.enabledToolNames = enabledToolNames
        await initializeSession(session)
    }
    
    // MARK: - Private Methods
    
    private func initializeSession(_ session: ChatSession) async {
        // Ensure tools are loaded
        await toolManager.loadToolsIfNeeded()
        
        // Get tools for this specific session
        let tools = toolManager.getToolsToUse(enabledToolNames: session.enabledToolNames)
        session.tools = tools
        
        // Create language model session
        let languageModelSession = createLanguageModelSession(for: session, with: tools)
        session.languageModelSession = languageModelSession
        
        logger.debug("Initialized session \(session.id) with \(tools.count) tools")
    }
    
    private func createLanguageModelSession(for session: ChatSession, with tools: [any FoundationModels.Tool]) -> LanguageModelSession {
        let model = SystemLanguageModel.default
        return LanguageModelSession(
            model: model,
            guardrails: .default,
            tools: tools,
            instructions: session.systemInstructions
        )
    }
    
    private func getAIResponse(for session: ChatSession, userInput: String) async throws -> String {
        // Ensure the session has a language model session
        if session.languageModelSession == nil {
            await initializeSession(session)
        }
        
        guard let languageModelSession = session.languageModelSession else {
            throw ChatError.sessionNotInitialized
        }
        
        let options = GenerationOptions(
            sampling: nil,
            temperature: session.temperature,
            maximumResponseTokens: session.maximumResponseTokens
        )
        
        let response = try await languageModelSession.respond(to: userInput, options: options)
        return response.content
    }
}

enum ChatError: LocalizedError {
    case sessionNotInitialized
    
    nonisolated var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "Chat session is not properly initialized"
        }
    }
}
