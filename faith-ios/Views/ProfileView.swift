import SwiftUI
import SwiftData
import AuthenticationServices

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @EnvironmentObject private var session: SessionStore
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @Query private var completions: [DayCompletion]
    @AppStorage("textSizeScale") private var textSizeScale: Double = 1.0
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour: Int = 6
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute: Int = 30
    @State private var showingSignOut = false
    @State private var showingDeleteAccount = false
    @State private var signInError: String?
    @State private var showingTextSizePicker = false
    @State private var showingTimePicker = false

    private var textSizeLabel: String {
        switch textSizeScale {
        case ..<0.9: "Small"
        case ..<1.1: "Medium"
        case ..<1.3: "Large"
        default:     "Extra large"
        }
    }

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var totalCompleted: Int { completions.filter(\.isComplete).count }
    private var palette: Palette { Palette(rawValue: paletteRaw) ?? .moss }
    private var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    }

    var body: some View {
        ZStack {
            NatureSubstrate()
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    accountSection
                    statsRow
                    section("Appearance") { appearanceSection }
                    section("Palette") { paletteSection }
                    section("Practice") { practiceSection }
                    section("Reading") { readingSection }
                    section("About") { aboutSection }
                    if session.auth.isSignedIn {
                        Button(role: .destructive) {
                            showingSignOut = true
                        } label: {
                            Text("Sign out")
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Button(role: .destructive) {
                            showingDeleteAccount = true
                        } label: {
                            Text("Delete account and all data")
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
            }
        }
        .alert("Sign out?", isPresented: $showingSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) { session.signOut() }
        } message: {
            Text("Your journal, anniversaries, and streak stay on this device. You'll need to pick your tradition again on next launch.")
        }
        .alert("Delete account?", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                session.deleteAccount()
            }
        } message: {
            Text("Wipes your sign-in, journal, anniversaries, streak, chat history, and tradition preference. This cannot be undone.")
        }
        .alert("Sign in failed", isPresented: Binding(
            get: { signInError != nil },
            set: { if !$0 { signInError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(signInError ?? "")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if session.auth.isSignedIn, let appleID = session.auth.appleUserID {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text((session.user.displayName?.isEmpty == false ? session.user.displayName : nil) ?? "Signed in")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text("Apple · \(appleID.prefix(8))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 8)
        } else {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let signed = session.auth.handleAppleAuthorization(auth) {
                        var user = session.user
                        if let given = signed.givenName, !given.isEmpty {
                            user.displayName = [given, signed.familyName ?? ""]
                                .joined(separator: " ")
                                .trimmingCharacters(in: .whitespaces)
                        }
                        session.user = user
                        session.users.save(user)
                    }
                case .failure(let error):
                    if let asAuthError = error as? ASAuthorizationError, asAuthError.code == .canceled {
                        // User dismissed the sheet — don't alert.
                        return
                    }
                    signInError = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(appearance == .dark ? .white : .black)
            .frame(height: 48)
            .padding(.top, 8)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile("Now", "\(progress.currentStreak())", "days", isAccent: true)
            statTile("In total", "\(totalCompleted)", "days", isAccent: false)
        }
        .padding(.top, 8)
    }

    private func statTile(_ label: String, _ value: String, _ sub: String, isAccent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .serif).monospacedDigit())
                .foregroundStyle(isAccent ? theme.accent : theme.ink)
            Text(sub)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(theme.inkMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var appearanceSection: some View {
        HStack(spacing: 8) {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    withAnimation(.snappy) { appearanceRaw = mode.rawValue }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(mode.rawValue == appearanceRaw ? .white : theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            mode.rawValue == appearanceRaw
                            ? AnyShapeStyle(theme.accent)
                            : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    private var paletteSection: some View {
        ForEach(Array(Palette.allCases.enumerated()), id: \.element.id) { index, p in
            Button {
                withAnimation(.snappy) { paletteRaw = p.rawValue }
            } label: {
                HStack(spacing: 12) {
                    paletteSwatch(p)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.displayName)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(theme.ink)
                        Text(p.tagline)
                            .font(.caption)
                            .foregroundStyle(theme.inkMute)
                    }
                    Spacer()
                    if p.rawValue == paletteRaw {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if index < Palette.allCases.count - 1 {
                Divider().background(theme.border).padding(.leading, 56)
            }
        }
    }

    private var practiceSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $dailyReminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily passage reminder").font(.system(size: 15, design: .serif))
                    Text(dailyReminderEnabled ? formattedTime : "Off")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.inkMute)
                }
            }
            .tint(theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .onChange(of: dailyReminderEnabled) { _, enabled in
                Task {
                    if enabled {
                        let granted = await Notifications.requestAuthIfNeeded()
                        if granted {
                            await Notifications.scheduleDailyReminder(
                                at: dailyReminderHour, minute: dailyReminderMinute
                            )
                        } else {
                            dailyReminderEnabled = false
                        }
                    } else {
                        Notifications.cancelDailyReminder()
                    }
                }
            }
            Divider().background(theme.border).padding(.leading, 18)
            Button { showingTimePicker = true } label: {
                settingsRow("Reminder time", detail: formattedTime, showsChevron: dailyReminderEnabled)
            }
            .buttonStyle(.plain)
            .disabled(!dailyReminderEnabled)
            .opacity(dailyReminderEnabled ? 1.0 : 0.55)
            .sheet(isPresented: $showingTimePicker) {
                ReminderTimeSheet(hour: $dailyReminderHour, minute: $dailyReminderMinute)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: dailyReminderHour) { _, _ in rescheduleIfEnabled() }
            .onChange(of: dailyReminderMinute) { _, _ in rescheduleIfEnabled() }
        }
    }

    private var formattedTime: String {
        let comp = DateComponents(hour: dailyReminderHour, minute: dailyReminderMinute)
        let date = Calendar.current.date(from: comp) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func rescheduleIfEnabled() {
        guard dailyReminderEnabled else { return }
        Task {
            await Notifications.scheduleDailyReminder(
                at: dailyReminderHour, minute: dailyReminderMinute
            )
        }
    }

    private var readingSection: some View {
        VStack(spacing: 0) {
            Button { showingTextSizePicker = true } label: {
                settingsRow("Text size", detail: textSizeLabel)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingTextSizePicker) {
            TextSizeSheet(scale: $textSizeScale)
        }
    }

    private var aboutSection: some View {
        settingsRow("Version", detail: appVersion, showsChevron: false)
    }

    private func settingsRow(_ label: String, detail: String, showsChevron: Bool = true) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(theme.ink)
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.inkMute)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func paletteSwatch(_ p: Palette) -> some View {
        let dusk = p.theme(for: .dark)
        return HStack(spacing: -6) {
            Circle().fill(dusk.accent).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
            Circle().fill(dusk.secondary).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
            Circle().fill(dusk.tertiary).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - TextSizeSheet

struct TextSizeSheet: View {
    @Binding var scale: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Aa")
                    .font(.system(size: 48 * scale, weight: .light, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                Slider(value: $scale, in: 0.8 ... 1.5, step: 0.05) {
                    Text("Text size")
                } minimumValueLabel: {
                    Text("A").font(.caption)
                } maximumValueLabel: {
                    Text("A").font(.title3)
                }
                .padding(.horizontal, 32)

                Text("Affects reading sizes throughout the app.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkMute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Text size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ReminderTimeSheet

struct ReminderTimeSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var time: Date = .now

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Spacer()
            }
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
                        hour = comps.hour ?? 6
                        minute = comps.minute ?? 30
                        dismiss()
                    }
                }
            }
            .task {
                let comps = DateComponents(hour: hour, minute: minute)
                time = Calendar.current.date(from: comps) ?? .now
            }
        }
    }
}
