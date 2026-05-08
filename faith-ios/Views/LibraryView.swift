import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.theme) private var theme
    @Binding var deepLinkPassageID: String?
    @State private var openPassage: SuttaPassage?
    @State private var showingCalendar = false
    @State private var showingAnniversaries = false
    @State private var showingJournal = false
    @State private var showingQuiz = false
    @State private var showingBlessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerBlock
                    coreReadsSection
                    traditionsSection
                    actionsSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .profileToolbar()
            .sheet(item: $openPassage) { p in
                NavigationStack { SuttaDetailSheet(passage: p) }
            }
            .sheet(isPresented: $showingCalendar) {
                NavigationStack { HolyCalendarView() }
            }
            .sheet(isPresented: $showingAnniversaries) {
                NavigationStack { AnniversariesView() }
            }
            .sheet(isPresented: $showingJournal) {
                NavigationStack { JournalView() }
            }
            .sheet(isPresented: $showingQuiz) {
                NavigationStack { QuizView() }
            }
            .sheet(isPresented: $showingBlessing) {
                NavigationStack { SendBlessingFlow() }
            }
            .onChange(of: deepLinkPassageID) { _, newValue in
                guard let id = newValue,
                      let passage = canon.passage(byID: id) else { return }
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
            (Text("The canon\n")
                + Text("at hand.")
                .italic()
                .foregroundColor(theme.secondary))
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
                let core = canon.coreReads().prefix(8)
                if core.isEmpty {
                    Text("Loading canon…")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(Array(core), id: \.id) { passage in
                        passageRow(passage)
                    }
                }
            }
        }
    }

    private func passageRow(_ passage: SuttaPassage) -> some View {
        Button {
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
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
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
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
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

private struct TraditionBrowseView: View {
    let tradition: Tradition
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.theme) private var theme

    private var collections: [CanonCollection] {
        canon.collections(for: tradition)
    }

    var body: some View {
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
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.border, lineWidth: 0.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(tradition.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
