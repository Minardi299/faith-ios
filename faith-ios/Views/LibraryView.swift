import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.theme) private var theme
    @Binding var deepLinkPassageID: String?
    @State private var openPassage: SuttaPassage?
    @State private var openContext: PathwayContext?
    @State private var showingCalendar = false
    @State private var showingAnniversaries = false
    @State private var showingJournal = false
    @State private var showingQuiz = false
    @State private var showingBlessing = false
    @State private var showingPathwaysAll = false
    @ObservedObject private var pathwayStore = PathwayStore.shared
    @ObservedObject private var pathwayProgress = PathwayProgressStore.shared

    private var pathways: [ReadingPathway] {
        pathwayStore.pathways
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NatureSubstrate()
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        headerBlock
                        coreReadsSection
                        traditionsSection
                        pathwaysSection
                        actionsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .profileToolbar()
            .sheet(item: $openPassage) { p in
                SuttaDetailSheet(passage: p, pathwayContext: openContext)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPathwaysAll) {
                PathwaysView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingCalendar) {
                NavigationStack { HolyCalendarView() }
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAnniversaries) {
                NavigationStack { AnniversariesView() }
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingJournal) {
                NavigationStack { JournalView() }
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingQuiz) {
                NavigationStack { QuizView() }
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingBlessing) {
                NavigationStack { SendBlessingFlow() }
                    .presentationDragIndicator(.visible)
            }
            .task(id: deepLinkPassageID) {
                guard let id = deepLinkPassageID,
                      let passage = canon.passage(byID: id) else { return }
                openContext = nil
                openPassage = passage
                deepLinkPassageID = nil
            }
            .onChange(of: canon.loadStatus) { _, _ in
                guard let id = deepLinkPassageID,
                      let passage = canon.passage(byID: id) else { return }
                openContext = nil
                openPassage = passage
                deepLinkPassageID = nil
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIBRARY")
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .foregroundStyle(theme.inkMute)
            Text("\(Text("The canon\n").foregroundStyle(theme.ink))\(Text("at hand.").italic().foregroundColor(theme.secondary))")
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private var coreReadsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CORE READS")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                switch canon.loadStatus {
                case .pending:
                    ProgressView().tint(theme.accent)
                case .loaded:
                    ForEach(Array(canon.coreReads().prefix(8)), id: \.id) { passage in
                        passageRow(passage)
                    }
                case .failed(let message):
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The canon failed to load")
                            .font(BTFont.ui(14, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text(message)
                            .font(BTFont.ui(11))
                            .foregroundStyle(theme.inkMute)
                            .lineLimit(3)
                        Button("Retry") {
                            canon.load()
                        }
                        .font(BTFont.ui(12, weight: .medium))
                        .foregroundStyle(theme.accent)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func passageRow(_ passage: SuttaPassage) -> some View {
        Button {
            openContext = nil
            openPassage = passage
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(passage.englishTitle)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text("\(passage.code) · \(passage.readingBadge)")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var traditionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRADITIONS")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(Array(Tradition.allCases.enumerated()), id: \.offset) { _, tradition in
                    traditionRow(tradition)
                }
            }
        }
    }

    @ViewBuilder
    private func traditionRow(_ tradition: Tradition) -> some View {
        NavigationLink {
            TraditionBrowseView(tradition: tradition)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(tradition.accent)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tradition.name)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text(tradition.pali)
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var pathwaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PATHWAYS")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            if pathways.isEmpty {
                Text("No pathways available.")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMute)
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(pathways.prefix(3)) { pathway in
                        Button { openPathwayDirect(pathway) } label: {
                            PathwayRow(pathway: pathway)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showingPathwaysAll = true
                    } label: {
                        HStack {
                            Text("See all pathways")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openPathwayDirect(_ pathway: ReadingPathway) {
        let nextIndex = pathwayProgress.nextStepIndex(in: pathway)
        guard pathway.steps.indices.contains(nextIndex),
              let passage = canon.passage(byID: pathway.steps[nextIndex].suttaID) else { return }
        openContext = PathwayContext(
            pathwayID: pathway.id,
            pathwayTitle: pathway.title,
            stepIndex: nextIndex,
            totalSteps: pathway.steps.count
        )
        openPassage = passage
        pathwayProgress.markOpened(pathwayID: pathway.id)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MORE")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                actionRow("Holy calendar", systemImage: "calendar") { showingCalendar = true }
                Divider().background(theme.border).padding(.leading, 52)
                actionRow("Anniversaries", systemImage: "heart") { showingAnniversaries = true }
                Divider().background(theme.border).padding(.leading, 52)
                actionRow("Journal", systemImage: "leaf") { showingJournal = true }
                Divider().background(theme.border).padding(.leading, 52)
                actionRow("Quiz", systemImage: "questionmark.circle") { showingQuiz = true }
                Divider().background(theme.border).padding(.leading, 52)
                actionRow("Send a blessing", systemImage: "envelope") { showingBlessing = true }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func actionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkSoft)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PathwayRow: View {
    let pathway: ReadingPathway
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(pathway.tradition.accent).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(pathway.title)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(pathway.subtitle)
                    .font(.system(size: 12).italic())
                    .foregroundStyle(theme.inkMute)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(theme.inkMute)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TraditionBrowseView: View {
    let tradition: Tradition
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.theme) private var theme

    private var collections: [CanonCollection] {
        canon.collections(for: tradition)
    }

    var body: some View {
        ZStack {
            NatureSubstrate(tradition: tradition)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(collections) { collection in
                        NavigationLink {
                            CollectionListView(tradition: tradition, collection: collection)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collection.name)
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                        .foregroundStyle(theme.ink)
                                    Text("\(collection.count) · \(collection.subtitle)")
                                        .font(.caption2)
                                        .foregroundStyle(theme.inkMute)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.inkFaint)
                            }
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(tradition.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
