import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.theme) private var theme

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)])
    private var entries: [JournalEntry]

    @State private var showingComposer: Bool = false
    @State private var editing: JournalEntry?
    @State private var entryToDelete: JournalEntry?

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(dimming: 0.18)

            VStack(alignment: .leading, spacing: 14) {
                header
                if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .padding(.top, 18)
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .sheet(isPresented: $showingComposer) {
            JournalComposer(prefillSuttaID: nil) { text, suttaID in
                JournalStore.add(text: text,
                                 tradition: session.user.tradition,
                                 suttaID: suttaID,
                                 in: context)
            }
        }
        .sheet(item: $editing) { entry in
            JournalComposer(existing: entry) { text, _ in
                entry.text = text
                try? context.save()
            }
        }
        .alert("Delete this entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { entryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let e = entryToDelete {
                    JournalStore.delete(e, in: context)
                }
                entryToDelete = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Journal").eyebrow()
                Text("Reflections")
                    .font(BTFont.serif(28, weight: .light))
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            Button { showingComposer = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 22)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(entries) { entry in
                    Button { editing = entry } label: {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 80)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Your first reflection")
                .font(BTFont.serif(20, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
            Text("A line is enough.")
                .font(BTFont.ui(12, weight: .light))
                .foregroundStyle(theme.inkMute)
            Button { showingComposer = true } label: {
                Text("Write")
                    .font(BTFont.ui(13, weight: .regular))
                    .tracking(1.5)
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EntryRow: View {
    @Environment(\.theme) private var theme

    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let t = entry.tradition {
                    Rectangle().fill(t.accent).frame(width: 14, height: 1)
                    Text(t.name)
                        .font(BTFont.serif(11.5, weight: .light, italic: true))
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
                Text(entry.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(BTFont.ui(10.5, weight: .light))
                    .foregroundStyle(theme.inkMute)
            }
            Text(entry.text)
                .font(BTFont.serif(15, weight: .light))
                .foregroundStyle(theme.ink)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
            if let sid = entry.suttaID,
               let p = CanonStore.shared.passage(byID: sid) {
                HStack(spacing: 6) {
                    Image(systemName: "book")
                        .font(.system(size: 10, weight: .light))
                    Text("\(p.code) · \(p.englishTitle)")
                        .font(BTFont.serif(11.5, weight: .light, italic: true))
                }
                .foregroundStyle(theme.inkMute)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct JournalComposer: View {
    @Environment(\.theme) private var theme

    var prefillSuttaID: String? = nil
    var existing: JournalEntry? = nil
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var text: String = ""

    init(prefillSuttaID: String? = nil,
         existing: JournalEntry? = nil,
         onSave: @escaping (String, String?) -> Void) {
        self.prefillSuttaID = prefillSuttaID
        self.existing = existing
        self.onSave = onSave
        _text = State(initialValue: existing?.text ?? "")
    }

    var body: some View {
        ZStack {
            NatureSubstrate(dimming: 0.2)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(existing == nil ? "Write" : "Edit").eyebrow()
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(theme.ink)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: Circle())
                    .accessibilityLabel("Close")
                }

                Text("What are you noticing?")
                    .font(BTFont.serif(22, weight: .light))
                    .foregroundStyle(theme.ink)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("A line, an image, a question.")
                            .font(BTFont.serif(15, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                            .padding(14)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(BTFont.serif(15, weight: .light))
                        .foregroundStyle(theme.ink)
                        .padding(8)
                }
                .frame(minHeight: 180)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let sid = prefillSuttaID,
                   let p = CanonStore.shared.passage(byID: sid) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .light))
                        Text("Linked to \(p.code) · \(p.englishTitle)")
                            .font(BTFont.serif(12.5, weight: .light, italic: true))
                    }
                    .foregroundStyle(theme.inkMute)
                }

                Spacer()

                Button {
                    onSave(text, prefillSuttaID)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(BTFont.ui(15, weight: .regular))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }
}
