//
//  NotificationManager.swift
//  CoopWatch
//
//  Real local-notification scheduling for the coop reminders (lock-up, perimeter
//  check, deterrent move). Uses UNUserNotificationCenter (iOS 10+, fully iOS 14
//  safe). No remote push.
//

import UserNotifications

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    init() { refreshStatus() }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized
                                     || settings.authorizationStatus == .provisional)
            }
        }
    }

    /// Requests permission and, on grant, schedules the given reminder.
    func enable(_ reminder: Reminder, completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted { self.schedule(reminder) }
                completion(granted)
            }
        }
    }

    func schedule(_ reminder: Reminder) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.kind.notifID])

        let content = UNMutableNotificationContent()
        content.title = "Coop Watch — \(reminder.kind.displayName)"
        content.body = reminder.kind.notifBody
        content.sound = .default

        var comps = DateComponents()
        comps.hour = reminder.hour
        comps.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.kind.notifID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancel(_ kind: ReminderKind) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [kind.notifID])
    }

    /// Fires a one-off confirmation so the user immediately sees it working.
    func sendTest(_ kind: ReminderKind) {
        let content = UNMutableNotificationContent()
        content.title = "Coop Watch"
        content.body = "Test: \(kind.notifBody)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
