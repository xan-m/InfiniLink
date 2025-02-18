//
//  HealthKitManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 12/22/23.
//

import SwiftUI
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    @AppStorage("syncToAppleHealth") var syncToAppleHealth = true
    
    var healthStore: HKHealthStore?
    
    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }
    
    func writeSteps(date: Date, stepsToAdd: Double) {
        let stepType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        
        let stepsSample = HKQuantitySample(type: stepType, quantity: HKQuantity.init(unit: HKUnit.count(), doubleValue: stepsToAdd), start: date, end: date)
        
        if healthStore?.authorizationStatus(for: stepType) == .sharingAuthorized && syncToAppleHealth && stepsToAdd != 0 {
            if let healthStore = healthStore {
                healthStore.save(stepsSample, withCompletion: { success, error in
                    
                    if let error {
                        log(error.localizedDescription, caller: "HealthKitManager")
                        return
                    }
                    
                    if success {
                        log("Steps successfully saved", type: .info, caller: "HealthKitManager")
                        return
                    } else {
                        log("Unknown error while writing steps", caller: "HealthKitManager")
                    }
                })
            }
        }
    }
    
    func readCurrentSteps(completion: @escaping (Double?, Error?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity()?.doubleValue(for: HKUnit.count()) else {
                    completion(nil, error)
                    return
                }
                completion(sum, nil)
            }
        }

        healthStore?.execute(query)
    }
    
    func writeHeartRate(date: Date, dataToAdd: Double) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!

        let heartRateSample = HKQuantitySample(type: heartRateType, quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: dataToAdd), start: date, end: date)

        if healthStore?.authorizationStatus(for: heartRateType) == .sharingAuthorized && syncToAppleHealth {
            if let healthStore = healthStore {
                healthStore.save(heartRateSample, withCompletion: { success, error in
                    if let error = error {
                        log("Error saving heart rate: \(error.localizedDescription)", caller: "HealthKitManager")
                        return
                    }

                    if success {
                        log("Heart rate successfully saved", type: .info, caller: "HealthKitManager")
                    } else {
                        log("Unknown error while writing heart rate", caller: "HealthKitManager")
                    }
                })
            }
        }
    }
    
    func requestAuthorization() {
        let steps = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        let heartRate = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        
        guard let healthStore = self.healthStore else { return }
        
        healthStore.requestAuthorization(toShare: [steps, heartRate], read: [steps]) { success, error in
            if let error = error {
                log(error.localizedDescription, caller: "HealthKitManager")
            }
        }
    }
}
