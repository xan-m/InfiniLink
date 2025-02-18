//
//  DeviceConnectionManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/16/24.
//

import SwiftUI
import CoreData
import CoreBluetooth

class DeviceManager: ObservableObject {
    struct cbuuid {
        let modelNumber = CBUUID(string: "2A24")
        let serial = CBUUID(string: "2A25")
        let firmware = CBUUID(string: "2A26")
        let hardwareRevision = CBUUID(string: "2A27")
        let softwareRevision = CBUUID(string: "2A28")
        let manufacturer = CBUUID(string: "2A29")
        let blefsVersion = CBUUID(string: "adaf0100-4669-6c65-5472-616e73666572")
    }
    let cbuuids = cbuuid()
    
    let persistenceController = PersistenceController.shared
    let bleManager = BLEManager.shared
    
    static let shared = DeviceManager()
    
    var name: String {
        return bleManager.pairedDevice?.name ?? "InfiniTime"
    }
    var modelNumber: String {
        return bleManager.pairedDevice?.modelNumber ?? ""
    }
    var serial: String {
        return bleManager.pairedDevice?.serial ?? ""
    }
    var firmware: String {
        return bleManager.pairedDevice?.firmware ?? "1.0.0"
    }
    var hardwareRevision: String {
        return bleManager.pairedDevice?.hardwareRevision ?? ""
    }
    var softwareRevision: String {
        return bleManager.pairedDevice?.softwareRevision ?? ""
    }
    var manufacturer: String {
        return bleManager.pairedDevice?.manufacturer ?? ""
    }
    var blefsVersion: String {
        return bleManager.pairedDevice?.blefsVersion ?? ""
    }
    var bleUUID: String {
        return bleManager.pairedDevice?.bleUUID ?? ""
    }
    
    var hour24: Bool {
        return settings.clockType == .H24
    }
    
    @Published var settings = Settings()
    @Published var watches = [Device]()
    
    // Get persisted settings, before settings.dat has loaded
    func getSettings() {
        guard let device = bleManager.pairedDevice else { return }
        
        DispatchQueue.main.async {
            self.settings = Settings(
                version: UInt32(device.settingsVersion),
                stepsGoal: UInt32(device.stepsGoal),
                screenTimeOut: UInt32(device.screenTimeout),
                alwaysOnDisplay: device.alwaysOnDisplay,
                clockType: ClockType(rawValue: UInt8(device.clockType)) ?? .H24,
                weatherFormat: WeatherFormat(rawValue: UInt8(device.weatherFormat)) ?? .Metric,
                notificationStatus: Notification(rawValue: UInt8(device.notificationStatus)) ?? .On,
                watchFace: UInt8(device.watchface),
                chimesOption: ChimesOption(rawValue: UInt8(device.chimesOption)) ?? .None,
                pineTimeStyle: PineTimeStyleData(),
                watchFaceInfineat: WatchFaceInfineat(),
                wakeUpMode: .RaiseWrist,
                shakeWakeThreshold: UInt16(device.shakeWakeThreshold),
                brightLevel: BrightLevel(rawValue: UInt8(device.brightLevel)) ?? .Mid
            )
        }
    }
    
    func fetchDevice(with uuid: String? = nil) -> Device? {
        guard let id = uuid ?? bleManager.pairedDeviceID else { return nil }
        
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id)
        
