import SwiftUI

/// A wrapping flow layout — used to mix paragraphs of text with inline glass pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var runSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        return layout(in: maxWidth, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, frame) in result.frames.enumerated() {
            let pos = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
            subviews[i].place(at: pos, proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x)
        }

        return (frames, CGSize(width: totalWidth, height: y + rowHeight))
    }
}
