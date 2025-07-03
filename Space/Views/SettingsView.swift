//
//  SettingsView.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 25/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import Updater

struct SettingsView: View {
    @AppStorage("scanHiddenFiles") private var scanHiddenFiles: Bool = true
    
    private var version: String {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(versionNumber) (\(buildNumber))"
    }
    
    private let updater = Updater(name: "Space", providers: [Updater.Github(user: "exelban", repo: "space", asset: "Space.dmg")])
    
    @State private var checkingForUpdates: Bool = false
    @State private var updateAvailable: Bool = false
    @State private var updateUrl: URL? = nil
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            GroupBox {
                VStack(spacing: 10) {
                    Image(nsImage: NSImage(named: NSImage.Name("AppIcon"))!)
                    
                    VStack(spacing: 2) {
                        Text("Space")
                            .font(.title)
                        Text("Version \(self.version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if self.checkingForUpdates {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 20, height: 20)
                    } else {
                        if self.updateAvailable {
                            Button {
                                self.installUpdate()
                            } label: {
                                Label("Install Update", systemImage: "arrow.down.circle.fill")
                                    .font(.subheadline)
                            }
                        } else {
                            Button {
                                self.checkForUpdates()
                            } label: {
                                Label("Check for Updates", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hidden files and folders")
                        Spacer()
                        Toggle("", isOn: $scanHiddenFiles)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            }
            
            Button {
                if let url = URL(string: "https://github.com/exelban/space") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Homepage", systemImage: "link")
                    .font(.caption)
            }
            .buttonStyle(.link)
        }
        .frame(width: 400, height: 320)
        .padding()
    }
    
    private func checkForUpdates() {
        self.checkingForUpdates = true
        self.updateUrl = nil
        self.updateAvailable = false
        
        self.updater.check { result, error in
            self.checkingForUpdates = false
            guard error == nil else { return }
            let local = Updater.Tag(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
            guard let external = result, local < external.tag, let url = URL(string: external.url) else { return }
            self.updateAvailable = true
            self.updateUrl = url
        }
    }
    
    private func installUpdate() {
        self.checkingForUpdates = true
        guard let url = self.updateUrl else { return }
        self.updater.download(url, done: { path in
            self.updater.install(path: path)
            self.checkingForUpdates = false
        })
    }
}
