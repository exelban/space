//
//  ListView.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 25/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI

struct ListView: View {
    @EnvironmentObject private var analizer: Analizer
    
    @State private var sortOrder = [KeyPathComparator(\Entity.size, order: .reverse)]
    @State private var expandedFolders: Set<String> = []
    @State private var flattenedEntities: [Entity] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Table(of: Entity.self, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \Entity.name) { entity in
                        HStack {
                            ForEach(0..<entity.level, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 14)
                            }
                            
                            if entity.isDirectory {
                                Image(systemName: self.isExpanded(path: entity.path) ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 13)
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.gray)
                            }
                            
                            Text(entity.name)
                                .fontWeight(.medium)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if entity.isDirectory {
                                self.toggleFolder(path: entity.path)
                            }
                        }
                    }
                    
                    TableColumn("Type", value: \Entity.type) { entity in
                        Text(entity.isDirectory ? "Folder" : "File")
                            .foregroundColor(.secondary)
                    }
                    .width(80)
                    
                    TableColumn("Items", value: \Entity.items) { entity in
                        Text(entity.isDirectory ? "\(entity.items)" : "")
                            .foregroundColor(.secondary)
                    }
                    .width(60)
                    
                    TableColumn("Size", value: \Entity.size) { entity in
                        Text(entity.formattedSize)
                            .font(.headline)
                    }
                    .width(80)
                    
                    TableColumn("") { entity in
                        Button(action: {
                            self.openInFinder(path: entity.path)
                        }) {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Open in Finder")
                    }
                    .width(30)
                } rows: {
                    ForEach(self.flattenedEntities) { entity in
                        TableRow(entity)
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    self.openInFinder(path: entity.path)
                                }
                            }
                    }
                }
                .onChange(of: self.analizer.status) { _, _ in
                    if self.analizer.status == .running {
                        self.flattenedEntities = []
                        self.expandedFolders.removeAll()
                        self.sortOrder = [KeyPathComparator(\Entity.size, order: .forward)]
                    }
                }
                .onChange(of: self.analizer.analyzedEntities) { _, _ in
                    self.updateFlattenedEntities()
                }
                .onChange(of: self.expandedFolders) { _, _ in
                    self.updateFlattenedEntities()
                }
                .onChange(of: self.sortOrder) { _, _ in
                    self.updateFlattenedEntities()
                }
                .onAppear {
                    self.updateFlattenedEntities()
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .padding()
        }
    }
    
    private func sortedChildren(_ children: [Entity]) -> [Entity] {
        guard let value = self.sortOrder.first else { return children }
        
        return children.sorted { first, second in
            let result: Bool
            
            switch value.keyPath {
            case \Entity.name:
                result = first.name.localizedStandardCompare(second.name) == .orderedAscending
            case \Entity.type:
                result = first.type < second.type
            case \Entity.items:
                result = first.items < second.items
            default:
                result = first.size < second.size
            }
            
            return value.order == .forward ? result : !result
        }
    }
    
    private func updateFlattenedEntities() {
        guard let rootEntity = self.analizer.analyzedEntities.first else {
            self.flattenedEntities = []
            return
        }
        self.flattenedEntities = self.flattenHierarchy(children: self.sortedChildren(rootEntity.children), level: 0)
    }
    
    private func flattenHierarchy(children: [Entity], level: Int) -> [Entity] {
        var result: [Entity] = []
        
        for entity in children {
            var entityWithLevel = entity
            entityWithLevel.level = level
            result.append(entityWithLevel)
            
            if entity.isDirectory && self.isExpanded(path: entity.path) {
                result.append(contentsOf: self.flattenHierarchy(children: self.sortedChildren(entity.children), level: level + 1))
            }
        }
        
        return result
    }
    
    private func isExpanded(path: String) -> Bool {
        self.expandedFolders.contains(path)
    }
    
    private func toggleFolder(path: String) {
        if self.expandedFolders.contains(path) {
            self.expandedFolders.remove(path)
        } else {
            self.expandedFolders.insert(path)
        }
    }
    
    private func openInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