        do {
            let context = persistenceController.container.viewContext
            let existingDevices = try context.fetch(fetchRequest)
            
            // There's already a paired watch
            if let existingDevice = existingDevices.first {
                return existingDevice
            }
            
            // There's not already a paired watch, create a new object to save
            let newDevice = Device(context: context)
            newDevice.uuid = id
            newDevice.bleUUID = id
            newDevice.blefsVersion = ""
            newDevice.firmware = ""
            newDevice.softwareRevision = ""
            newDevice.hardwareRevision = ""
            newDevice.manufacturer = ""
            newDevice.modelNumber = ""
            newDevice.serial = ""
            
            try context.save()
            
            return newDevice
        } catch {
            log("Error fetching or saving device: \(error)", caller: "DeviceManager")
            return nil
        }
    }
    
    // Get settings from settings file from watch and save it to keep device object up-to-date
    func updateSettings(settings: Settings) {
        guard let device = fetchDevice() else { return }
        
        device.brightLevel = Int16(settings.brightLevel.rawValue)
        device.chimesOption = Int16(settings.chimesOption.rawValue)
        device.clockType = Int16(settings.clockType.rawValue)
        device.notificationStatus = Int16(settings.notificationStatus.rawValue)
        device.shakeWakeThreshold = Int16(settings.watchFace)
        device.watchface = Int16(settings.watchFace)
        device.weatherFormat = Int16(settings.weatherFormat.rawValue)
        device.stepsGoal = Int32(settings.stepsGoal)
        device.screenTimeout = Int32(settings.screenTimeOut)
        
        let pineTimeStyle = PineTimeStyleWatchface(context: persistenceController.container.viewContext)
        pineTimeStyle.colorBG = Int16(settings.pineTimeStyle.ColorBG.rawValue)
        pineTimeStyle.colorBar = Int16(settings.pineTimeStyle.ColorBar.rawValue)
        pineTimeStyle.colorTime = Int16(settings.pineTimeStyle.ColorTime.rawValue)
        pineTimeStyle.guageStyle = Int16(settings.pineTimeStyle.gaugeStyle.rawValue)
        pineTimeStyle.weatherEnable = Int16(settings.pineTimeStyle.weatherEnable.rawValue)
        device.pineTimeStyle = pineTimeStyle
        
        let infineatWatchFace = InfineatWatchface(context: persistenceController.container.viewContext)
        infineatWatchFace.colorIndex = Int16(settings.watchFaceInfineat.colorIndex)
        infineatWatchFace.showSideCover = settings.watchFaceInfineat.showSideCover
        device.watchFaceInfineat = infineatWatchFace
        
        Task {
            await persistenceController.save()
        }
        
        getSettings()
    }
    
    func updateName(name: String, for device: Device) {
        guard let uuid = device.uuid else { return }
        guard let device = fetchDevice(with: uuid) else { return }
        
        device.name = name
        
        Task {
            await persistenceController.save()
        }
    }
    
    func getName(for uuid: String) -> String {
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        
        do {
            let existingDevices = try persistenceController.container.viewContext.fetch(fetchRequest)
            
            if let existingDevice = existingDevices.first {
                return existingDevice.name ?? "InfiniTime"
            }
            
            return "InfiniTime"
        } catch {
            return "InfiniTime"
        }
    }
    
    func removeDevice(_ device: Device) async {
        await persistenceController.container.performBackgroundTask { context in
            do {
                context.delete(device)
                try context.save()
            } catch {
                log(error.localizedDescription, caller: "DeviceManager - removeDevice")
            }
        }
    }
    
    func fetchAllDevices() {
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        
        do {
            self.watches = try self.persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            log("Error fetching devices: \(error.localizedDescription)", caller: "DeviceManager")
        }
    }
}

extension DeviceManager {
    func updateInfo(characteristic: CBCharacteristic) {
        guard let value = characteristic.value else { return }
        
        bleManager.pairedDevice.bleUUID = characteristic.uuid.uuidString
        
        switch characteristic.uuid {
        case cbuuids.modelNumber:
            bleManager.pairedDevice.modelNumber = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.serial:
            bleManager.pairedDevice.serial = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.firmware:
            bleManager.pairedDevice.firmware = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.hardwareRevision:
            bleManager.pairedDevice.hardwareRevision = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.softwareRevision:
            bleManager.pairedDevice.softwareRevision = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.manufacturer:
            bleManager.pairedDevice.manufacturer = String(data: value, encoding: .utf8) ?? ""
        case cbuuids.blefsVersion:
            let byteArray = [UInt8](characteristic.value!)
            bleManager.pairedDevice.blefsVersion = String(Int(byteArray[1])) + String(Int(byteArray[0]))
        default:
            break
        }
    }
    
    func readInfoCharacteristics(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case cbuuids.modelNumber, cbuuids.serial, cbuuids.firmware, cbuuids.hardwareRevision, cbuuids.softwareRevision, cbuuids.manufacturer, cbuuids.blefsVersion: peripheral.readValue(for: characteristic)
        default:
            break
        }
    }
}
