//
//  NewSessionView.swift
//  PrivateChat
//
//  View for creating a new chat session with custom system instructions
//

import SwiftUI

struct NewSessionView: View {
    @Binding var isPresented: Bool
    let onCreateSession: (String, Double) -> Void
    
    @State private var systemInstructions: String = "You are a helpful assistant."
    @State private var temperature: Double = 0.7
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
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Chat") {
                    onCreateSession(systemInstructions, temperature)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    NewSessionView(isPresented: .constant(true)) { instructions, temperature in
        print("System instructions: \(instructions)")
        print("Temperature: \(temperature)")
    }
}
