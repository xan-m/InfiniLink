//
//  HeartView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/5/24.
//

import SwiftUI
import CoreData

struct HeartView: View {
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var chartManager = ChartManager.shared
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\.timestamp)]) var heartDataPoints: FetchedResults<HeartDataPoint>
    
    var heartPointValues: [Double] {
        return heartDataPoints.compactMap({ $0.value })
    }
    
    func heartRate(for val: Double) -> String {
        return val > 0 ? String(format: "%.0f", val) : "--"
    }
    func units(for seconds: Int) -> String {
        if seconds >= 172800 {
            return NSLocalizedString("Several days ago", comment: "")
        } else if seconds >= 86400 {
            let days = seconds / 86400
            return NSLocalizedString("\(days) day\(days == 1 ? "" : "s") ago", comment: "")
        } else if seconds >= 3600 {
            let hours = seconds / 3600
            return NSLocalizedString("\(hours) hour\(hours == 1 ? "" : "s") ago", comment: "")
        } else if seconds >= 60 {
            let minutes = seconds / 60
            return NSLocalizedString("\(minutes) minute\(minutes == 1 ? "" : "s") ago", comment: "")
        }
        return NSLocalizedString("Now", comment: "")
    }
    func timestamp(for heartPoint: HeartDataPoint?) -> String? {
        guard let timeInterval = heartPoint?.timestamp?.timeIntervalSinceNow else { return " " }
        
        return units(for: Int(abs(timeInterval)))
    }
    
    var body: some View {
        GeometryReader { geo in
            List {
                Group {
                    Section {
                        DetailHeaderView(Header(title: String(format: "%.0f", heartPointValues.last ?? 0), subtitle: timestamp(for: heartDataPoints.last), units: "BPM", icon: "heart.fill", accent: .red), width: geo.size.width, animate: (heartDataPoints.last?.timestamp?.timeIntervalSinceNow ?? 60) < 60) {
                            HStack {
                                DetailHeaderSubItemView(
                                    title: "Min",
                                    value: heartRate(for: heartPointValues.min() ?? 0)
                                )
                                DetailHeaderSubItemView(
                                    title: "Avg",
                                    value: heartRate(for: {
                                        guard heartPointValues.count > 0 else { return Double(0) }
                                        
                                        return Double(heartPointValues.compactMap({ Int($0) }).reduce(0, +) / heartPointValues.count)
                                    }()))
                                DetailHeaderSubItemView(
                                    title: "Max",
                                    value: heartRate(for: heartPointValues.max() ?? 0)
                                )
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    HeartChartView()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Heart Rate")
        .toolbar {
            NavigationLink {
                HeartSettingsView()
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    NavigationView {
        HeartView()
            .onAppear {
                BLEManager.shared.heartRate = 76
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}
