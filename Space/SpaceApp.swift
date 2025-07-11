//
//  SpaceApp.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 24/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI

@main
struct SpaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var analizer: Analizer = Analizer()
    @State private var searchPath: String = NSHomeDirectory()
    @State private var windowWidth: CGFloat = 0
    
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                ContentView()
                    .environmentObject(self.analizer)
                    .toolbar {
                        ToolbarView(analizer: self.analizer, width: $windowWidth)
                    }
                    .onAppear {
                        self.windowWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.windowWidth = newWidth
                        }
                    }
            }
            .frame(minWidth: 900, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct ContentView: View {
    @EnvironmentObject private var analizer: Analizer
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack {
                if let errorMessage = self.analizer.errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .foregroundColor(.red)
                    Spacer()
                } else if self.analizer.analyzedEntities.isEmpty {
                    Spacer()
                    Text("No results yet. Start an analysis.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    HStack(spacing: 2) {
                        ListView().environmentObject(self.analizer)
                        Divider()
                        DetailsView().environmentObject(self.analizer).frame(width: 250)
                    }
                }
            }
        }
    }
}
