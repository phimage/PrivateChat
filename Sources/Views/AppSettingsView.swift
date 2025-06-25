//
//  AppSettingsView.swift
//  PrivateChat
//
//  Global app settings including MCP server management
//

import SwiftUI
import FoundationModels
import Logging
import MCPUtils

struct AppSettingsView: View {
    @ObservedObject var toolManager: ToolManager
    let chatManager: ChatManager
    @Binding var isPresented: Bool
    
    @State private var showingAddServerSheet = false
    @State private var currentAppServers: [String: MCPServerConfig] = [:]
    @State private var refreshingServers = false
    
    private let logger = Logger(label: "AppSettingsView")
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // App Information
                        GroupBox("Application") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("PrivateChat")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("v1.0")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("A privacy-focused chat application with Model Context Protocol support")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // MCP Server Management
                        GroupBox("MCP Servers") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Manage Model Context Protocol servers")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingAddServerSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus")
                                            Text("Add Server")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        refreshServers()
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(refreshingServers)
                                }
                                
                                if currentAppServers.isEmpty {
                                    VStack {
                                        Image(systemName: "server.rack")
                                            .font(.title)
                                            .foregroundColor(.secondary)
                                        Text("No custom MCP servers configured")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Text("Add a server to extend functionality across all chats")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 100)
                                } else {
                                    LazyVStack(spacing: 8) {
                                        ForEach(Array(currentAppServers.keys.sorted()), id: \.self) { serverName in
                                            if let serverConfig = currentAppServers[serverName] {
                                                MCPServerRowView(
                                                    serverName: serverName,
                                                    serverConfig: serverConfig,
                                                    onRemove: {
                                                        removeServer(serverName)
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Global Tool Overview
                        GroupBox("Available Tools") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Global tool registry")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(toolManager.allTools.count) total tools")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Tool count by client
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(toolManager.toolsByClient.keys.sorted()), id: \.self) { clientName in
                                        if let tools = toolManager.toolsByClient[clientName] {
                                            HStack {
                                                Image(systemName: clientIcon(for: clientName))
                                                    .font(.caption)
                                                    .foregroundColor(.accentColor)
                                                    .frame(width: 16)
                                                
                                                Text(clientName)
                                                    .font(.caption)
                                                
                                                Spacer()
                                                
                                                Text("\(tools.count) tool\(tools.count == 1 ? "" : "s")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                Text("Tools can be enabled/disabled per chat session in Chat Settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("App Settings")
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
        .onAppear {
            loadCurrentAppServers()
        }
        .sheet(isPresented: $showingAddServerSheet) {
            AddMCPServerView(isPresented: $showingAddServerSheet) { serverName, serverConfig in
                addServer(serverName, serverConfig)
            }
            .frame(minWidth: 500, minHeight: 600)
        }
    }
    
    // MARK: - Helper Functions
    
    private func clientIcon(for clientName: String) -> String {
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
    
    // MARK: - MCP Server Management
    
    private func loadCurrentAppServers() {
        Task {
            do {
                let config = try CurrentAppConfigService.loadConfig(logger: logger)
                await MainActor.run {
                    currentAppServers = config.servers
                }
            } catch {
                logger.error("Failed to load current app servers: \(error)")
            }
        }
    }
    
    private func addServer(_ serverName: String, _ serverConfig: MCPServerConfig) {
        Task {
            do {
                try CurrentAppConfigService.addServer(name: serverName, config: serverConfig, logger: logger)
                await MainActor.run {
                    currentAppServers[serverName] = serverConfig
                }
                
                // Reload tools to include the new server
                await toolManager.reloadTools()
                // Note: Individual chat sessions will need to be reinitialized manually
                
                logger.info("Added MCP server: \(serverName)")
            } catch {
                logger.error("Failed to add MCP server: \(error)")
            }
        }
    }
    
    private func removeServer(_ serverName: String) {
        Task {
            do {
                let wasRemoved = try CurrentAppConfigService.removeServer(name: serverName, logger: logger)
                if wasRemoved {
                    await MainActor.run {
                        currentAppServers.removeValue(forKey: serverName)
                    }
                    
                    // Reload tools to remove the server's tools
                    await toolManager.reloadTools()
                    // Note: Individual chat sessions will need to be reinitialized manually
                    
                    logger.info("Removed MCP server: \(serverName)")
                }
            } catch {
                logger.error("Failed to remove MCP server: \(error)")
            }
        }
    }
    
    private func refreshServers() {
        refreshingServers = true
        Task {
            await toolManager.reloadTools()
            loadCurrentAppServers()
            
            await MainActor.run {
                refreshingServers = false
            }
        }
    }
}

struct MCPServerRowView: View {
    let serverName: String
    let serverConfig: MCPServerConfig
    let onRemove: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(serverName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(serverConfig.command ?? ">")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        showingDetails.toggle()
                    }) {
                        Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Show Details")
                    
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove Server")
                }
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(serverConfig.command ?? ">")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    if !(serverConfig.args?.isEmpty ?? true) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text((serverConfig.args ?? []).joined(separator: " "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    
                    if let env = serverConfig.env, !env.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(env.keys.sorted()), id: \.self) { key in
                                    if let value = env[key] {
                                        Text("\(key)=\(value)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: showingDetails)
    }
}

struct AddMCPServerView: View {
    @Binding var isPresented: Bool
    let onAddServer: (String, MCPServerConfig) -> Void
    
    @State private var serverName = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envVariables: [EnvVariable] = []
    @FocusState private var isServerNameFocused: Bool
    
    struct EnvVariable: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add MCP Server")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Configure a new Model Context Protocol server to extend functionality.")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Name")
                            .font(.headline)
                        
                        TextField("Enter server name", text: $serverName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isServerNameFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command")
                            .font(.headline)
                        
                        TextField("Enter executable command", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .help("The executable command to run the MCP server")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arguments")
                            .font(.headline)
                        
                        TextField("Enter command arguments (space-separated)", text: $args)
                            .textFieldStyle(.roundedBorder)
                            .help("Command line arguments separated by spaces")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Environment Variables")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                envVariables.append(EnvVariable())
                            }) {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        if envVariables.isEmpty {
                            Text("No environment variables")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(envVariables.indices, id: \.self) { index in
                                    HStack {
                                        TextField("Key", text: $envVariables[index].key)
                                            .textFieldStyle(.roundedBorder)
                                        
                                        Text("=")
                                            .foregroundColor(.secondary)
                                        
                                        TextField("Value", text: $envVariables[index].value)
                                            .textFieldStyle(.roundedBorder)
                                        
                                        Button(action: {
                                            envVariables.remove(at: index)
                                        }) {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bottom buttons
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Spacer()
                        
                        Button("Add Server") {
                            addServer()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                 command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                isServerNameFocused = true
            }
        }
    }
    
    private func addServer() {
        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty && !trimmedCommand.isEmpty else { return }
        
        // Parse arguments
        let parsedArgs = args.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Parse environment variables
        var env: [String: String]? = nil
        let validEnvVars = envVariables.filter { 
            !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
        }
        if !validEnvVars.isEmpty {
            env = Dictionary(uniqueKeysWithValues: validEnvVars.map { 
                ($0.key.trimmingCharacters(in: .whitespacesAndNewlines), 
                 $0.value.trimmingCharacters(in: .whitespacesAndNewlines))
            })
        }
        
        let serverConfig = MCPServerConfig(
            command: trimmedCommand,
            args: parsedArgs,
            env: env
        )
        
        onAddServer(trimmedName, serverConfig)
        isPresented = false
    }
}

#Preview {
    let toolManager = ToolManager()
    return AppSettingsView(
        toolManager: toolManager,
        chatManager: ChatManager(toolManager: toolManager),
        isPresented: .constant(true)
    )
}
