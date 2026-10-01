import SwiftUI
import UserNotifications

/// Shared by onboarding and the Settings tab so both edit the same thing.
struct NudgeSettingsForm: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle("Remind me with notifications", isOn: $settings.value.pushEnabled)
            if settings.value.pushEnabled {
                Picker("Style", selection: $settings.value.mode) {
                    Text("Free windows").tag(NudgeMode.windows)
                    Text("Daily digest").tag(NudgeMode.digest)
                }
                .pickerStyle(.segmented)
            }
        } footer: {
            Text(settings.value.mode == .windows
                 ? "One notification each time you're likely free. Never one per item."
                 : "One notification a day, at the time you pick.")
        }
        if settings.value.pushEnabled {
            Section(settings.value.mode == .windows ? "When are you free?" : "Digest time") {
                if settings.value.mode == .windows {
                    ForEach($settings.value.windows) { $window in
                        HStack {
                            Toggle(isOn: $window.enabled) {
                                Label(window.name, systemImage: window.symbol)
                            }
                            if window.enabled {
                                DatePicker("", selection: $window.time, displayedComponents: .hourAndMinute).labelsHidden()
                            }
                        }
                    }
                } else {
                    DatePicker("Every day at", selection: $settings.value.digestTime, displayedComponents: .hourAndMinute)
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                NudgeSettingsForm()
                if settings.value.pushEnabled, status == .denied {
                    Section {
                        Button("Notifications are off in iOS. Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
                Section("Widget") {
                    Label("Touch and hold your Home Screen, tap +, then add Resurface.", systemImage: "square.grid.2x2")
                        .font(.subheadline)
                }
                Section("How to save") {
                    Label("In any app, tap Share, then Resurface.", systemImage: "square.and.arrow.up").font(.subheadline)
                    Label("Screenshots: tap the preview, then Share.", systemImage: "camera.viewfinder").font(.subheadline)
                    Label("Not in the list? Scroll the app row, tap More, and turn on Resurface.", systemImage: "ellipsis.circle").font(.subheadline)
                }
                Section {
                    Button("Replay welcome") { settings.value.onboarded = false }
                }
            }
            .navigationTitle("Settings")
            .task(id: settings.value.pushEnabled) {
                if settings.value.pushEnabled, await NudgeScheduler.authorizationStatus() == .notDetermined {
                    _ = await NudgeScheduler.requestAuthorization()
                }
                status = await NudgeScheduler.authorizationStatus()
            }
        }
    }
}
