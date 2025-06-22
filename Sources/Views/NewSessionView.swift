//
//  NewSessionView.swift
//  PrivateChat
//
//  View for creating a new chat session with custom system instructions
//

import SwiftUI

struct NewSessionView: View {
    @Binding var isPresented: Bool
    let onCreateSession: (String) -> Void
    
    @State private var systemInstructions: String = "You are a helpful assistant."
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Chat")
                .font(.title2)
                .fontWeight(.semibold)
            
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
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Chat") {
                    onCreateSession(systemInstructions)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 450, idealWidth: 500, maxWidth: 600, minHeight: 280, idealHeight: 320, maxHeight: 400)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    NewSessionView(isPresented: .constant(true)) { instructions in
        print("System instructions: \(instructions)")
    }
}
