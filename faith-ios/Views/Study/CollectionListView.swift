import SwiftUI

/// Drill-down sutta list shown when a user taps a collection in the canon browser.
/// Lists every entry CanonStore has for that collection, with a search filter.
struct CollectionListView: View {
    @Environment(\.theme) private var theme

    let tradition: Tradition
    let collection: CanonCollection
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var openPassage: SuttaPassage?

    private var entries: [SuttaPassage] {
        let all = CanonStore.shared.entries(for: collection.id, tradition: tradition)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        let q = query.lowercased()
        return all.filter {
            $0.code.lowercased().contains(q)
                || $0.title.lowercased().contains(q)
                || $0.englishTitle.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(tradition: tradition, dimming: 0.18)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                searchField
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .sheet(item: $openPassage) { p in
            SuttaDetailSheet(passage: p)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tradition.name.uppercased())
                    .font(BTFont.ui(10.5, weight: .light))
                    .tracking(2)
                    .foregroundStyle(theme.inkMute)
                Text(collection.name)
                    .font(BTFont.serif(26, weight: .light))
                    .foregroundStyle(theme.ink)
                Text("\(entries.count) of \(collection.count) · \(collection.subtitle)")
                    .font(BTFont.serif(12, weight: .light, italic: true))
                    .foregroundStyle(theme.inkMute)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(theme.inkMute)
            TextField("filter by title or code", text: $query)
                .font(BTFont.ui(13.5, weight: .light))
                .foregroundStyle(theme.ink)
                .submitLabel(.done)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: Capsule())
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    Button { openPassage = entry } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(entry.code)
                                .font(BTFont.mono(11, weight: .light))
                                .foregroundStyle(theme.inkMute)
                                .frame(minWidth: 70, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.englishTitle)
                                    .font(BTFont.serif(15, weight: .light))
                                    .foregroundStyle(.white.opacity(entry.isStub ? 0.55 : 0.92))
                                    .multilineTextAlignment(.leading)
                                if entry.isStub {
                                    Text("translation forthcoming")
                                        .font(BTFont.serif(10.5, weight: .light, italic: true))
                                        .foregroundStyle(theme.inkMute)
                                }
                            }
                            Spacer()
                            Text(entry.readingBadge)
                                .font(BTFont.ui(10.5, weight: .light))
                                .foregroundStyle(theme.inkMute)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(theme.inkMute)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    if entry.id != entries.last?.id {
                        Divider().background(theme.border).padding(.horizontal, 16)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 80)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Nothing here yet.")
                .font(BTFont.serif(15, weight: .light, italic: true))
                .foregroundStyle(theme.inkMute)
            Text("Translations for this collection are still in progress.")
                .font(BTFont.ui(12, weight: .light))
                .foregroundStyle(theme.inkMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
