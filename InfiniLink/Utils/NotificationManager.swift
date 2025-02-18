//
//  NotificationManager.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/8/24.
//

import SwiftUI
import UserNotifications
import EventKit

struct AppNotification {
    let title: String
    let subtitle: String
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private var batteryIsUnderTwenty: Bool = false
    private var batteryIsUnderTen: Bool = false
    
    let bleWriteManager = BLEWriteManager()
    let bleManager = BLEManager.shared
    
    init() {
        if !PersonalizationController.shared.showSetupSheet {
            requestNotificationAuthorization()
        }
    }
    
    @Published var canSendNotifications = false
    
    @AppStorage("watchNotifications") var watchNotifications = true
    @AppStorage("sendLowBatteryNotification") var sendBatteryNotifications = true
    @AppStorage("sendLowBatteryNotificationToiPhone") var sendLowBatteryNotificationToiPhone = true
    @AppStorage("sendLowBatteryNotificationToWatch") var sendLowBatteryNotificationToWatch = true
    
    @AppStorage("waterReminderAmount") var waterReminderAmount = 7
    @AppStorage("waterReminder") var waterReminder = true
    
    @AppStorage("minHeartRange") var minHeartRange = 40
    @AppStorage("maxHeartRange") var maxHeartRange = 150
    @AppStorage("heartRangeReminder") var heartRangeReminder = true
    @AppStorage("lastTimeMinHeartRangeNotified") var lastTimeMinHeartRangeNotified: Double = 0
    @AppStorage("lastTimeMaxHeartRangeNotified") var lastTimeMaxHeartRangeNotified: Double = 0
    
    private var nextReminderCheckDate: Date?
    private var waterReminderStartHour: Int = 8
    private var waterReminderEndHour: Int = 20
    private var waterReminderInterval: TimeInterval = 0
    
    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.canSendNotifications = true
                } else if error != nil {
                    self.canSendNotifications = false
                }
            }
        }
    }
    
    func sendNotificationToHost(_ notif: AppNotification) {
        let content = UNMutableNotificationContent()
        content.title = notif.title
        content.body = notif.subtitle
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                log("Error sending notification: \(error.localizedDescription)", caller: "NotificationManager")
            }
        }
    }
}

// MARK: Battery
extension NotificationManager {
    func checkToSendLowBatteryNotification() {
        if watchNotifications {
            let bat = bleManager.batteryLevel
            
            if bat > 20 {
                batteryIsUnderTwenty = false
                batteryIsUnderTen = false
            } else if (bat <= 20 && bat > 10) && !batteryIsUnderTwenty {
                self.sendLowBatteryNotification()
                self.batteryIsUnderTwenty = true
            } else if (bat <= 10 && bat > 5) && !batteryIsUnderTen {
                self.sendLowBatteryNotification()
                self.batteryIsUnderTen = true
            }
        }
    }
    
    private func sendLowBatteryNotification() {
        let bat = bleManager.batteryLevel
        let notif = AppNotification(title: NSLocalizedString("Battery Low", comment: ""), subtitle: "\(String(format: "%.0f", bat))% " + NSLocalizedString("battery remaining", comment: ""))
        
        if sendLowBatteryNotificationToWatch && sendBatteryNotifications {
            self.bleWriteManager.sendNotification(notif)
        }
        if sendLowBatteryNotificationToiPhone && sendBatteryNotifications {
            self.sendNotificationToHost(notif)
        }
    }
}

// MARK: Health
extension NotificationManager {
    func sendHeartRangeNotification(_ bpm: Int) {
        let currentTime = Date().timeIntervalSince1970
        
        if bpm < minHeartRange, (currentTime - lastTimeMinHeartRangeNotified) >= (60 * 10) {
            self.bleWriteManager.sendNotification(
                AppNotification(title: NSLocalizedString("Heart Rate Low", comment: ""), subtitle: NSLocalizedString("Your heart rate fell below \(minHeartRange) BPM", comment: ""))
            )
            self.lastTimeMinHeartRangeNotified = currentTime
        }
        if bpm > maxHeartRange, (currentTime - lastTimeMaxHeartRangeNotified) >= (60 * 10) {
            self.bleWriteManager.sendNotification(
                AppNotification(title: NSLocalizedString("Heart Rate High", comment: ""), subtitle: NSLocalizedString("Your heart rate rose above \(maxHeartRange)", comment: ""))
            )
            self.lastTimeMaxHeartRangeNotified = currentTime
        }
    }
    
    func setWaterRemindersPerDay() {
        waterReminderAmount = waterReminderAmount
        
        calculateReminderInterval()
        
        nextReminderCheckDate = getNextReminderDate()
    }
    
    private func calculateReminderInterval() {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.hour = waterReminderStartHour
        var endComponents = DateComponents()
        endComponents.hour = waterReminderEndHour
        
        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(from: endComponents) else {
            return
        }
        
        let totalTimeInterval = endDate.timeIntervalSince(startDate)
        
        waterReminderInterval = totalTimeInterval / Double(waterReminderAmount)
    }
    
    func checkAndNotifyForWaterReminders() {
        let currentTime = Date()
        
        if let nextReminderCheckDate = nextReminderCheckDate, currentTime >= nextReminderCheckDate {
            if waterReminder {
                bleWriteManager.sendNotification(AppNotification(title: NSLocalizedString("Water Reminder", comment: ""), subtitle: NSLocalizedString("It's time to drink water", comment: "")))
            }
            
            // Don't include in conditional because we want to keep the reminders up-to-date in case the user reenables water reminders
            self.nextReminderCheckDate = getNextReminderDate()
        }
    }
    
    private func getNextReminderDate() -> Date {
        let currentDate = Date()
        
        return currentDate.addingTimeInterval(waterReminderInterval)
    }
}

// MARK: Goals
extension NotificationManager {
    func sendStepGoalReachedNotification() {
        let notif = AppNotification(title: NSLocalizedString("Goal Reached", comment: ""), subtitle: NSLocalizedString("You've reached your steps goal", comment: ""))
        
        self.bleWriteManager.sendNotification(notif)
    }
}

// MARK: Reminders
extension NotificationManager {
    func sendReminderDueNotification(_ reminder: EKReminder) {
        let notif = AppNotification(title: NSLocalizedString("Reminders", comment: ""), subtitle: reminder.title + NSLocalizedString(" is due", comment: ""))
        
        self.bleWriteManager.sendNotification(notif)
    }
    
    func sendEventDueNotification(_ event: EKEvent) {
        let notif = AppNotification(title: NSLocalizedString("Calender", comment: ""), subtitle: event.title + NSLocalizedString(" is due", comment: ""))
        
        self.bleWriteManager.sendNotification(notif)
    }
}
