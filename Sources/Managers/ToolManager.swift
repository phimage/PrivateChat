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
    
    /// Returns all loaded tools (both enabled and disabled)
    var allTools: [any FoundationModels.Tool] {
        return _allTools
    }
    
    /// Returns enabled tools for a given set of enabled tool names
    func getEnabledTools(enabledToolNames: Set<String>) -> [any FoundationModels.Tool] {
        return _allTools.filter { enabledToolNames.contains($0.name) }
    }
    
    /// Returns the tools to use (enabled tools, or all tools if none are specifically enabled)
    func getToolsToUse(enabledToolNames: Set<String>) -> [any FoundationModels.Tool] {
        return getEnabledTools(enabledToolNames: enabledToolNames)
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
    func getEnabledToolsByClient(enabledToolNames: Set<String>) -> [String: [any FoundationModels.Tool]] {
        var groupedTools: [String: [any FoundationModels.Tool]] = [:]
        
        let enabledTools = getEnabledTools(enabledToolNames: enabledToolNames)
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
    
    /// Enable or disable a specific tool in a set of enabled tool names
    func setToolEnabled(_ toolName: String, enabled: Bool, in enabledToolNames: inout Set<String>) {
        if enabled {
            enabledToolNames.insert(toolName)
        } else {
            enabledToolNames.remove(toolName)
        }
    }
    
    /// Get a set of all tool names
    func getAllToolNames() -> Set<String> {
        return Set(_allTools.map { $0.name })
    }
    
    /// Enable all tools from a specific client in a set of enabled tool names
    func enableAllToolsFromClient(_ clientName: String, in enabledToolNames: inout Set<String>) {
        if let tools = toolsByClient[clientName] {
            for tool in tools {
                enabledToolNames.insert(tool.name)
            }
        }
    }
    
    /// Disable all tools from a specific client in a set of enabled tool names
    func disableAllToolsFromClient(_ clientName: String, in enabledToolNames: inout Set<String>) {
        if let tools = toolsByClient[clientName] {
            for tool in tools {
                enabledToolNames.remove(tool.name)
            }
        }
    }
    
    /// Check if all tools from a client are enabled
    func areAllToolsFromClientEnabled(_ clientName: String, in enabledToolNames: Set<String>) -> Bool {
        guard let tools = toolsByClient[clientName], !tools.isEmpty else { return false }
        return tools.allSatisfy { enabledToolNames.contains($0.name) }
    }
    
    /// Check if any tools from a client are enabled
    func areAnyToolsFromClientEnabled(_ clientName: String, in enabledToolNames: Set<String>) -> Bool {
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
    
    /// Check if a client name corresponds to a CurrentAppConfig server
    func isCurrentAppServer(_ clientName: String) -> Bool {
        // Built-in clients that cannot be removed
        let builtInClients = ["claude", "vs code", "vscode", "general", "system"]
        return !builtInClients.contains(clientName.lowercased())
    }
}
