//
//  PrivateChatApp.swift
//  PrivateChat
//
//  Created by Eric on 6/22/25.
//

import SwiftUI

@main
struct PrivateChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
    }
}
