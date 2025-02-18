//
//  BLEUpdateHandler.swift
//  InfiniLink
//
//  Created by Alex Emry on 10/1/21.
//
//

import CoreBluetooth
import CoreData
import SwiftUI

struct BLECharacteristicHandler {
    let bleFs = BLEFSHandler.shared
    let bleManager = BLEManager.shared
    let healthKitManager = HealthKitManager.shared
    let chartManager = ChartManager.shared
    let notificationManager = NotificationManager.shared
    let remindersManager = RemindersManager.shared
    let deviceManager = DeviceManager.shared
    let fitnessCalculator = FitnessCalculator.shared
    let persistenceController = PersistenceController.shared
    
    @AppStorage("filterHeartRateData") var filterHeartRateData: Bool = false
    @AppStorage("remindOnStepGoalCompletion") var remindOnStepGoalCompletion = true
    
    @AppStorage("lastHeartRateUpdateTimestamp") var lastHeartRateUpdateTimestamp: Double = 0
    @AppStorage("lastTimeCheckCompleted") var lastTimeCheckCompleted: Double = 0
    @AppStorage("lastTimeStepGoalNotified") var lastTimeStepGoalNotified: Double = 0
    
    func fetchHeartPoints() -> [HeartDataPoint] {
        let fetchRequest: NSFetchRequest<HeartDataPoint> = HeartDataPoint.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            return try persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            log("Error fetching heart points: \(error)", caller: "BLECharacteristicHandler")
            return []
        }
    }
    
    func heartRate(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
    }
    
    func handleDiscoveredCharacteristics(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case bleManager.cbuuidList.musicControl:
            peripheral.setNotifyValue(true, for: characteristic)
            bleManager.musicChars.control = characteristic
        case bleManager.cbuuidList.statusControl:
            bleManager.musicChars.status = characteristic
        case bleManager.cbuuidList.musicTrack:
            bleManager.musicChars.track = characteristic
        case bleManager.cbuuidList.musicArtist:
            bleManager.musicChars.artist = characteristic
        case bleManager.cbuuidList.positionTrack:
            bleManager.musicChars.position = characteristic
        case bleManager.cbuuidList.lengthTrack:
            bleManager.musicChars.length = characteristic
        case bleManager.cbuuidList.hrm:
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.bat:
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.motion:
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.blefsTransfer:
            bleManager.blefsTransfer = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.notify:
            bleManager.notifyCharacteristic = characteristic
        case bleManager.cbuuidList.stepCount:
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.time:
            bleManager.currentTimeService = characteristic
            BLEWriteManager().setTime(characteristic: characteristic)
        case bleManager.cbuuidList.weather:
            bleManager.weatherCharacteristic = characteristic
            
        case bleManager.cbuuidList.dfuControlPoint:
            bleManager.dfuControlPointCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        case bleManager.cbuuidList.dfuPacket:
            bleManager.dfuPacketCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            
        case bleManager.cbuuidList.navigationFlags:
            bleManager.navigationFlagsCharacteristic = characteristic
        case bleManager.cbuuidList.navigationNarrative:
            bleManager.navigationNarrativeCharacteristic = characteristic
        case bleManager.cbuuidList.navigationDistance:
            bleManager.navigationDistanceCharacteristic = characteristic
        case bleManager.cbuuidList.navigationProgress:
            bleManager.navigationProgressCharacteristic = characteristic
            
        case bleManager.cbuuidList.sleep:
            peripheral.setNotifyValue(true, for: characteristic)
        default:
            break
        }
    }
    
    func handleUpdates(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case bleManager.cbuuidList.musicControl:
            let musicControl = [UInt8](characteristic.value!)
            
            MusicController.shared.controlMusic(controlNumber: Int(musicControl[0]))
        case bleManager.cbuuidList.hrm:
            let bpm = heartRate(from: characteristic)
            
            bleManager.heartRate = Double(bpm)
            
            if bpm > 0 {
                let currentTime = Date().timeIntervalSince1970
                let timeDifference = currentTime - lastHeartRateUpdateTimestamp
                
                // Check if the last data point is available and if filtering is enabled
                if let referenceValue = fetchHeartPoints().last?.value, filterHeartRateData {
                    let isWithinRange = abs(referenceValue - bleManager.heartRate) <= 25
                    
                    // Update heart rate if within the valid range or recent enough
                    if isWithinRange || timeDifference <= 15 {
                        updateHeartRate(bpm: bpm)
                    } else {
                        log("Abnormal heart rate value detected: \(bpm)", caller: "BLECharacteristicHandler")
                    }
                } else {
                    // If no last data point or filtering is not applied, update heart rate
                    updateHeartRate(bpm: bpm)
                }
            }
        case bleManager.cbuuidList.bat:
            guard let value = characteristic.value else { break }
            let batData = [UInt8](value)
            
            bleManager.batteryLevel = Double(batData[0])
            bleManager.hasLoadedBatteryLevel = true
            
            chartManager.addBatteryDataPoint(batteryLevel: Double(batData[0]), time: Date())
        case bleManager.cbuuidList.stepCount:
            guard let value = characteristic.value else { break }
            let stepData = [UInt8](value)
            let stepCount = Int(stepData[0]) + (Int(stepData[1]) * 256) + (Int(stepData[2]) * 65536) + (Int(stepData[3]) * 16777216)
            
            bleManager.stepCount = stepCount
            
            if stepCount != 0 {
                healthKitManager.readCurrentSteps { value, error in
                    if let error = error {
                        log("Error reading current steps: \(error.localizedDescription)", caller: "HealthKitManager")
                        return
                    }
                    
                    let currentSteps = value ?? 0.0
                    let newSteps = Double(stepCount)
                    
                    let stepsToAdd = max(newSteps - currentSteps, 0)
                    healthKitManager.writeSteps(date: Date(), stepsToAdd: stepsToAdd)
                }
                
                StepCountManager.shared.setStepCount(steps: Int32(stepCount), isArbitrary: false, for: Date())
            }
        case bleManager.cbuuidList.blefsTransfer:
            guard let value = characteristic.value else { break }
            
            bleFs.handleResponse(responseData: [UInt8](value))
        case bleManager.cbuuidList.motion:
            // As of now, we don't need the motion data, but it constantly updates, so to work around iOS timer restrictions, we use this to fetch data in the background
            let currentTime = Date().timeIntervalSince1970
            let timeDifference = currentTime - lastTimeCheckCompleted
            
            // Only update every five seconds
            if timeDifference > 5 {
                remindersManager.checkForDueItems()
                notificationManager.checkAndNotifyForWaterReminders()

                // TODO: we need to make sure this is in fact better than using onChange in ContentView
                
                checkForCompletedStepGoal()
                
                lastTimeCheckCompleted = Date().timeIntervalSince1970
            }
        case bleManager.cbuuidList.sleep:
            guard let data = characteristic.value else { break }
            
            let timestampBytes = data[0...3]
            let minutesAsleepBytes = data[4...5]
            let minutesAsleepByteArray = [UInt8](minutesAsleepBytes)
            
            let minutesAsleep = UInt16(minutesAsleepByteArray[0]) << 8 | UInt16(minutesAsleepByteArray[1])
            let timestamp = Date(timeIntervalSince1970: TimeInterval(UInt32(timestampBytes[0]) << 24 |
                                                     UInt32(timestampBytes[1]) << 16 |
                                                     UInt32(timestampBytes[2]) << 8 |
                                                     UInt32(timestampBytes[3])))
            
            SleepController.shared.sleep = SleepData(startDate: timestamp, endDate: timestamp.addingTimeInterval(Double(minutesAsleep * 60)))
        case bleManager.cbuuidList.dfuPacket:
            guard let data = characteristic.value else { break }
            log("Response from DFU Packet characteristic: \(String(decoding: data, as: UTF8.self))")
        case bleManager.cbuuidList.dfuControlPoint:
            guard let data = characteristic.value else { break }
            log("Response from DFU Control Point: \(String(decoding: data, as: UTF8.self))")
        default:
            break
        }
    }
    
    private func checkForCompletedStepGoal() {
        if bleManager.stepCount >= Int(deviceManager.settings.stepsGoal) && remindOnStepGoalCompletion {
            let currentTime = Date().timeIntervalSince1970
            let twentyFourHours: TimeInterval = 86400
            
            if (currentTime - lastTimeStepGoalNotified) >= twentyFourHours {
                notificationManager.sendStepGoalReachedNotification()
                lastTimeStepGoalNotified = currentTime
            }
        }
    }
    private func updateHeartRate(bpm: Int) {
        lastHeartRateUpdateTimestamp = Date().timeIntervalSince1970
        
        healthKitManager.writeHeartRate(date: Date(), dataToAdd: bleManager.heartRate)
        chartManager.addHeartRateDataPoint(heartRate: Double(bpm), time: Date())
        
        notificationManager.sendHeartRangeNotification(bpm)
    }
}
