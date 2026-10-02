import SwiftUI

/// Three screens, good defaults already chosen: someone who just taps through still gets the right setup.
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
            VStack(spacing: 10) {
                Button(page == 2 ? "Turn on nudges" : "Continue", action: next)
                    .buttonStyle(GlowButtonStyle())
                Button("Not now") { settings.value.onboarded = true }
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .opacity(page == 2 ? 1 : 0)
                    .disabled(page != 2)
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func next() {
        if page < 2 {
            withAnimation { page += 1 }
        } else {
            Task {
                _ = await NudgeScheduler.requestAuthorization()
                settings.value.onboarded = true
            }
        }
    }

    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 104, height: 104)
            .glassCard(radius: 32, glow: true)
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            glyph("arrow.up.circle")
            Text("Save it now.\nRead it when\nyou're free.").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) {
                step("square.and.arrow.up", "In any app, tap Share → Resurface")
                step("camera.viewfinder", "Screenshots too: tap the preview, then Share")
                step("bell.badge", "It comes back when you have time")
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func step(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(.white).frame(width: 24)
            Text(text).font(.subheadline).foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard()
    }

    private var when: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When are you free?").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
            Text("One nudge per window. Change it anytime.").font(.subheadline).foregroundStyle(Theme.textSecondary)
            Form { NudgeSettingsForm() }
                .darkForm()
                .padding(.horizontal, -20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 48)
    }

    private var allow: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            glyph("bell.badge")
            Text("Let it nudge you.").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            Text("One quiet notification when you're free. Never one per item. Nothing leaves your phone.")
                .font(.body).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2").font(.body.weight(.semibold)).foregroundStyle(.white).frame(width: 24)
                Text("Add the widget too: touch and hold your Home Screen, tap +, pick Resurface.")
                    .font(.subheadline).foregroundStyle(.white)
            }
            .padding(14)
            .glassCard()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
