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
    
    @ObservedObject var bleManager = BLEManager.shared
    
    var body: some View {
        ScrollView {
            DetailHeaderView(Header(title: String(format: "%.0f", bleManager.batteryLevel), titleUnits: "%", icon: {
                if bleManager.batteryLevel > 20 {
                    return "battery.100percent"
                } else if bleManager.batteryLevel > 10 {
                    return "battery.25percent"
                } else {
                    return "battery.0percent"
                }
            }(), accent: {
                if bleManager.batteryLevel > 20 {
                    return Color.green
                } else if bleManager.batteryLevel > 10 {
                    return Color.orange
                } else {
                    return Color.red
                }
            }()), width: UIScreen.main.bounds.width) {
                HStack {
                    DetailHeaderSubItemView(title: "Avg", value: "157")
                    DetailHeaderSubItemView(title: "Min", value: "64")
                    DetailHeaderSubItemView(title: "Max", value: "186")
                }
            }
            .listRowBackground(Color.clear)
            // FIXME:
//            List {
//                Section(footer: Text("Send a notification to your devices when your watch is on low battery.")) {
//                    Toggle("Notify on Low Battery", isOn: $sendLowBatteryNotification)
//                }
//                if sendLowBatteryNotification {
//                    Section {
//                        Toggle("Send to iPhone", isOn: $sendLowBatteryNotification)
//                        Toggle("Send to Watch", isOn: $sendLowBatteryNotification)
//                    }
//                }
//            }
        }
        .navigationTitle("Battery")
    }
}

#Preview {
    BatterySettingsView()
}
