// Renders the 1024×1024 app icon. Compiled together with Sources/Uncork/UncorkMark.swift by scripts/make-icon.sh.
import AppKit
import SwiftUI

/// The top of a wine bottle drawn in black lines on a white tile, cropped by the tile, with a cork-coloured cork
/// popping out and a ">" beside the mouth: the pop of the cork, and a nod to a command prompt.
struct AppIcon: View {
    // The bottle is drawn larger than the tile so only its top shows; the tile crops the rest.
    private let bottleHeight: CGFloat = 1000
    private var bottleWidth: CGFloat { bottleHeight * 0.3 }
    /// Where the bottle's centre sits below the tile's centre.
    private let bottleOffset: CGFloat = 330
    private let line: CGFloat = 34
    private let ink = Color(white: 0.07)
    private let cork = Color(red: 0.80, green: 0.58, blue: 0.34)

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack {
            // macOS icon grid: an 824-point tile centred in the 1024 canvas.
            tile
                .fill(LinearGradient(colors: [.white, Color(white: 0.93)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)

            ZStack {
                ZStack {
                    BottleShape()
                        .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                    // Only the label's top edge is inside the tile; keep its sides off the bottle's outline.
                    LabelShape()
                        .stroke(ink, style: StrokeStyle(lineWidth: line * 0.75, lineJoin: .round))
                        .mask(Rectangle().padding(.horizontal, line * 0.6))
                    // A solid cork with no outline, the same outer size as an outlined one would be.
                    CorkShape(width: 0.2, bottom: 0.15, length: 0.13)
                        .rotation(.degrees(18), anchor: UnitPoint(x: 0.5, y: 0.15))
                        .offset(y: -bottleHeight * 0.1 - 40)
                        .stroke(cork, style: StrokeStyle(lineWidth: line * 0.85, lineJoin: .round))
                    CorkShape(width: 0.2, bottom: 0.15, length: 0.13)
                        .rotation(.degrees(18), anchor: UnitPoint(x: 0.5, y: 0.15))
                        .offset(y: -bottleHeight * 0.1 - 40)
                        .fill(cork)
                }
                .frame(width: bottleWidth, height: bottleHeight)
                .offset(y: bottleOffset)
            }
            .frame(width: 824, height: 824)
            .clipShape(tile)

            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 92, y: 46))
                path.addLine(to: CGPoint(x: 0, y: 92))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            .frame(width: 92, height: 92)
            // Up and to the left of the bottle's mouth.
            .position(x: 318, y: 372)
        }
        .frame(width: 1024, height: 1024)
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
