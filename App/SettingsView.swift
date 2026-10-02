import SwiftUI
import UserNotifications

/// Shared by onboarding and the Settings tab so both edit the same thing.
struct NudgeSettingsForm: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle("Remind me", isOn: $settings.value.pushEnabled)
            if settings.value.pushEnabled {
                Picker("Style", selection: $settings.value.mode) {
                    Text("Free windows").tag(NudgeMode.windows)
                    Text("Daily digest").tag(NudgeMode.digest)
                }
                .pickerStyle(.segmented)
            }
        } footer: {
            Text(settings.value.mode == .windows
                 ? "One nudge each time you're likely free. Never one per item."
                 : "One nudge a day, at the time you pick.")
                .foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.card)
        if settings.value.pushEnabled {
            Section {
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
            } header: {
                Caption(settings.value.mode == .windows ? "When are you free?" : "Digest time")
            }
            .listRowBackground(Theme.card)
        }
    }
}

extension View {
    /// Dark Form chrome shared by Settings and onboarding.
    func darkForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
            .toggleStyle(SwitchToggleStyle(tint: Theme.on))
            .tint(.white)
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section { PageTitle("Settings") }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            NudgeSettingsForm()
            if settings.value.pushEnabled, status == .denied {
                Section {
                    Button("Notifications are off in iOS. Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .foregroundStyle(.orange)
                }
                .listRowBackground(Theme.card)
            }
            Section {
                Label("In any app, tap Share, then Resurface.", systemImage: "square.and.arrow.up")
                Label("Screenshots: tap the preview, then Share.", systemImage: "camera.viewfinder")
                Label("Not in the list? Scroll the app row, tap More, turn on Resurface.", systemImage: "ellipsis.circle")
                Label("Widget: touch and hold the Home Screen, tap +, pick Resurface.", systemImage: "square.grid.2x2")
            } header: {
                Caption("How to save")
            }
            .font(.subheadline)
            .listRowBackground(Theme.card)
            Section {
                Button("Replay welcome") { settings.value.onboarded = false }.foregroundStyle(.white)
            }
            .listRowBackground(Theme.card)
        }
        .darkForm()
        .contentMargins(.top, 4, for: .scrollContent)
        .task(id: settings.value.pushEnabled) {
            if settings.value.pushEnabled, await NudgeScheduler.authorizationStatus() == .notDetermined {
                _ = await NudgeScheduler.requestAuthorization()
            }
            status = await NudgeScheduler.authorizationStatus()
        }
    }
}
