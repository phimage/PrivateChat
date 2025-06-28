//
//  NewSessionView.swift
//  PrivateChat
//
//  View for creating a new chat session with custom system instructions
//

import SwiftUI
import FoundationModels
import Logging
import MCPUtils

struct NewSessionView: View {
    @Binding var isPresented: Bool
    @ObservedObject var toolManager: ToolManager
    let onCreateSession: (String, Double, Set<String>) -> Void
    
    @State private var systemInstructions: String = "You are a helpful assistant."
    @State private var temperature: Double = 0.7
    @State private var selectedTab = 0
    @State private var selectedToolNames: Set<String> = []
    @State private var searchText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let logger = Logger(label: "NewSessionView")
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selection
                Picker("", selection: $selectedTab) {
                    Text("Settings").tag(0)
                    Text("Tools").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    // Settings Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Customize the system instructions for this chat session:")
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("System Instructions")
                                    .font(.headline)
                                
                                TextEditor(text: $systemInstructions)
                                    .focused($isTextFieldFocused)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Temperature")
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.1f", temperature))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                
                                Slider(
                                    value: $temperature,
                                    in: 0.0...2.0,
                                    step: 0.1
                                ) {
                                    Text("Temperature")
                                } minimumValueLabel: {
                                    Text("0.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } maximumValueLabel: {
                                    Text("2.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Controls creativity and randomness in responses. Lower values are more focused and deterministic.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                    .tag(0)
                    
                    // Tools Tab
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Select tools for this chat session")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(selectedToolNames.count) of \(toolManager.allTools.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .animation(.easeInOut(duration: 0.2), value: selectedToolNames.count)
                            }
                            
                            // Tool management buttons
                            HStack {
                                Button("Select All") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedToolNames = Set(toolManager.allTools.map { $0.name })
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Select None") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedToolNames.removeAll()
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                            }
                            
                            // Search field
                            TextField("Search tools...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        
                        // Tools list
                        ScrollView {
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
                                .padding()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(filteredToolsByClient.keys.sorted()), id: \.self) { clientName in
                                        if let tools = filteredToolsByClient[clientName] {
                                            VStack(spacing: 0) {
                                                // Client header
                                                NewSessionClientHeaderView(
                                                    clientName: clientName,
                                                    toolCount: tools.count,
                                                    selectedToolNames: $selectedToolNames,
                                                    tools: tools
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color(NSColor.controlBackgroundColor))
                                                
                                                // Tools for this client
                                                ForEach(tools, id: \.name) { tool in
                                                    NewSessionToolRowView(
                                                        tool: tool,
                                                        isSelected: selectedToolNames.contains(tool.name),
                                                        onToggle: { selected in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                if selected {
                                                                    selectedToolNames.insert(tool.name)
                                                                } else {
                                                                    selectedToolNames.remove(tool.name)
                                                                }
                                                            }
                                                        }
                                                    )
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .tag(1)
                }
                // .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Create New Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Chat") {
                        onCreateSession(systemInstructions, temperature, selectedToolNames)
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minHeight: 500)
        .padding(6)
        .onAppear {
            if selectedTab == 0 {
                isTextFieldFocused = true
            }
        }
        .task {
            await toolManager.loadToolsIfNeeded()
        }
    }
}

struct NewSessionToolRowView: View {
    let tool: any FoundationModels.Tool
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(.headline)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct NewSessionClientHeaderView: View {
    let clientName: String
    let toolCount: Int
    @Binding var selectedToolNames: Set<String>
    let tools: [any FoundationModels.Tool]
    
    private var allToolsSelected: Bool {
        tools.allSatisfy { selectedToolNames.contains($0.name) }
    }
    
    private var someToolsSelected: Bool {
        tools.contains { selectedToolNames.contains($0.name) }
    }
    
    var body: some View {
        HStack {
            Image(systemName: clientIcon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(clientName)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Client-level controls
            HStack(spacing: 8) {
                // Toggle all tools for this client
                Button(action: {
                    if allToolsSelected {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for tool in tools {
                                selectedToolNames.remove(tool.name)
                            }
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for tool in tools {
                                selectedToolNames.insert(tool.name)
                            }
                        }
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
        if allToolsSelected {
            return "checkmark.circle.fill"
        } else if someToolsSelected {
            return "minus.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var clientToggleColor: Color {
        if allToolsSelected {
            return .green
        } else if someToolsSelected {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var clientToggleHelpText: String {
        if allToolsSelected {
            return "Deselect all \(clientName) tools"
        } else {
            return "Select all \(clientName) tools"
        }
    }
}

#Preview {
    let toolManager = ToolManager()
    NewSessionView(
        isPresented: .constant(true),
        toolManager: toolManager
    ) { instructions, temperature, selectedTools in
        print("System instructions: \(instructions)")
        print("Temperature: \(temperature)")
        print("Selected tools: \(selectedTools)")
    }
}
