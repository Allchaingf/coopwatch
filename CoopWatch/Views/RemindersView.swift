//
//  RemindersView.swift  (Screen 13 — Reminders)
//  CoopWatch
//
//  Three repeating local reminders — close the coop, check the perimeter, move
//  a deterrent — each with a toggle and a time. Wired to UNUserNotificationCenter
//  for real scheduling/cancelling, with a "send test" to prove it works.
//  iOS 14 safe.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @State private var deniedAlert = false

    var body: some View {
        ScreenScaffold("Reminders", subtitle: "Never forget to lock up", showFence: false) {
            if !notifications.isAuthorized {
                CardView(tint: Theme.dusk.opacity(0.4)) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill").foregroundColor(Theme.dusk)
                        Text("Turn a reminder on to allow notifications. You can change times anytime.")
                            .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    }
                }
            }

            ForEach(store.reminders) { reminder in
                reminderCard(reminder)
            }
        }
        .onAppear { notifications.refreshStatus() }
        .alert(isPresented: $deniedAlert) {
            Alert(title: Text("Notifications are off"),
                  message: Text("Enable notifications for Coop Watch in iOS Settings to schedule reminders."),
                  dismissButton: .default(Text("OK")))
        }
    }

    private func reminderCard(_ reminder: Reminder) -> some View {
        CardView(tint: reminder.isEnabled ? Theme.protectedC.opacity(0.4) : nil) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill((reminder.isEnabled ? Theme.protectedC : Theme.textSecondary).opacity(0.18)).frame(width: 40, height: 40)
                        Image(systemName: reminder.kind.icon).foregroundColor(reminder.isEnabled ? Theme.protectedC : Theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.kind.displayName).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Text(reminder.kind.blurb).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { reminder.isEnabled },
                        set: { newValue in setEnabled(reminder, newValue) }
                    )).labelsHidden().toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))
                }

                HStack {
                    FieldLabel(text: "Time")
                    Spacer()
                    DatePicker("", selection: timeBinding(reminder), displayedComponents: .hourAndMinute)
                        .labelsHidden().accentColor(Theme.alarm)
                }

                if reminder.isEnabled {
                    Button(action: { notifications.sendTest(reminder.kind) }) {
                        Label("Send test now", systemImage: "paperplane.fill")
                            .font(Theme.caption(12)).foregroundColor(Theme.dusk)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func timeBinding(_ reminder: Reminder) -> Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = reminder.hour; c.minute = reminder.minute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                var r = reminder
                r.hour = Calendar.current.component(.hour, from: newDate)
                r.minute = Calendar.current.component(.minute, from: newDate)
                store.saveReminder(r)
                if r.isEnabled { notifications.schedule(r) }
            }
        )
    }

    private func setEnabled(_ reminder: Reminder, _ enabled: Bool) {
        var r = reminder
        if enabled {
            notifications.enable(r) { granted in
                if granted {
                    r.isEnabled = true
                    store.saveReminder(r)
                } else {
                    r.isEnabled = false
                    store.saveReminder(r)
                    deniedAlert = true
                }
            }
        } else {
            r.isEnabled = false
            store.saveReminder(r)
            notifications.cancel(r.kind)
        }
    }
}
