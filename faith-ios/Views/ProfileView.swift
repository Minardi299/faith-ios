import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var completions: [DayCompletion]

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var totalCompleted: Int { completions.filter(\.isComplete).count }

    var body: some View {
        Form {
            Section {
                LabeledContent("Current streak") {
                    Label("\(progress.currentStreak())", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                LabeledContent("Days completed", value: "\(totalCompleted)")
            }
            Section("Preferences") {
                NavigationLink("Reminder time") { Text("Reminder time settings") }
                NavigationLink("Appearance") { Text("Appearance settings") }
            }
            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
