import ActivityKit
import WidgetKit
import SwiftUI

struct SitActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SitActivityAttributes.self) { context in
            // Lock Screen / banner UI
            SitLockScreenView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: context.state.startedAt ... context.state.endsAt, countsDown: true)
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.95))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let chant = context.state.chant {
                        Text(chant)
                            .font(.system(size: 12, weight: .light, design: .serif).italic())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.white.opacity(0.85))
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt ... context.state.endsAt, countsDown: true)
                    .font(.system(size: 12, weight: .light))
                    .monospacedDigit()
                    .frame(maxWidth: 44)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white.opacity(0.85))
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .keylineTint(.white.opacity(0.5))
        }
    }
}

private struct SitLockScreenView: View {
    let state: SitActivityAttributes.State

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SITTING")
                .font(.system(size: 9, weight: .light))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
            Text(timerInterval: state.startedAt ... state.endsAt, countsDown: true)
                .font(.system(size: 36, weight: .light, design: .serif))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
            if let chant = state.chant {
                Text(chant)
                    .font(.system(size: 12, weight: .light, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
