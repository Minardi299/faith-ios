import SwiftUI
import SwiftData

struct AnniversariesView: View {
    @Environment(\.theme) private var theme

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    @Query(sort: [SortDescriptor(\Anniversary.month), SortDescriptor(\Anniversary.day)])
    private var anniversaries: [Anniversary]

    @State private var showAdd: Bool = false
    @State private var anniversaryToDelete: Anniversary?

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(tradition: session.user.tradition, dimming: 0.18)
            VStack(alignment: .leading, spacing: 16) {
                header
                if anniversaries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .padding(.top, 18)
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .sheet(isPresented: $showAdd) {
            AnniversaryComposer()
        }
        .alert("Delete this anniversary?", isPresented: Binding(
            get: { anniversaryToDelete != nil },
            set: { if !$0 { anniversaryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { anniversaryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let a = anniversaryToDelete {
                    AnniversaryStore.delete(a, in: context)
                }
                anniversaryToDelete = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Personal").eyebrow()
                Text("Anniversaries")
                    .font(BTFont.serif(28, weight: .light))
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            Button { showAdd = true } label: {
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
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())
        }
        .padding(.horizontal, 22)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(anniversaries) { ann in
                    HStack(spacing: 12) {
                        if let t = ann.tradition {
                            Rectangle().fill(t.accent).frame(width: 14, height: 1)
                        } else {
                            Circle().strokeBorder(theme.inkMute, lineWidth: 0.5)
                                .frame(width: 6, height: 6)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ann.label)
                                .font(BTFont.serif(15, weight: .light))
                                .foregroundStyle(theme.ink)
                            Text(dateLabel(ann))
                                .font(BTFont.serif(12, weight: .light, italic: true))
                                .foregroundStyle(theme.inkMute)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            anniversaryToDelete = ann
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .light))
                                .foregroundStyle(theme.inkMute)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 80)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("No anniversaries yet")
                .font(BTFont.serif(20, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
            Text("A loved one's birthday, the day someone passed, the day you started.")
                .font(BTFont.ui(12, weight: .light))
                .foregroundStyle(theme.inkMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Text("Add")
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

    private func dateLabel(_ ann: Anniversary) -> String {
        let symbols = DateFormatter().monthSymbols ?? []
        let monthName: String = (1...12).contains(ann.month) && symbols.indices.contains(ann.month - 1)
            ? symbols[ann.month - 1]
            : "?"
        let yearStr = ann.repeatsYearly ? " · yearly" : " · \(ann.year)"
        return "\(monthName) \(ann.day)\(yearStr)"
    }
}

struct AnniversaryComposer: View {
    @Environment(\.theme) private var theme

    var initialDay: Int = Calendar.current.component(.day, from: .now)
    var initialMonth: Int = Calendar.current.component(.month, from: .now)
    var initialYear: Int = Calendar.current.component(.year, from: .now)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionStore

    @State private var label: String = ""
    @State private var date: Date = .now
    @State private var traditionPick: Tradition? = nil
    @State private var repeatsYearly: Bool = true

    var body: some View {
        ZStack {
            NatureSubstrate(tradition: session.user.tradition, dimming: 0.2)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Anniversary").eyebrow()
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

                Text("Mark a day")
                    .font(BTFont.serif(22, weight: .light))
                    .foregroundStyle(theme.ink)

                TextField("Label", text: $label)
                    .font(BTFont.serif(15, weight: .light))
                    .foregroundStyle(theme.ink)
                    .padding(14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(session.user.tradition.accent)
                    .padding(14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle("Repeat each year", isOn: $repeatsYearly)
                    .tint(session.user.tradition.accent)
                    .padding(14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Button {
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.year, .month, .day], from: date)
                    AnniversaryStore.add(
                        day: comps.day ?? initialDay,
                        month: comps.month ?? initialMonth,
                        year: comps.year ?? initialYear,
                        label: label,
                        tradition: traditionPick,
                        repeatsYearly: repeatsYearly,
                        in: context
                    )
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
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .onAppear {
                var comps = DateComponents()
                comps.year = initialYear
                comps.month = initialMonth
                comps.day = initialDay
                if let d = Calendar.current.date(from: comps) {
                    date = d
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }
}
