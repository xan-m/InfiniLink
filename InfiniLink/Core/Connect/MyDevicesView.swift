//
//  MyDevicesView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/17/24.
//

import SwiftUI

struct MyDevicesView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var bleManager = BLEManager.shared
    
    @State private var showConnectSheet = false
    @State private var showSettings = false
    @State private var showUnpairConfirmation = false
    
    @State private var selectedWatch: Device!
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink("", isActive: $showSettings, destination: {
                    if let selectedWatch {
                        List {
                            Section {
                                AboutRowView("Name", value: selectedWatch.name ?? "InfiniTime")
                                AboutRowView("Software Version", value: selectedWatch.firmware ?? "Unknown")
                                AboutRowView("Manufacturer", value: selectedWatch.manufacturer ?? "Unknown")
                                AboutRowView("Model Name", value: selectedWatch.modelNumber ?? "Unknown")
                                AboutRowView("UUID", value: selectedWatch.bleUUID ?? "Unknown")
                            }
                            Section {
                                AboutRowView("File System", value: selectedWatch.blefsVersion ?? "Unknown")
                                AboutRowView("Hardware Revision", value: selectedWatch.hardwareRevision ?? "Unknown")
                            }
                            Section {
                                Button("Unpair", role: .destructive) {
                                    showUnpairConfirmation = true
                                }
                                .foregroundStyle(.red)
                                .alert("Are you sure you want to unpair from \(selectedWatch.name ?? "InfiniTime")?", isPresented: $showUnpairConfirmation) {
                                    Button(role: .destructive) {
                                        bleManager.unpair(device: selectedWatch)
                                        showSettings = false
                                    } label: {
                                        Text("Unpair")
                                    }
                                }
                            }
                        }
                        .navigationTitle(selectedWatch.name ?? "InfiniTime")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                })
                .hidden()
                List {
                    Section {
                        ForEach(deviceManager.watches, id: \.self) { watch in
                            HStack {
                                Button {
                                    bleManager.switchDevice(device: watch)
                                    dismiss()
                                } label: {
                                    DeviceRowView(watch: watch)
                                }
                                .disabled(bleManager.pairedDeviceID ?? "" == watch.uuid ?? "")
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.accentColor)
                                    .onTapGesture {
                                        selectedWatch = watch
                                        showSettings = true
                                    }
                            }
                            .imageScale(.large)
                        }
                    }
                    Section {
                        Button {
                            showConnectSheet = true
                            bleManager.isPairingNewDevice = true
                        } label: {
                            Text("Pair New Device")
                        }
                    }
                }
            }
            .navigationTitle("My Watches")
            .toolbar {
                Button("Done", role: .cancel) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showConnectSheet, onDismiss: { bleManager.isPairingNewDevice = false }) {
                ConnectView()
            }
            .onAppear {
                deviceManager.fetchAllDevices()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct DeviceRowView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var bleManager = BLEManager.shared
    
    let watch: Device
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundStyle(.blue)
                .font(.body.weight(.semibold))
                .opacity(bleManager.pairedDeviceID  == watch.uuid ? 1 : 0)
            WatchFaceView(watchface: .constant(UInt8(watch.watchface)), device: watch)
                .frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 4) {
                Text(watch.name ?? "InfiniTime")
                    .foregroundStyle(Color.primary)
                    .font(.title2.weight(.semibold))
                Text("InfiniTime " + "\(watch.firmware ?? "")")
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
    }
}

#Preview {
    MyDevicesView()
}
