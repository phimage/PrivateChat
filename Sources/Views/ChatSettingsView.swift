//
//  ChatSettingsView.swift
//  PrivateChat
//
//  Settings view for chat configuration including tool filtering
//

import SwiftUI
import FoundationModels
import Logging
import MCPUtils

struct ChatSettingsView: View {
    let session: ChatSession
    @ObservedObject var toolManager: ToolManager
    let chatManager: ChatManager
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    private let logger = Logger(label: "ChatSettingsView")
    
    var filteredToolsByClient: [String: [any FoundationModels.Tool]] {
        let toolsByClient = toolManager.toolsByClient
        
        if searchText.isEmpty {
            return toolsByClient
        } else {
            var filtered: [String: [any FoundationModels.Tool]] = [:]
            
            for (clientName, tools) in toolsByClient {
                let filteredTools = tools.filter { tool in
                    tool.name.localizedCaseInsensitiveContains(searchText) ||
                    tool.description.localizedCaseInsensitiveContains(searchText) ||
                    clientName.localizedCaseInsensitiveContains(searchText)
                }
                
                if !filteredTools.isEmpty {
                    filtered[clientName] = filteredTools
                }
            }
            
            return filtered
        }
    }
    
    var totalFilteredToolsCount: Int {
        filteredToolsByClient.values.flatMap { $0 }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Session Information
                        GroupBox("Session Information") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Title:")
                                        .font(.headline)
                                    Spacer()
                                    Text(session.title)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Temperature:")
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.1f", session.temperature))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("System Instructions:")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text(session.systemInstructions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                        }
                        
                        // Tool Filtering
                        GroupBox("Available Tools") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Filter tools used in this chat session")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(toolManager.enabledTools.count) of \(toolManager.allTools.count) enabled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .animation(.easeInOut(duration: 0.2), value: toolManager.enabledTools.count)
                                }
                                
                                // Tool management buttons
                                HStack {
                                    Button("Enable All") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            toolManager.enableAllTools()
                                        }
                                        Task {
                                            await chatManager.reinitializeSession(session.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Disable All") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            toolManager.disableAllTools()
                                        }
                                        Task {
                                            await chatManager.reinitializeSession(session.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                }
                                
                                // Search field
                                TextField("Search tools...", text: $searchText)
                                    .textFieldStyle(.roundedBorder)
                                
                                // Tools list grouped by client
                                if filteredToolsByClient.isEmpty {
                                    VStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title)
                                            .foregroundColor(.secondary)
                                        Text("No tools found")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        if !searchText.isEmpty {
                                            Text("Try adjusting your search terms")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 100)
                                } else {
                                    List {
                                        ForEach(Array(filteredToolsByClient.keys.sorted()), id: \.self) { clientName in
                                            if let tools = filteredToolsByClient[clientName] {
                                                Section(header: ClientHeaderView(
                                                    clientName: clientName, 
                                                    toolCount: tools.count,
                                                    toolManager: toolManager,
                                                    chatManager: chatManager,
                                                    sessionId: session.id
                                                )) {
                                                    ForEach(tools, id: \.name) { tool in
                                                        ToolRowView(
                                                            tool: tool,
                                                            isEnabled: toolManager.enabledToolNames.contains(tool.name),
                                                            onToggle: { enabled in
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    toolManager.setToolEnabled(tool.name, enabled: enabled)
                                                                }
                                                                Task {
                                                                    await chatManager.reinitializeSession(session.id)
                                                                }
                                                            }
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(minHeight: 200)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Chat Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minHeight: 500)
    }
}

struct ToolRowView: View {
    let tool: any FoundationModels.Tool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onToggle(!isEnabled)
            }) {
                HStack {
                    Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundColor(isEnabled ? .accentColor : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.name)
                            .font(.headline)
                            .foregroundColor(isEnabled ? .primary : .secondary)
                        
                        Text(tool.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    Circle()
                        .fill(isEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 4)
        .background(isEnabled ? Color.clear : Color.gray.opacity(0.1))
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

struct ClientHeaderView: View {
    let clientName: String
    let toolCount: Int
    let toolManager: ToolManager
    let chatManager: ChatManager
    let sessionId: UUID
    
    // Check if this client comes from CurrentAppConfig (removable) vs built-in (Claude, VS Code)
    private var isRemovableClient: Bool {
        return toolManager.isCurrentAppServer(clientName)
    }
    
    var body: some View {
        HStack {
            Image(systemName: clientIcon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(clientName)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if isRemovableClient {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help("Custom MCP Server")
            }
            
            Spacer()
            
            // Client-level controls
            HStack(spacing: 8) {
                // Enable/Disable toggle for the entire client
                Button(action: {
                    if toolManager.areAllToolsFromClientEnabled(clientName) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            toolManager.disableAllToolsFromClient(clientName)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            toolManager.enableAllToolsFromClient(clientName)
                        }
                    }
                    Task {
                        await chatManager.reinitializeSession(sessionId)
                    }
                }) {
                    Image(systemName: clientToggleIcon)
                        .font(.caption)
                        .foregroundColor(clientToggleColor)
                }
                .buttonStyle(.borderless)
                .help(clientToggleHelpText)
                
                Text("\(toolCount) tool\(toolCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
    
    private var clientIcon: String {
        switch clientName.lowercased() {
        case "github":
            return "checkmark.seal"
        case "file system", "filesystem":
            return "folder"
        case "web browser", "browser":
            return "globe"
        case "general":
            return "wrench.and.screwdriver"
        default:
            return "app.connected.to.app.below.fill"
        }
    }
    
    private var clientToggleIcon: String {
        if toolManager.areAllToolsFromClientEnabled(clientName) {
            return "checkmark.circle.fill"
        } else if toolManager.areAnyToolsFromClientEnabled(clientName) {
            return "minus.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var clientToggleColor: Color {
        if toolManager.areAllToolsFromClientEnabled(clientName) {
            return .green
        } else if toolManager.areAnyToolsFromClientEnabled(clientName) {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var clientToggleHelpText: String {
        if toolManager.areAllToolsFromClientEnabled(clientName) {
            return "Disable all \(clientName) tools"
        } else {
            return "Enable all \(clientName) tools"
        }
    }
}

#Preview {
    let toolManager = ToolManager()
    return ChatSettingsView(
        session: ChatSession(title: "Preview Chat"),
        toolManager: toolManager,
        chatManager: ChatManager(toolManager: toolManager),
        isPresented: .constant(true)
    )
}
