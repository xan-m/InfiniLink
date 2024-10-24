//
//  RemindersView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/6/24.
//

import SwiftUI
import EventKit

struct RemindersView: View {
    @ObservedObject var remindersManager = RemindersManager.shared
    
    @State private var authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    
    var body: some View {
        Group {
            switch authorizationStatus {
            case .authorized, .fullAccess:
                authorized
            case .denied, .notDetermined, .restricted, .writeOnly:
                unauthorized
            @unknown default:
                unauthorized
            }
        }
        .onChange(of: remindersManager.isAuthorized) { _ in
            remindersManager.requestReminderAccess()
        }
        .onAppear {
            remindersManager.requestReminderAccess()
        }
    }
    
    var authorized: some View {
        Group {
            if remindersManager.reminders.filter({ $0.isCompleted == false }).isEmpty {
                Text("You don't have any upcoming reminders. You can set them in the Reminders app.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color.gray)
                    .multilineTextAlignment(.center)
                    .padding(20)
            } else {
                List {
                    ForEach(remindersManager.reminders.filter({ $0.isCompleted == false }), id: \.hashValue) { reminder in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .foregroundStyle({
                                    if let dueDate = reminder.dueDateComponents, let date = Calendar.current.date(from: dueDate) {
                                        if date <= Date() {
                                            return Color.red
                                        }
                                    }
                                    return Color.blue
                                }())
                            if let dueDate = reminder.dueDateComponents, let date = Calendar.current.date(from: dueDate) {
                                Text("\(date >= Date() ? "Notifying" : "Notified") on " + date.formatted())
                                    .foregroundStyle(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
    }
    
    var unauthorized: some View {
        ActionView(action: Action(title: "We need access to your Reminders.", subtitle: "To receive reminders on your watch, you'll need to give InfiniLink full access to them.", icon: "checklist", action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }, actionLabel: "Open Settings...", accent: .blue))
    }
}

#Preview {
    RemindersView()
}
