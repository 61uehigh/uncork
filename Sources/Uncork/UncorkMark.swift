import SwiftUI

/// A wine bottle whose cork pops out while `isOpen` is true. SF Symbols has no wine bottle, so it's drawn here.
struct UncorkMark: View {
    var isOpen: Bool
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = proxy.size.width
            // Room around the frame so the popped cork isn't clipped by the mask.
            let margin = height * 0.2
            // Drawn as a mask over one fill so overlapping strokes don't darken a translucent style like .secondary.
            Rectangle()
                .mask {
                    ZStack {
                        BottleShape()
                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                        LabelShape()
                            .stroke(style: StrokeStyle(lineWidth: lineWidth * 0.7, lineJoin: .round))
                        labelArt(width: width)
                            .frame(width: width * 0.94, height: height * (LabelShape.bottom - LabelShape.top))
                            .position(x: width / 2, y: height * (LabelShape.top + LabelShape.bottom) / 2)
                        cork(width: width, height: height)
                            .fill()
                    }
                    .foregroundStyle(.black)
                    .padding(margin)
                }
                .padding(-margin)
        }
        .aspectRatio(0.3, contentMode: .fit)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isOpen)
        .accessibilityHidden(true)
    }

    /// A small window over "EXE", echoing the app icon's label. Sizes scale with the bottle's width.
    private func labelArt(width: CGFloat) -> some View {
        VStack(spacing: width * 0.1) {
            WindowShape()
                .stroke(style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round, lineJoin: .round))
                .frame(width: width * 0.6, height: width * 0.5)
            Text("EXE")
                .font(.system(size: width * 0.24, weight: .bold, design: .serif))
                .tracking(width * 0.02)
                .fixedSize()
        }
    }

    /// Closed, the cork is pushed into the neck with a gap on each side and its top just above the lip (y 0.1), so it
    /// reads as inserted. Popped, the same cork flies up, tilted.
    private func cork(width: CGFloat, height: CGFloat) -> some Shape {
        let gap: CGFloat = 0.5
        let corkWidth = max(BottleShape.neckWidth - (lineWidth + gap * 2) / max(width, 1), 0.08)
        let length: CGFloat = 0.13
        let cork = isOpen
            ? CorkShape(width: corkWidth, bottom: 0.15, length: length)
            : CorkShape(width: corkWidth, bottom: 0.075 + length, length: length)
        return cork
            .rotation(.degrees(isOpen ? 14 : 0), anchor: cork.anchor)
            .offset(y: isOpen ? -height * 0.1 : 0)
    }
}

/// A Bordeaux bottle. Coordinates are fractions of the rect: the cork's room above y 0.1, a long straight neck,
/// rounded shoulders from y 0.29 to 0.43, and a straight body down to a flat bottom at 1.
struct BottleShape: Shape {
    /// The neck runs from x 0.36 to 0.64, centred.
    static let neckWidth: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        // Mouth. The lip is the same width as the neck so nothing sticks out.
        path.move(to: point(0.36, 0.1))
        path.addLine(to: point(0.64, 0.1))
        // Neck and right shoulder: a short dome that turns straight down into the body.
        path.addLine(to: point(0.64, 0.29))
        path.addCurve(to: point(0.97, 0.43), control1: point(0.66, 0.33), control2: point(0.97, 0.32))
        // Body and bottom.
        path.addLine(to: point(0.97, 0.97))
        path.addQuadCurve(to: point(0.88, 1), control: point(0.97, 1))
        path.addLine(to: point(0.12, 1))
        path.addQuadCurve(to: point(0.03, 0.97), control: point(0.03, 1))
        // Left shoulder and neck back up to the mouth.
        path.addLine(to: point(0.03, 0.43))
        path.addCurve(to: point(0.36, 0.29), control1: point(0.03, 0.32), control2: point(0.34, 0.33))
        path.closeSubpath()
        return path
    }
}

/// A tall label wrapped round the middle of the body, as on a Bordeaux château bottle.
struct LabelShape: Shape {
    static let top: CGFloat = 0.47
    static let bottom: CGFloat = 0.86

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX + rect.width * 0.03,
            y: rect.minY + rect.height * Self.top,
            width: rect.width * 0.94,
            height: rect.height * (Self.bottom - Self.top)
        ))
    }
}

/// An arched window with a cross-shaped sash bar and both shutters swung open: the engraving on the label, and a nod
/// to the Windows programs inside. The shutters keep it from reading as a plain grid. Drawn for a rect about 1.2:1.
struct WindowShape: Shape {
    /// Where the arch springs from the window's sides, as a fraction of the height. The cross bar sits on this line.
    static let springLine: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let spring = Self.springLine
        var path = Path()

        // Window sides, then a true circular arch through both springing points and the top centre.
        let left = point(0.21, spring), right = point(0.79, spring)
        let halfChord = (right.x - left.x) / 2
        let rise = left.y - rect.minY
        let radius = (halfChord * halfChord + rise * rise) / (2 * rise)
        let centre = CGPoint(x: rect.midX, y: rect.minY + radius)
        let startAngle = Angle(radians: atan2(left.y - centre.y, left.x - centre.x))
        let endAngle = Angle(radians: atan2(right.y - centre.y, right.x - centre.x))
        path.move(to: point(0.21, 1))
        path.addLine(to: left)
        path.addArc(center: centre, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addLine(to: point(0.79, 1))

        // Sash bars.
        path.move(to: point(0.5, 0))
        path.addLine(to: point(0.5, 1))
        path.move(to: left)
        path.addLine(to: right)

        // Open shutters: the outer edge stands a little below the arch's crown, then the top sweeps across and down,
        // meeting the window's side vertically just below the springing line.
        let meet = spring + 0.1
        path.move(to: point(0, 1))
        path.addLine(to: point(0, 0.08))
        path.addCurve(to: point(0.21, meet), control1: point(0.13, 0.08), control2: point(0.21, 0.16))
        path.move(to: point(1, 1))
        path.addLine(to: point(1, 0.08))
        path.addCurve(to: point(0.79, meet), control1: point(0.87, 0.08), control2: point(0.79, 0.16))

        // Sill line under everything.
        path.move(to: point(0, 1))
        path.addLine(to: point(1, 1))
        return path
    }
}

/// A cork centred horizontally, standing on `bottom` and reaching `length` above it. All values are fractions of the rect.
struct CorkShape: Shape {
    var width: CGFloat = 0.17
    var bottom: CGFloat = 0.19
    var length: CGFloat = 0.19

    /// The cork's own bottom edge, for tilting it in place rather than around the whole bottle.
    var anchor: UnitPoint { UnitPoint(x: 0.5, y: bottom) }

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(width, AnimatablePair(bottom, length)) }
        set { (width, bottom, length) = (newValue.first, newValue.second.first, newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(
            x: rect.minX + rect.width * (0.5 - width / 2),
            y: rect.minY + rect.height * (bottom - length),
            width: rect.width * width,
            height: rect.height * length
        ), cornerRadius: rect.width * 0.05)
    }
}
