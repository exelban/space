//
//  FooterView.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 25/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI

struct FooterView: View {
    @EnvironmentObject private var analizer: Analizer
    
    private var rootEntity: Entity? {
        analizer.analyzedEntities.first
    }
    
    private var folderCount: Int {
        guard let rootEntity = rootEntity else { return 0 }
        return countFolders(in: rootEntity) - 1
    }
    
    private var fileCount: Int {
        guard let rootEntity = rootEntity else { return 0 }
        return countFiles(in: rootEntity)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let stats = self.analizer.stats {
                    LabelValueItem(label: "Total Size", value: stats.formattedSize)
                    Spacer()
                    LabelValueItem(label: "Folders", value: "\(stats.folders)")
                    LabelValueItem(label: "Files", value: "\(stats.files)")
                } else {
                    Text("")
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
            .padding(.top, 10)
        }
    }
    
    private func countFolders(in entity: Entity) -> Int {
        var count = entity.isDirectory ? 1 : 0
        for child in entity.children where child.isDirectory {
            count += countFolders(in: child)
        }
        return count
    }
    
    private func countFiles(in entity: Entity) -> Int {
        var count = entity.isDirectory ? 0 : 1
        for child in entity.children {
            count += countFiles(in: child)
        }
        return count
    }
}

struct LabelValueItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .bottom) {
            Text(self.label).font(.subheadline).foregroundColor(.secondary)
            Text(self.value).font(.headline).monospaced()
        }
    }
}
