// Renders the 1024×1024 app icon. Compiled together with Sources/Uncork/UncorkMark.swift by scripts/make-icon.sh.
import AppKit
import SwiftUI

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A dark red Bordeaux bottle with a framed label on a cream tile, with the cork popping out.
struct AppIcon: View {
    // Bottle frame inside the 1024 canvas. The cork sits above it, lifted and tilted.
    private let bottleHeight: CGFloat = 680
    private var bottleWidth: CGFloat { bottleHeight * 0.3 }

    var body: some View {
        ZStack {
            // macOS icon grid: an 824-point tile centred in the 1024 canvas.
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF8EEE1), Color(hex: 0xE6CFB6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)

            ZStack {
                BottleShape()
                    .fill(LinearGradient(colors: [Color(hex: 0x5A1828), Color(hex: 0x1E070D)], startPoint: .leading, endPoint: .trailing))
                // Glass highlights on the shoulder and down the body.
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: bottleWidth * 0.07, height: bottleHeight * 0.06)
                    // Follows the curve of the left shoulder.
                    .rotationEffect(.degrees(40))
                    .offset(x: -bottleWidth * 0.3, y: -bottleHeight * 0.12)
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: bottleWidth * 0.07, height: bottleHeight * 0.48)
                    .offset(x: -bottleWidth * 0.36, y: bottleHeight * 0.18)
                LabelShape()
                    .fill(Color(hex: 0xF7F1E8))
                label
                    .frame(width: bottleWidth * 0.94, height: bottleHeight * (LabelShape.bottom - LabelShape.top))
                    .offset(y: bottleHeight * ((LabelShape.top + LabelShape.bottom) / 2 - 0.5))
                CorkShape()
                    .fill(LinearGradient(colors: [Color(hex: 0xD9AE7E), Color(hex: 0xA97B4F)], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(20), anchor: CorkShape().anchor)
                    .offset(y: -bottleHeight * 0.11)
            }
            .frame(width: bottleWidth, height: bottleHeight)
            // An overlay, so the wide burst doesn't stretch the bottle's frame.
            .overlay { popLines }
            .offset(y: 56)
        }
        .frame(width: 1024, height: 1024)
    }

    /// A label in the Bordeaux style: a framed panel with a window engraving, the name and the vintage.
    private var label: some View {
        let ink = Color(hex: 0x4A1220)
        // Small caps lines share one size and tracking so they read as a set.
        func caption(_ text: String, size: CGFloat = 6.5) -> some View {
            Text(text)
                .font(.system(size: size, weight: .semibold, design: .serif))
                .tracking(size * 0.26)
        }
        return ZStack {
            // Double rule just inside the edge.
            Rectangle()
                .strokeBorder(ink.opacity(0.85), lineWidth: 1.8)
                .padding(8)
            Rectangle()
                .strokeBorder(ink.opacity(0.55), lineWidth: 0.7)
                .padding(12.5)
            VStack(spacing: 0) {
                caption("GRAND VIN DE WINDOWS")
                WindowShape()
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 56, height: 46)
                    .padding(.top, 11)
                Text("UNCORK")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .tracking(2.2)
                    .padding(.top, 12)
                caption("GRAND CRU \u{2022} .EXE", size: 7)
                    .padding(.top, 3)
                // Vintage between two short rules.
                HStack(spacing: 7) {
                    Rectangle().frame(width: 16, height: 0.7)
                    Text("MMXXVI")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(2.6)
                    Rectangle().frame(width: 16, height: 0.7)
                }
                .padding(.top, 14)
                caption("MIS EN BOUTEILLE SUR MAC", size: 4.8)
                    .opacity(0.85)
                    .padding(.top, 12)
            }
            .foregroundStyle(ink)
            // Text boxes carry more room below the baseline than above the cap height; nudge down to look centred.
            .offset(y: 2)
        }
    }

    /// Short strokes bursting out of the bottle's mouth on either side of the cork.
    private var popLines: some View {
        ForEach([-62.0, -34.0, 58.0], id: \.self) { angle in
            Capsule()
                .fill(Color(hex: 0xB9773F))
                .frame(width: 14, height: 48)
                .offset(y: -112)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(angle))
                // Centre the burst on the mouth, which is at 10% of the bottle's height.
                .offset(y: -bottleHeight * 0.4)
        }
    }
}

@main
struct RenderIcon {
    @MainActor
    static func main() throws {
        let output = URL(filePath: CommandLine.arguments[1])
        let renderer = ImageRenderer(content: AppIcon())
        renderer.scale = 1
        guard
            let tiff = renderer.nsImage?.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { fatalError("Couldn't render the icon") }
        try png.write(to: output)
    }
}
