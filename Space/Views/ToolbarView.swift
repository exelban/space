//
//  ToolbarView.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 25/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI

struct ToolbarView: ToolbarContent {
    @ObservedObject public var analizer: Analizer
    @Binding public var width: CGFloat
    @State private var path: String = NSHomeDirectory()
    @State private var showStatusInfo: Bool = false
    
    @State private var settingsWindow: NSWindow?
    
    private var navbarWidth: CGFloat {
        if self.width - 350 < 460 {
            return 460
        }
        return self.width - 350
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: {
                self.openSettingsWindow()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 10)
            .help(Text("Open settings"))
        }
        
        ToolbarItem(placement: .principal) {
            HStack(spacing: 10) {
                Button(action: {
                    self.selectFolder()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .padding(.leading, 10)
                
                TextField("Path to the folder to analyze", text: $path)
                    .font(.system(size: 13))
                    .padding(.vertical, 6)
                    .focusEffectDisabled()
                    .textFieldStyle(PlainTextFieldStyle())
                    .background(Color.clear)
                    .onSubmit {
                        guard self.analizer.status != .running else { return }
                        self.analize(self.path)
                    }
                
                Button(action: {
                    showStatusInfo = true
                }) {
                    switch self.analizer.status {
                    case .running:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 14, height: 14)
                            .scaleEffect(0.4)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    case .cancelled, .error:
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    default:
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showStatusInfo, arrowEdge: .bottom) {
                    StatusView(status: analizer.status, duration: analizer.stats?.formattedDuration ?? "N/A")
                }
                .padding(.trailing, 10)
            }
            .frame(width: 460)
            .background(Material.bar)
            .cornerRadius(5)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                if self.analizer.status != .running {
                    self.analize(self.path)
                } else {
                    self.analizer.stop()
                }
            }) {
                Image(systemName: self.analizer.status != .running ? "play.fill" : "stop.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 10)
            .help(Text("\(self.analizer.status != .running ? "Run" : "Stop") the analysis"))
        }
    }
    
    private func analize(_ path: String) {
        self.analizer.start(self.path) { newPath in
            DispatchQueue.main.async {
                self.path = newPath
            }
        }
    }
    
    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a folder to analyze"
        openPanel.prompt = "Select"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    self.path = url.path
                }
            }
        }
    }
    
    private func openSettingsWindow() {
        if let window = self.settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
        
        window.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - 400)/2,
            y: ((NSScreen.main!.frame.height - 320)/1.8)
        ))
        
        window.makeKeyAndOrderFront(nil)
        
        self.settingsWindow = window
    }
}

struct StatusView: View {
    let status: Analizer.Status
    let duration: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch status {
            case .running:
                Text("Analysis in progress").font(.headline)
                Divider()
                Text("The folder is being scanned...").font(.footnote)
                Text("Duration: \(duration)").font(.footnote).foregroundColor(.secondary)
            case .completed:
                Text("Analysis completed").font(.headline)
                Divider()
                Text("Scan completed successfully").font(.footnote)
                Text("Duration: \(duration)").font(.footnote).foregroundColor(.secondary)
            case .cancelled:
                Text("Analysis cancelled").font(.headline)
                Divider()
                Text("The operation was stopped by user").font(.footnote)
            case .error:
                Text("Analysis error").font(.headline)
                Divider()
                Text("An error occurred during the scan").font(.footnote)
            default:
                Text("Ready").font(.headline)
                Divider()
                Text("Click the play button to start analysis").font(.footnote)
            }
        }
        .padding()
        .frame(width: 250)
    }
}
