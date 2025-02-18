//
//  DeviceView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/3/24.
//

import SwiftUI

struct DeviceView: View {
    @Environment(\.openURL) var openURL
    
    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var personalizationController = PersonalizationController.shared
    @ObservedObject var remindersManager = RemindersManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    
    @AppStorage("sleepGoal") var sleepGoal = 28800
    @AppStorage("enableDeveloperMode") var enableDeveloperMode = false
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showMyDevicesSheet = false
    @State private var showNavigationTitle = false
    
    func connectionState() -> String {
        if bleManager.isBusy {
            return NSLocalizedString("Connecting...", comment: "")
        }
        switch (bleManager.isConnectedToPinetime, bleManager.hasLoadedBatteryLevel) {
        case (true, true):
            return NSLocalizedString("Connected", comment: "")
        case (true, false):
            return NSLocalizedString("Connecting...", comment: "")
        default:
            if bleManager.hasDisconnectedForUpdate {
                return NSLocalizedString("Installing update...", comment: "")
            } else {
                return NSLocalizedString("Disconnected", comment: "")
            }
        }
    }
    
    var body: some View {
        Group {
            if downloadManager.updateStarted {
                CurrentUpdateView()
            } else {
                if bleManager.isDeviceInRecoveryMode {
                    RecoveryModeView()
                } else {
                    content
                }
            }
        }
    }
    
