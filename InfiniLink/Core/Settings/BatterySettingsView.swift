//
//  BatterySettingsView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/5/24.
//

import SwiftUI

struct BatterySettingsView: View {
    @AppStorage("sendLowBatteryNotification") var sendLowBatteryNotification = true
    @AppStorage("sendLowBatteryNotificationToiPhone") var sendLowBatteryNotificationToiPhone = true
    @AppStorage("sendLowBatteryNotificationToWatch") var sendLowBatteryNotificationToWatch = true
    @AppStorage("watchNotifications") var watchNotifications = true
    
    @ObservedObject var bleManager = BLEManager.shared
    
    var body: some View {
        GeometryReader { geo in
            List {
                Section {
                    DetailHeaderView(Header(title: String(format: "%.0f", bleManager.batteryLevel), units: "%", icon: {
                        if bleManager.batteryLevel > 75 {
                            return "battery.100percent"
                        } else if bleManager.batteryLevel > 50 {
                            return "battery.75percent"
                        } else if bleManager.batteryLevel > 25 {
                            return "battery.50percent"
                        } else if bleManager.batteryLevel == 0 {
                            return "battery.0percent"
                        } else {
                            return "battery.25percent"
                        }
                    }(), accent: {
                        if bleManager.batteryLevel > 20 {
                            return Color.green
                        } else if bleManager.batteryLevel > 10 {
                            return Color.orange
                        } else if bleManager.batteryLevel == 0 {
                            return Color.gray
                        } else {
                            return Color.red
                        }
                    }()), width: geo.size.width) {
                        Color.clear
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                Section(footer: Text("Send a notification to your devices when your watch is on low battery.")) {
                    Toggle("Notify on Low Battery", isOn: $sendLowBatteryNotification)
                }
                if sendLowBatteryNotification {
                    Section(footer: watchNotifications ? nil : Text("Watch notifications are currently disabled.")) {
                        Toggle("Send to iPhone", isOn: $sendLowBatteryNotificationToiPhone)
                        Toggle("Send to Watch", isOn: $sendLowBatteryNotificationToWatch)
                            .disabled(!watchNotifications)
                    }
                }
            }
        }
        .navigationTitle("Battery")
    }
}

#Preview {
    BatterySettingsView()
}
