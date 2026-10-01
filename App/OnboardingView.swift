import SwiftUI

/// Three screens, good defaults already chosen: someone who just taps Next still gets the right setup.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = DebugArgs.int("-onboardingPage") ?? 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                pitch.tag(0)
                when.tag(1)
                allow.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button(action: next) {
                Text(page == 2 ? "Get started" : "Next")
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    private func next() {
        if page < 2 { withAnimation { page += 1 } } else { settings.value.onboarded = true }
    }

    private var pitch: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.up.bin.fill").font(.system(size: 64)).foregroundStyle(Theme.accent)
            Text("Save it now.\nRead it when you're free.").font(.largeTitle.bold()).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                Label("In any app, tap Share → Resurface", systemImage: "square.and.arrow.up")
                Label("Screenshots too: tap the preview, then Share", systemImage: "camera.viewfinder")
                Label("Resurface brings it back when you have time", systemImage: "bell.badge")
            }
            .font(.subheadline)
            Text("Don't see Resurface in the share sheet? Scroll the app row, tap More, and turn it on.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var when: some View {
        @Bindable var settings = settings
        return VStack(spacing: 8) {
            Text("When are you free?").font(.title.bold()).padding(.top, 40)
            Text("Pick how we nudge you. You can change this anytime.").font(.subheadline).foregroundStyle(.secondary)
            Form { NudgeSettingsForm() }.scrollContentBackground(.hidden)
        }
    }

    private var allow: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.badge.fill").font(.system(size: 64)).foregroundStyle(Theme.accent)
            Text("Allow nudges").font(.largeTitle.bold())
            Text("One gentle notification per free window. Never one per item.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Turn on notifications") { Task { _ = await NudgeScheduler.requestAuthorization() } }
                .buttonStyle(.bordered)
            Label("Add the widget: touch and hold your Home Screen, tap +, pick Resurface.", systemImage: "square.grid.2x2")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
