import SwiftUI

struct Lotus: View {
    var size: CGFloat = 28
    var bloom: Double = 1.0
    var color: Color = .white
    var dim: Color = Color.white.opacity(0.18)
    var strokeWidth: CGFloat = 1.4

    var body: some View {
        Canvas { context, _ in
            let center = CGPoint(x: size / 2, y: size / 2)
            let scale = size / 32.0
            let petalCount = 8

            for i in 0..<petalCount {
                let angle = Double(i) / Double(petalCount) * .pi * 2 - .pi / 2
                let showThreshold = Double(i) / Double(petalCount) * 0.6
                let visible = bloom > showThreshold
                let open = max(0, min(1, (bloom - showThreshold) / 0.4))
                let length = (9 + open * 4) * scale

                let inset = 2 * scale
                let x1 = center.x + cos(angle) * inset
                let y1 = center.y + sin(angle) * inset
                let x2 = center.x + cos(angle) * length
                let y2 = center.y + sin(angle) * length

                let cx = (x1 + x2) / 2
                let cy = (y1 + y2) / 2
                let rx = (3 + open * 1.5) * scale
                let ry = length / 2 - 1 * scale
                let rotation = angle + .pi / 2

                let petal = Path { p in
                    p.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                }

                let transform = CGAffineTransform.identity
                    .translatedBy(x: cx, y: cy)
                    .rotated(by: rotation)
                let placed = petal.applying(transform)

                if visible {
                    let fillAlpha = 0.18 + open * 0.25
                    context.fill(placed, with: .color(color.opacity(fillAlpha)))
                    let strokeAlpha = 0.55 + open * 0.45
                    context.stroke(placed, with: .color(color.opacity(strokeAlpha)), lineWidth: strokeWidth)
                } else {
                    context.stroke(placed, with: .color(dim), lineWidth: strokeWidth)
                }
            }

            let dotR = (1.5 + bloom * 1.2) * scale
            let dot = Path(ellipseIn: CGRect(
                x: center.x - dotR, y: center.y - dotR,
                width: dotR * 2, height: dotR * 2
            ))
            context.fill(dot, with: .color(color.opacity(0.7 + bloom * 0.3)))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        Lotus(bloom: 0, color: .green)
        Lotus(bloom: 0.3, color: .green)
        Lotus(bloom: 0.6, color: .green)
        Lotus(bloom: 1.0, color: .green)
    }
    .padding()
    .background(.black)
}
