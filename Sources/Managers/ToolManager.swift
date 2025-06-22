//
//  ToolManager.swift
//  PrivateChat
//
//  Manages tool loading and sharing across chat sessions
//

import Foundation
import FoundationModels
import Logging
import MCPUtils
import Combine

@MainActor
class ToolManager: ObservableObject {
    
    private let logger = Logger(label: "ToolManager")
    private var _allTools: [any FoundationModels.Tool] = []
    private var isLoaded = false
    private var loadingTask: Task<Void, Never>?
    
    /// Set of tool names that are currently enabled
    @Published var enabledToolNames: Set<String> = []
    
    /// Returns all loaded tools (both enabled and disabled)
    var allTools: [any FoundationModels.Tool] {
        return _allTools
    }
    
    /// Returns only the enabled tools
    var enabledTools: [any FoundationModels.Tool] {
        return _allTools.filter { enabledToolNames.contains($0.name) }
    }
    
    /// Returns the tools to use (enabled tools, or all tools if none are specifically enabled)
    var tools: [any FoundationModels.Tool] {
        if enabledToolNames.isEmpty {
            return _allTools
        }
        return enabledTools
    }
    
    /// Returns true if tools have been loaded
    var areToolsLoaded: Bool {
        return isLoaded
    }
    
    // MARK: - Public Methods
    
    /// Returns tools grouped by MCP client name
    var toolsByClient: [String: [any FoundationModels.Tool]] {
        var groupedTools: [String: [any FoundationModels.Tool]] = [:]
        
        for tool in _allTools {
            // Try to access the MCP client name from the tool
            let clientName = getClientName(for: tool)
            
            if groupedTools[clientName] == nil {
                groupedTools[clientName] = []
            }
            groupedTools[clientName]?.append(tool)
        }
        
        return groupedTools
    }
    
    /// Returns enabled tools grouped by MCP client name
    var enabledToolsByClient: [String: [any FoundationModels.Tool]] {
        var groupedTools: [String: [any FoundationModels.Tool]] = [:]
        
        for tool in enabledTools {
            let clientName = getClientName(for: tool)
            
            if groupedTools[clientName] == nil {
                groupedTools[clientName] = []
            }
            groupedTools[clientName]?.append(tool)
        }
        
        return groupedTools
    }
    
    /// Loads tools asynchronously. Safe to call multiple times - will only load once.
    func loadToolsIfNeeded() async {
        // If already loaded or currently loading, return
        if isLoaded || loadingTask != nil {
            await loadingTask?.value
            return
        }
        
        loadingTask = Task {
            await loadTools()
        }
        
        await loadingTask?.value
        loadingTask = nil
    }
    
    /// Force reload tools (useful for refreshing tools)
    func reloadTools() async {
        isLoaded = false
        _allTools.removeAll()
        await loadTools()
    }
    
    /// Enable or disable a specific tool
    func setToolEnabled(_ toolName: String, enabled: Bool) {
        if enabled {
            enabledToolNames.insert(toolName)
        } else {
            enabledToolNames.remove(toolName)
        }
    }
    
    /// Enable all tools
    func enableAllTools() {
        enabledToolNames = Set(_allTools.map { $0.name })
    }
    
    /// Disable all tools
    func disableAllTools() {
        enabledToolNames.removeAll()
    }
    
    /// Enable all tools from a specific client
    func enableAllToolsFromClient(_ clientName: String) {
        if let tools = toolsByClient[clientName] {
            for tool in tools {
                enabledToolNames.insert(tool.name)
            }
        }
    }
    
    /// Disable all tools from a specific client
    func disableAllToolsFromClient(_ clientName: String) {
        if let tools = toolsByClient[clientName] {
            for tool in tools {
                enabledToolNames.remove(tool.name)
            }
        }
    }
    
    /// Check if all tools from a client are enabled
    func areAllToolsFromClientEnabled(_ clientName: String) -> Bool {
        guard let tools = toolsByClient[clientName], !tools.isEmpty else { return false }
        return tools.allSatisfy { enabledToolNames.contains($0.name) }
    }
    
    /// Check if any tools from a client are enabled
    func areAnyToolsFromClientEnabled(_ clientName: String) -> Bool {
        guard let tools = toolsByClient[clientName] else { return false }
        return tools.contains { enabledToolNames.contains($0.name) }
    }
    
    func killTools() async {
        logger.debug("Killing all mcp tools server...")
        
        loadingTask?.cancel()
        // Get clients
        var clients: [String: MCP.Client] = [:]
        for tool in allTools where tool is MCPWrapperTool {
            if let mcpTool = tool as? MCPWrapperTool {
                clients[mcpTool.mcpClient.name] = mcpTool.mcpClient
            }
        }
        // kill each client
        for (_, client) in clients {
            await client.disconnect()
            logger.debug("Killed tool server: \(client.name)")
        }
    }

    // MARK: - Private Methods
    
    private func loadTools() async {
        logger.debug("Loading tools...")
        
        let toolService = ToolService()
        let allTools = await toolService.loadTools(logger: logger).foundationModelsTools
        
        // Remove duplicates by name
        let uniqueTools = removeDuplicateTools(from: allTools)
        
        _allTools = uniqueTools
        isLoaded = true
        
        // If no tools are explicitly enabled, enable all by default
        if enabledToolNames.isEmpty {
            enabledToolNames = Set(uniqueTools.map { $0.name })
        }
        
        logger.debug("Loaded \(uniqueTools.count) unique tools")
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
    
    /// Get MCP client name for a tool
    private func getClientName(for tool: any FoundationModels.Tool) -> String {
        // For now, let's try to use reflection or check if there's a way to get the client info
        if let mcpTool = tool as? MCPWrapperTool {
            // Try to access the MCP client property
            return mcpTool.mcpClient.name
        }

        // If no client info found, group under "General"
        return "General"
    }

}
