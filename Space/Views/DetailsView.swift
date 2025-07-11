//
//  DetailsView.swift
//  Space
//
//  Created by Serhiy Mytrovtsiy on 06/07/2025
//  Using Swift 6.0
//  Running on macOS 15.5
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI
import Charts

struct DetailsView: View {
    @EnvironmentObject private var analizer: Analizer
    @State private var selectedEntity: Entity? = nil
    @State var selection: Int?
    
    private var rootEntity: Entity? {
        analizer.analyzedEntities.first
    }
    private var entities: [Entity] {
        if let root = rootEntity {
            return root.children.sorted { first, second in
                return first.size > second.size
            }.prefix(10).map { $0 }
        }
        return []
    }
    
    private static let chartColors: [Color] = [
      .red, .green, .blue, .yellow, .purple, .indigo, .brown, .mint, .orange, .pink, .cyan
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Chart(self.entities, id: \.id) { product in
                SectorView(product: product, selectedEntity: self.$selectedEntity)
            }
            .chartLegend(.hidden)
            .chartBackground { proxy in
                VStack {
                    Text((self.selectedEntity?.formattedSize ?? self.analizer.stats?.formattedSize) ?? "")
                        .font(.title2)
                    Text(self.selectedEntity?.name ?? rootEntity?.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 150, alignment: .center)
                        .truncationMode(.tail)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .chartForegroundStyleScale(domain: .automatic, range: Self.chartColors)
            .chartGesture { chart in
                SpatialTapGesture().onEnded { event in
                    let center = CGPoint(x: chart.plotSize.width / 2, y: chart.plotSize.height / 2)
                    let vector = CGPoint(x: event.location.x - center.x, y: event.location.y - center.y)
                    
                    let distance = sqrt(pow(vector.x, 2) + pow(vector.y, 2))
                    let radius = min(chart.plotSize.width, chart.plotSize.height) / 2
                    
                    if distance < radius * 0.75 || distance > radius {
                        self.selectedEntity = nil
                        return
                    }
                    
                    let angle = atan2(vector.y, vector.x)
                    let normalizedAngle = angle < 0 ? angle + 2 * Double.pi : angle
                    
                    var startAngle: Double = -Double.pi / 2
                    let totalSize = self.entities.reduce(0) { $0 + $1.size }
                    
                    for child in self.entities {
                        let proportion = Double(child.size) / Double(totalSize)
                        let sectorAngle = proportion * 2 * Double.pi
                        let endAngle = startAngle + sectorAngle
                        
                        let normalizedStartAngle = startAngle < 0 ? startAngle + 2 * Double.pi : startAngle
                        let normalizedEndAngle = endAngle < 0 ? endAngle + 2 * Double.pi : endAngle
                        
                        if (normalizedStartAngle < normalizedEndAngle &&
                            normalizedAngle >= normalizedStartAngle &&
                            normalizedAngle <= normalizedEndAngle) ||
                           (normalizedStartAngle > normalizedEndAngle &&
                            (normalizedAngle >= normalizedStartAngle ||
                             normalizedAngle <= normalizedEndAngle)) {
                            if self.selectedEntity?.path == child.path {
                                self.selectedEntity = nil
                                break
                            }
                            
                            self.selectedEntity = child
                            break
                        }
                        
                        startAngle = endAngle
                    }
                }
            }
            
            VStack(spacing: 4) {
                if let stats = self.analizer.stats {
                    LabelValueItem("Folder", value: rootEntity?.path ?? "", valueSelection: true)
                    LabelValueItem("Total size", value: stats.formattedSize)
                    LabelValueItem("Objects", value: "\(stats.folders + stats.files)")
                    LabelValueItem("Folders", value: "\(stats.folders)")
                    LabelValueItem("Files", value: "\(stats.files)")
                }
            }
        }
        .padding()
    }
    
    private func findSelectedEntity(_ value: Int) -> Entity? {
        var accumulatedCount: Int64 = 0
        return self.entities.first { entity in
            accumulatedCount += entity.size
            return value <= accumulatedCount
        }
    }
}

struct SectorView: ChartContent {
    let product: Entity
    @Binding var selectedEntity: Entity?
    
    var body: some ChartContent {
        SectorMark(
            angle: .value(Text(verbatim: product.path), product.size),
            innerRadius: .ratio(0.8),
            angularInset: 2,
        )
        .cornerRadius(2)
        .opacity(self.selectedEntity == nil ? 1.0 : (self.selectedEntity?.path == product.path ? 1.0 : 0.5))
        .foregroundStyle(by: .value(Text(verbatim: product.path), product.path))
    }
}

struct LabelValueItem: View {
    private let label: String
    private let value: String
    
    private let valueSelection: Bool
    
    init(_ label: String, value: String, valueSelection: Bool = false) {
        self.label = label
        self.value = value
        self.valueSelection = valueSelection
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(self.label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if self.valueSelection {
                Text(self.value)
                    .font(.headline)
                    .monospaced()
                    .textSelection(.enabled)
            } else {
                Text(self.value)
                    .font(.headline)
                    .monospaced()
            }
        }
    }
}
