import SwiftUI

extension View {
    /// Ensure a `Button` with `.buttonStyle(.plain)` and a glass label has a
    /// hit area equal to its glass shape. Apply BEFORE the matching
    /// `.glassEffect(.regular, in:)` modifier on the label.
    func hitArea<S: Shape>(_ shape: S) -> some View {
        self.contentShape(shape)
    }

    /// Apply the standard glass capsule treatment AND make the full padded
    /// area tappable. Use on labels of `Button { … } label: { Text(…) … }`.
    func glassPillLabel() -> some View {
        self
            .contentShape(Capsule())
            .glassEffect(.regular, in: Capsule())
    }

    /// Glass rounded rectangle, full frame tappable.
    func glassRoundedLabel(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .contentShape(shape)
            .glassEffect(.regular, in: shape)
    }
}
