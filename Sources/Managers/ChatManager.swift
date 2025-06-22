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
    
    init() {
        // Don't create initial session automatically
        // Let the user create the first session with custom instructions
    }
    
    @discardableResult
    func createNewSession(systemInstructions: String? = nil) -> ChatSession {
        let session = ChatSession()
        
        // Set custom system instructions if provided
        if let instructions = systemInstructions {
            session.systemInstructions = instructions
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
        
        // Ensure we always have at least one session
        if sessions.isEmpty {
            createNewSession()
        }
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
        do {
            let response = try await getAIResponse(for: session, userInput: content)
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
    
    // MARK: - Private Methods
    
    private func initializeSession(_ session: ChatSession) async {
        // Load tools
        let tools = await loadTools()
        session.tools = tools
        
        // Create language model session
        let languageModelSession = createLanguageModelSession(for: session, with: tools)
        session.languageModelSession = languageModelSession
        
        logger.debug("Initialized session \(session.id) with \(tools.count) tools")
    }
    
    private func loadTools() async -> [any FoundationModels.Tool] {
        let toolService = ToolService()
        let allTools = await toolService.loadTools(logger: logger).foundationModelsTools
        
        // Remove duplicates by name
        let uniqueTools = removeDuplicateTools(from: allTools)
        
        logger.debug("Loaded \(uniqueTools.count) unique tools")
        return uniqueTools
    }
    
    private func removeDuplicateTools(from tools: [any FoundationModels.Tool]) -> [any FoundationModels.Tool] {
        var seenNames = Set<String>()
        var uniqueTools: [any FoundationModels.Tool] = []
        
        for tool in tools {
            if !seenNames.contains(tool.name) {
                seenNames.insert(tool.name)
                uniqueTools.append(tool)
            } else {
                logger.debug("Removing duplicate tool: \(tool.name)")
            }
        }
        
        return uniqueTools
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
