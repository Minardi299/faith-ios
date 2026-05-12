import SwiftUI

/// Standard scaffold for tab pages: tradition substrate + top glyph row + content.
/// Tab bar is supplied by the enclosing `TabView` (iOS 26 liquid glass tab bar).
struct PageScaffold<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String?
    let trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil,
         trailing: AnyView? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate()
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Spacer()
                    if let trailing { trailing } else { DateGlyph() }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 6)

                if let title {
                    HStack {
                        Text(title)
                            .font(BTFont.serif(28, weight: .light))
                            .foregroundStyle(theme.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                content()
            }
        }
    }
}
