//
//  analyzer.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 24/06/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI

struct Entity: Identifiable, Comparable {
    let id = UUID()
    let name: String
    let path: String
    let type: EntityType
    var size: Int64
    var children: [Entity]
    var level: Int = 0
    
    init(name: String, path: String, size: Int64 = 0, isDirectory: Bool = false, children: [Entity] = []) {
        self.name = name
        self.path = path
        self.size = size
        self.children = children
        self.type = isDirectory ? .folder : .file
    }
    
    static func < (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.size < rhs.size
    }
    
    var isDirectory: Bool {
        return self.type == .folder
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var items: Int {
        var count = self.isDirectory ? 0 : 1
        for child in children {
            count += child.items
        }
        return count
    }
}

enum EntityType: String, Comparable {
    case folder, file
    
    private var sortOrder: Int {
        switch self {
        case .folder:
            return 0
        case .file:
            return 1
        }
    }
    
    static func ==(lhs: EntityType, rhs: EntityType) -> Bool {
        return lhs.sortOrder == rhs.sortOrder
    }
    
    static func <(lhs: EntityType, rhs: EntityType) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
}

class Analizer: ObservableObject {
    @Published var status: Status = .unknown
    @Published var errorMessage: String?
    
    @Published var analyzedEntities: [Entity] = []
    @Published var stats: Stats?
    
    @AppStorage("scanHiddenFiles") private var scanHiddenFiles: Bool = true
    
    private var accumulatedScannedSize: Int64 = 0
    private let updateThreshold: Int64 = 10 * 1024 * 1024
    
    enum Status {
        case unknown, running, completed, cancelled, error
    }
    
    struct Stats {
        let start = Date()
        var duration: TimeInterval = 0
        
        var size: Int64 = 0
        var folders: Int = 0
        var files: Int = 0
        var entities: Int = 0
        
        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
        
        var formattedDuration: String {
            let duration = Int(self.duration)
            let hours = duration / 3600
            let minutes = (duration % 3600) / 60
            let seconds = duration % 60
            if hours > 0 {
                return String(format: "%dh %dm %ds", hours, minutes, seconds)
            } else if minutes > 0 {
                return String(format: "%dm %ds", minutes, seconds)
            } else {
                return String(format: "%ds", seconds)
            }
        }
    }
    
    public func start(_ path: String, pathCallback: ((String) -> Void)? = nil) {
        self.status = .running
        self.analyzedEntities = []
        self.stats = Stats()
        
        if FileManager.default.isReadableFile(atPath: path) {
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self.analyzeFolder(at: path)
                DispatchQueue.main.async {
                    self.analyzedEntities = results
                    if self.status != .cancelled {
                        self.status = .completed
                    }
                }
            }
        } else {
            self.requestFolderAccess { selectedURL in
                guard let selectedURL = selectedURL else { return }
                pathCallback?(selectedURL.path)
                DispatchQueue.global(qos: .userInitiated).async {
                    let results = self.analyzeFolder(at: selectedURL.path)
                    DispatchQueue.main.async {
                        self.analyzedEntities = results
                        if self.status != .cancelled {
                            self.status = .completed
                        }
                    }
                }
            }
        }
    }
    
    public func stop() {
        self.status = .cancelled
    }
    
    private func requestFolderAccess(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Please select a folder to analyze"
        openPanel.prompt = "Analyze"
        
        openPanel.begin { response in
            if response == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
    }
    
    private func analyzeFolder(at path: String) -> [Entity] {
        let fileManager = FileManager.default
        var rootEntity: Entity? = nil
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
            let rootName = (path as NSString).lastPathComponent
            let root = Entity(name: rootName, path: path, isDirectory: true)
            rootEntity = root
            DispatchQueue.main.async {
                self.analyzedEntities = [root]
            }
        }
        
        var enumerationOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !self.scanHiddenFiles {
            enumerationOptions.insert(.skipsHiddenFiles)
        }
        
        if let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: enumerationOptions, errorHandler: nil) {
            for case let url as URL in enumerator {
                if self.status == .cancelled { break }
                if url.lastPathComponent == ".DS_Store" { continue }
                self.processItem(url: url, rootEntity: &rootEntity, rootPath: path)
            }
        }
        
        guard let root = rootEntity else { return [] }
        return [root]
    }
    
    private func processItem(url: URL, rootEntity: inout Entity?, rootPath: String) {
        do {
            let attributes = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDirectory = attributes.isDirectory ?? false
            let size = attributes.fileSize ?? 0
            let path = url.path
            if !isDirectory && size == 0 { return }
            let entity = Entity(name: url.lastPathComponent, path: path, size: Int64(size), isDirectory: isDirectory)
            
            if var root = rootEntity {
                self.addToParent(entity: entity, root: &root, rootPath: rootPath)
                rootEntity = root
            }
            
            DispatchQueue.main.async {
                if let start = self.stats?.start {
                    self.stats?.duration = Date().timeIntervalSince(start)
                }
                self.stats?.entities += 1
                if isDirectory {
                    self.stats?.folders += 1
                } else {
                    self.stats?.files += 1
                    self.stats?.size += Int64(size)
                }
            }
            
            if !isDirectory {
                self.accumulatedScannedSize += Int64(size)
                if self.accumulatedScannedSize >= self.updateThreshold {
                    self.accumulatedScannedSize = 0
                    if let root = rootEntity {
                        DispatchQueue.main.async {
                            self.analyzedEntities = [root]
                        }
                    }
                }
            }
        } catch {
            print("error processing \(url.path): \(error)")
        }
    }
    
    private func addToParent(entity: Entity, root: inout Entity, rootPath: String) {
        let normalizedRootPath = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        
        var relativePath: String
        if entity.path.hasPrefix(normalizedRootPath) {
            relativePath = String(entity.path.dropFirst(normalizedRootPath.count))
        } else {
            relativePath = entity.path.replacingOccurrences(of: root.path, with: "")
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
        }
        
        if relativePath.isEmpty || !relativePath.contains("/") {
            if !root.children.contains(where: { $0.path == entity.path }) {
                root.children.append(entity)
            }
            root.size += entity.size
            return
        }
        
        let components = relativePath.split(separator: "/").map(String.init)
        self.addNestedEntity(entity: entity, parentPath: normalizedRootPath, pathComponents: components, currentIndex: 0, parent: &root)
    }
    
    private func addNestedEntity(entity: Entity, parentPath: String, pathComponents: [String], currentIndex: Int, parent: inout Entity) {
        if currentIndex == pathComponents.count - 1 {
            if !parent.children.contains(where: { $0.path == entity.path }) {
                parent.children.append(entity)
            }
            parent.size += entity.size
            return
        }
        
        let folderName = pathComponents[currentIndex]
        let folderPath = parentPath + folderName + "/"
        
        if let index = parent.children.firstIndex(where: { $0.name == folderName && $0.isDirectory }) {
            var childFolder = parent.children[index]
            self.addNestedEntity(entity: entity, parentPath: folderPath, pathComponents: pathComponents, currentIndex: currentIndex + 1, parent: &childFolder)
            parent.children[index] = childFolder
            parent.size += entity.size
            return
        }
        
        var newFolder = Entity(name: folderName, path: folderPath, isDirectory: true)
        
        self.addNestedEntity(entity: entity, parentPath: folderPath, pathComponents: pathComponents, currentIndex: currentIndex + 1, parent: &newFolder)
        
        parent.children.append(newFolder)
        parent.children.sort { $0.size > $1.size }
        parent.size += entity.size
    }
}
