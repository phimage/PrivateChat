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
}
