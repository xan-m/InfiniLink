//
//  FileSystemDetailView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/7/24.
//

import SwiftUI

struct FileSystemDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var bleFs = BLEFSHandler.shared
    @ObservedObject var fileSystemViewModel = FileSystemViewModel.shared
    
    @State var settings: Settings? = nil
    
    @State var textData: String? = nil
    @State var imageData: UIImage? = nil
    @State var csvData: [[String]]? = nil
    
    @State private var isLoadingFile = true
    
    let fileName: String
    
    var isSettings: Bool {
        return fileName == "settings.dat"
    }
    
    func row(key: String, value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoadingFile {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let settings = settings {
                        List {
                            row(key: NSLocalizedString("Display Timeout", comment: ""), value: "\(settings.screenTimeOut / 1000) Seconds")
                            row(key: NSLocalizedString("Brightness Level", comment: ""), value: {
                                switch settings.brightLevel {
                                case .Low:
                                    return "Low"
                                case .Mid:
                                    return "Mid"
                                case .High:
                                    return "High"
                                }
                            }())
                            row(key: NSLocalizedString("Time Format", comment: ""), value: {
                                switch settings.clockType {
                                case .H12:
                                    return "12 Hour"
                                case .H24:
                                    return "24 Hour"
                                }
                            }())
                            row(key: NSLocalizedString("Steps Goal", comment: ""), value: String(settings.stepsGoal))
                            row(key: NSLocalizedString("Weather Format", comment: ""), value: {
                                switch settings.weatherFormat {
                                case .Imperial:
                                    return "Imperial"
                                case .Metric:
                                    return "Metric"
                                }
                            }())
                            row(key: NSLocalizedString("Hourly Chimes", comment: ""), value: {
                                switch settings.chimesOption {
                                case .None:
                                    return "None"
                                case .Hours:
                                    return "Hour"
                                case .HalfHours:
                                    return "Half Hour"
                                }
                            }())
                        }
                    } else {
                        ScrollView {
                            VStack {
                                if let textData {
                                    Text(textData)
                                } else if let csvData {
                                    VStack(spacing: 0) {
                                        ForEach(csvData, id: \.self) { rows in
                                            HStack(spacing: 0) {
                                                ForEach(rows, id: \.self) { field in
                                                    Text(field)
                                                        .padding(6)
                                                    Divider()
                                                }
                                            }
                                            .padding(6)
                                            Divider()
                                        }
                                    }
                                } else if let imageData {
                                    Image(uiImage: imageData)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .toolbar {
                Button("Done", role: .cancel) {
                    dismiss()
                }
            }
            .onAppear {
                self.settings = nil
                
                if isSettings {
                    bleFs.readSettings { settings in
                        self.settings = settings
                        self.isLoadingFile = false
                        
                        // While we're already loading the settings, make sure we keep the vars updated
                        DeviceManager.shared.updateSettings(settings: settings)
                    }
                } else {
                    bleFs.readFile(fileSystemViewModel.getDir(input: fileName)) { data in
                        let `extension` = fileName.components(separatedBy: ".").last!
                        
                        guard let info = try? bleFs.convertDataToReadableFile(data: data, fileExtension: `extension`) else { return }
                        
                        switch `extension` {
                        case "txt":
                            self.textData = info as? String
                        case "json":
                            self.textData = bleFs.jsonToMultilineString(info as! Data)
                        case "csv":
                            self.csvData = info as? [[String]]
                        default:
                            self.textData = "This file is not currently supported."
                        }
                        
                        self.isLoadingFile = false
                    }
                }
            }
            .navigationTitle(isSettings ? "Settings" : fileName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