    var content: some View {
        NavigationView {
            GeometryReader { geo in
                List {
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: [geo.frame(in: .global).minY])
                        }
                        .frame(height: 0)
                        VStack(spacing: 4) {
                            WatchFaceView(watchface: .constant(nil), device: bleManager.pairedDevice)
                                .frame(width: min(geo.size.width / 2.5, 185), height: min(geo.size.width / 2.5, 185), alignment: .center)
                                .clipped(antialiased: true)
                            VStack(spacing: 5) {
                                Group {
                                    Text(connectionState()) + Text(bleManager.hasLoadedBatteryLevel ? " • " : "") + Text(bleManager.hasLoadedBatteryLevel ? "\(String(format: "%.0f", bleManager.batteryLevel))%" : "")
                                        .foregroundColor({
                                            if bleManager.batteryLevel > 20 {
                                                return Color.gray
                                            } else if bleManager.batteryLevel > 10 {
                                                return Color.orange
                                            } else {
                                                return Color.red
                                            }
                                        }())
                                }
                                .foregroundStyle(Color.gray)
                                Text(deviceManager.name)
                                    .font(.title.weight(.bold))
                            }
                            .opacity(showNavigationTitle ? 0 : 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                        if downloadManager.updateAvailable {
                            if !DFUUpdater.shared.local && bleManager.dfuControlPointCharacteristic != nil {
                                Section {
                                    NavigationLink {
                                        SoftwareUpdateView()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(.infiniTime)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 50, height: 50)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Update Available")
                                                    .foregroundStyle(Color.primary)
                                                    .font(.body.weight(.bold))
                                                Group {
                                                    Text("InfiniTime ") + Text(downloadManager.updateVersion).font(.body.weight(.medium))
                                                }
                                                .foregroundStyle(Color.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        } else if let update = downloadManager.appUpdate {
                            Section {
                                Button {
                                    guard let testFlight = URL(string: testFlightLink) else { return }
                                    guard let appStore = URL(string: appStoreLink) else { return }
                                    
                                    openURL(update.isBeta ? testFlight : appStore)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image("appIcon")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("App Update Available")
                                                .foregroundStyle(Color.primary)
                                                .font(.body.weight(.bold))
                                            Group {
                                                Text("InfiniLink ") + Text(update.version).font(.body.weight(.medium))
                                            }
                                            .foregroundStyle(Color.gray)
                                        }
                                    }
                                }
                            }
                        }
                    Section {
                        NavigationLink {
                            ExerciseView()
                        } label: {
                            ListRowView(title: "Exercise", icon: "figure.run", iconColor: .orange)
                        }
                        NavigationLink {
                            HeartView()
                        } label: {
                            ListRowView(title: "Heart", icon: "heart.fill", iconColor: .red)
                        }
                        NavigationLink {
                            StepsView()
                        } label: {
                            ListRowView(title: "Steps", icon: "shoeprints.fill", iconColor: .blue)
                        }
                        NavigationLink {
                            SleepView()
                        } label: {
                            ListRowView(title: "Sleep", icon: "bed.double.fill", iconColor: Color(.systemPurple))
                        }
                    }
                    Section {
                        NavigationLink {
                            GeneralSettingsView()
                        } label: {
                            ListRowView(title: "General", icon: "gear", iconColor: .gray.opacity(0.9))
                        }
                        NavigationLink {
                            BatterySettingsView()
                        } label: {
                            ListRowView(title: "Battery", icon: "battery.100percent", iconColor: .green)
                        }
                        NavigationLink {
                            NotificationsSettingsView()
                        } label: {
                            ListRowView(title: "Notifications", icon: "bell.badge.fill", iconColor: .red)
                        }
                        NavigationLink {
                            DirectionsView()
                        } label: {
                            ListRowView(title: "Navigation", icon: "map.fill", iconColor: .blue)
                        }
                        NavigationLink {
                            WeatherView()
                        } label: {
                            ListRowView(title: "Weather", icon: "sun.max.fill", iconColor: .yellow)
                        }
                        NavigationLink {
                            MusicSettingsView()
                        } label: {
                            ListRowView(title: "Music", icon: "music.note", iconColor: .red)
                        }
                    }
                    Section {
                        /*
                         NavigationLink {
                         AlarmView()
                         } label: {
                         ListRowView(title: "Alarms", icon: "alarm.fill")
                         }
                         */
                    }
                    if enableDeveloperMode {
                        Section {
                            NavigationLink {
                                DeveloperView()
                            } label: {
                                ListRowView(title: "Developer", icon: "hammer.fill", iconColor: .gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle(showNavigationTitle ? deviceManager.name : "")
            .navigationBarTitleDisplayMode(.inline)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { values in
                guard let value = values.first else { return }
                
                self.showNavigationTitle = (value <= -135)
            }
            .onChange(of: bleManager.blefsTransfer) { blefsTransfer in
                if blefsTransfer != nil {
                    BLEFSHandler.shared.readSettings { settings in
                        deviceManager.updateSettings(settings: settings)
                    }
                }
            }
            .onAppear {
                if let pairedDeviceID = bleManager.pairedDeviceID {
                    bleManager.pairedDevice = deviceManager.fetchDevice(with: pairedDeviceID)
                    deviceManager.getSettings()
                }
                
                notificationManager.setWaterRemindersPerDay()
                remindersManager.requestAccess()
                remindersManager.fetchAllItems()
                downloadManager.updateAvailable = downloadManager.checkForUpdates(currentVersion: deviceManager.firmware)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showMyDevicesSheet = true
                    } label: {
                        Text("My Watches")
                    }
                }
            }
            .sheet(isPresented: $showMyDevicesSheet) {
                MyDevicesView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ListRowView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let title: String
    let icon: String
    let iconColor: Color
    
    init(title: String, icon: String, iconColor: Color? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor ?? .blue
    }
    
    var body: some View {
        Label {
            Text(NSLocalizedString(title, comment: ""))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 13).weight(.medium))
                .frame(width: 34, height: 34)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue = [CGFloat]()
    
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        if let newValue = nextValue().first {
            value = [newValue]
        }
    }
}

#Preview {
    DeviceView()
        .onAppear {
            BLEManager.shared.pairedDevice.firmware = "0.14.1"
            DownloadManager.shared.updateBody = "Testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing testing."
            DFUUpdater.shared.local = false
        }
}
