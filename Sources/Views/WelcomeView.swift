//
//  WelcomeView.swift
//  PrivateChat
//
//  Welcome view shown when no chat session is selected
//

import SwiftUI

struct WelcomeView: View {
    let onStartNewChat: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Foundation Model Chat")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Start a conversation with AI powered by Foundation Models")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onStartNewChat) {
                HStack {
                    Image(systemName: "plus.bubble")
                    Text("Start New Chat")
                }
                .font(.title3)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Features:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 32) {
                    FeatureItem(icon: "brain", title: "AI Assistant", description: "Powered by Foundation Models")
                    FeatureItem(icon: "wrench.and.screwdriver", title: "MCP Tools", description: "Enhanced capabilities")
                    FeatureItem(icon: "bubble.left.and.bubble.right", title: "Multiple Chats", description: "Organize conversations")
                }
            }
            .padding(.bottom, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 120)
    }
}

#Preview {
    WelcomeView {
        print("Start new chat")
    }
}
