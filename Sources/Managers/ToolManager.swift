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
    private var _tools: [any FoundationModels.Tool] = []
    private var isLoaded = false
    private var loadingTask: Task<Void, Never>?
    
    /// Returns the loaded tools. If not loaded yet, returns empty array.
    var tools: [any FoundationModels.Tool] {
        return _tools
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
        _tools.removeAll()
        await loadTools()
    }
    
    // MARK: - Private Methods
    
    private func loadTools() async {
        logger.debug("Loading tools...")
        
        let toolService = ToolService()
        let allTools = await toolService.loadTools(logger: logger).foundationModelsTools
        
        // Remove duplicates by name
        let uniqueTools = removeDuplicateTools(from: allTools)
        
        _tools = uniqueTools
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
}
