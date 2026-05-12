import SwiftUI

struct PathwaysView: View {
    @ObservedObject private var store = PathwayStore.shared
    @ObservedObject private var progress = PathwayProgressStore.shared
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var openPassage: SuttaPassage?
    @State private var openContext: PathwayContext?

    private var pathways: [ReadingPathway] {
        store.pathways
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(pathways) { pathway in
                        Button { openFirstStep(of: pathway) } label: {
                            PathwayCard(pathway: pathway, progress: progress.byPathway[pathway.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("Pathways")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $openPassage) { passage in
            SuttaDetailSheet(passage: passage, pathwayContext: openContext)
                .presentationDragIndicator(.visible)
        }
    }

    private func openFirstStep(of pathway: ReadingPathway) {
        let nextIndex = progress.nextStepIndex(in: pathway)
        let step = pathway.steps[nextIndex]
        guard let passage = canon.passage(byID: step.suttaID) else { return }
        openContext = PathwayContext(
            pathwayID: pathway.id,
            pathwayTitle: pathway.title,
            stepIndex: nextIndex,
            totalSteps: pathway.steps.count
        )
        openPassage = passage
        progress.markOpened(pathwayID: pathway.id)
    }
}

private struct PathwayCard: View {
    let pathway: ReadingPathway
    let progress: PathwayProgressStore.Progress?
    @Environment(\.theme) private var theme

    private var readCount: Int { progress?.readSuttaIDs.count ?? 0 }
    private var pct: Double {
        pathway.stepCount == 0 ? 0 : Double(readCount) / Double(pathway.stepCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(pathway.tradition.accent).frame(width: 8, height: 8)
                Text(pathway.tradition.name)
                    .font(.caption2.weight(.light))
                    .tracking(1.2)
                    .foregroundStyle(theme.inkMute)
                Spacer()
                if readCount > 0 {
                    Text("\(readCount) of \(pathway.stepCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.inkMute)
                }
            }
            Text(pathway.title)
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.leading)
            Text(pathway.subtitle)
                .font(.system(size: 13, design: .serif).italic())
                .foregroundStyle(theme.inkSoft)
            Text(pathway.blurb)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(theme.inkMute)
                .lineLimit(2)
            ProgressView(value: pct)
                .tint(pathway.tradition.accent)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }
}
