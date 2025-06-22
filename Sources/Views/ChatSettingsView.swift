//
//  ChatSettingsView.swift
//  PrivateChat
//
//  Settings view for chat configuration including tool filtering
//

import SwiftUI
import FoundationModels

struct ChatSettingsView: View {
    let session: ChatSession
    let toolManager: ToolManager
    let chatManager: ChatManager
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    var filteredTools: [any FoundationModels.Tool] {
        if searchText.isEmpty {
            return toolManager.allTools
        } else {
            return toolManager.allTools.filter { tool in
                tool.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
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
                        }
                        
                        // Tool management buttons
                        HStack {
                            Button("Enable All") {
                                toolManager.enableAllTools()
                                Task {
                                    await chatManager.reinitializeSession(session.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Disable All") {
                                toolManager.disableAllTools()
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
                        
                        // Tools list
                        if filteredTools.isEmpty {
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
                                ForEach(filteredTools, id: \.name) { tool in
                                    ToolRowView(
                                        tool: tool,
                                        isEnabled: toolManager.enabledToolNames.contains(tool.name),
                                        onToggle: { enabled in
                                            toolManager.setToolEnabled(tool.name, enabled: enabled)
                                            Task {
                                                await chatManager.reinitializeSession(session.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .frame(minHeight: 200)
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
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct ToolRowView: View {
    let tool: any FoundationModels.Tool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                    .font(.headline)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Text("Tool for enhanced functionality")
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
        .padding(.vertical, 4)
        .background(isEnabled ? Color.clear : Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    ChatSettingsView(
        session: ChatSession(title: "Preview Chat"),
        toolManager: ToolManager(),
        chatManager: ChatManager(),
        isPresented: .constant(true)
    )
}
