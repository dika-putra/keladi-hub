// Generates assets/AppIcon.icns (via iconutil) and assets/MenuBarIcon.png. Run: swift assets/make-icons.swift assets
// Two designs on a cream tile, both two-tone (two accounts). Pick with the 2nd argument: `pinwheel` (default), `leaf`, `hub` or `captain`.
//   pinwheel: 8 rounded petals in a swirl.  leaf: keladi (caladium) leaf.  hub: a switcher with 5 colored AI-tool profiles around it.
import AppKit
import CoreGraphics

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets")
let fm = FileManager.default

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    draw(ctx, CGFloat(size))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

// Keladi (caladium) leaf: heart curve stretched into an arrowhead, notch on top, tip down, tilted, with a stem.
// `s` is one curve unit; points are given in curve units and mapped by pt().
struct Leaf {
    let cx: CGFloat, cy: CGFloat, s: CGFloat
    let kx: CGFloat = 0.82, ky: CGFloat = 1.35
    let tilt: CGFloat = 0.38

    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: cx + CGFloat(x) * kx * s, y: cy + CGFloat(y) * ky * s) }

    func outline() -> CGPath {
        let p = CGMutablePath()
        for i in 0...240 {
            let t = Double(i) / 240 * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            if i == 0 { p.move(to: pt(x, y)) } else { p.addLine(to: pt(x, y)) }
        }
        p.closeSubpath()
        return p
    }

    // Midrib plus (optionally) side veins that run from the midrib out toward the tip side of the margin.
    func veins(sides: Bool) -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(0, 3))
        p.addLine(to: pt(0, -13.5))
        if sides {
            for (sy, ex, ey) in [(0.5, 8.5, -2.5), (-3.5, 6.8, -7.0), (-7.5, 4.2, -10.5)] {
                for sign in [-1.0, 1.0] {
                    p.move(to: pt(0, sy))
                    p.addLine(to: pt(sign * ex, ey))
                }
            }
        }
        return p
    }

    func stem() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(0, 3))
        p.addQuadCurve(to: pt(2.5, 17), control: pt(-1.5, 10))
        return p
    }

    // Draws in a coordinate space rotated around the leaf center.
    func transformed(_ ctx: CGContext, _ body: () -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: -tilt)
        ctx.translateBy(x: -cx, y: -cy)
        body()
        ctx.restoreGState()
    }
}

func leafIcon(_ ctx: CGContext, _ w: CGFloat) {
    let u = w / 1024
    // macOS icon grid: 824pt artwork inside a 1024pt canvas.
    let art = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let shape = CGPath(roundedRect: art, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 24 * u, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(red: 0.95, green: 0.92, blue: 0.87, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
        CGColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1),
        CGColor(red: 0.91, green: 0.86, blue: 0.79, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512 * u, y: 924 * u), end: CGPoint(x: 512 * u, y: 100 * u), options: [])
    ctx.restoreGState()

    // Two accounts: left half terracotta, right half green.
    let leaf = Leaf(cx: 512 * u, cy: 505 * u, s: 15.5 * u)
    leaf.transformed(ctx) {
        ctx.addPath(leaf.stem())
        ctx.setStrokeColor(CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 1))
        ctx.setLineWidth(20 * u)
        ctx.setLineCap(.round)
        ctx.strokePath()
        for (color, rect) in [
            (CGColor(red: 0.85, green: 0.43, blue: 0.27, alpha: 1), CGRect(x: 0, y: 0, width: leaf.cx, height: w)),
            (CGColor(red: 0.20, green: 0.42, blue: 0.33, alpha: 1), CGRect(x: leaf.cx, y: 0, width: w - leaf.cx, height: w)),
        ] {
            ctx.saveGState()
            ctx.clip(to: rect)
            ctx.addPath(leaf.outline())
            ctx.setFillColor(color)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.addPath(leaf.veins(sides: true))
        ctx.setStrokeColor(CGColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1))
        ctx.setLineWidth(13 * u)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }
}

func leafMenuBar(_ ctx: CGContext, _ w: CGFloat) {
    let leaf = Leaf(cx: w * 0.5, cy: w * 0.5, s: 0.0225 * w)
    leaf.transformed(ctx) {
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.addPath(leaf.outline())
        ctx.fillPath()
        ctx.addPath(leaf.stem())
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(w * 0.07)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.addPath(leaf.veins(sides: false))
        ctx.setLineWidth(w * 0.06)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// One rounded petal at angle `a` around (cx, cy): spans radius r0...r1, tilted so the ring reads as a pinwheel.
func petal(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, angle a: CGFloat, r0: CGFloat, r1: CGFloat, width: CGFloat, tilt: CGFloat) {
    let len = r1 - r0
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: a)
    ctx.translateBy(x: 0, y: (r0 + r1) / 2)
    ctx.rotate(by: tilt)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -width / 2, y: -len / 2, width: width, height: len),
                       cornerWidth: width / 2, cornerHeight: width / 2, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
}

func tile(_ ctx: CGContext, _ u: CGFloat) {
    // macOS icon grid: 824pt artwork inside a 1024pt canvas.
    let art = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let shape = CGPath(roundedRect: art, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 24 * u, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(red: 0.95, green: 0.92, blue: 0.87, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
        CGColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1),
        CGColor(red: 0.91, green: 0.86, blue: 0.79, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512 * u, y: 924 * u), end: CGPoint(x: 512 * u, y: 100 * u), options: [])
    ctx.restoreGState()
}

func pinwheelIcon(_ ctx: CGContext, _ w: CGFloat) {
    let u = w / 1024
    tile(ctx, u)
    let terracotta = CGColor(red: 0.85, green: 0.43, blue: 0.27, alpha: 1)
    let umber = CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 1)
    for i in 0..<8 {
        ctx.setFillColor(i % 2 == 0 ? terracotta : umber)
        petal(ctx, cx: 512 * u, cy: 512 * u, angle: CGFloat(i) * .pi / 4, r0: 95 * u, r1: 335 * u, width: 118 * u, tilt: -0.24)
    }
}

func pinwheelMenuBar(_ ctx: CGContext, _ w: CGFloat) {
    // Single color; long and short petals alternate so the two "accounts" still read.
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    for i in 0..<8 {
        petal(ctx, cx: w / 2, cy: w / 2, angle: CGFloat(i) * .pi / 4, r0: w * 0.13, r1: i % 2 == 0 ? w * 0.48 : w * 0.40,
              width: w * 0.165, tilt: -0.24)
    }
}

// 4-point sparkle (generic "AI" glyph) of radius r centered on (cx, cy).
func sparkle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let k = 0.16 * r
    p.move(to: CGPoint(x: cx, y: cy + r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + k, y: cy + k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx + k, y: cy - k))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - k, y: cy - k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx - k, y: cy + k))
    p.closeSubpath()
    return p
}

// Hub and spokes: one switcher in the middle, five differently colored AI-tool profiles around it.
func hubIcon(_ ctx: CGContext, _ w: CGFloat) {
    let u = w / 1024
    tile(ctx, u)
    let c = CGPoint(x: 512 * u, y: 512 * u)
    let umber = CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 1)
    let cream = CGColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1)
    let colors = [
        CGColor(red: 0.85, green: 0.43, blue: 0.27, alpha: 1),
        CGColor(red: 0.20, green: 0.42, blue: 0.33, alpha: 1),
        CGColor(red: 0.25, green: 0.43, blue: 0.69, alpha: 1),
        CGColor(red: 0.89, green: 0.65, blue: 0.18, alpha: 1),
        CGColor(red: 0.55, green: 0.30, blue: 0.52, alpha: 1),
    ]
    let ring = 275 * u, nodeR = 82 * u, hubR = 118 * u
    var nodes: [CGPoint] = []
    for i in 0..<5 {
        let a = .pi / 2 + CGFloat(i) * 2 * .pi / 5
        nodes.append(CGPoint(x: c.x + cos(a) * ring, y: c.y + sin(a) * ring))
    }
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 0.35))
    ctx.setLineWidth(18 * u)
    ctx.setLineCap(.round)
    for n in nodes {
        ctx.move(to: c)
        ctx.addLine(to: n)
    }
    ctx.strokePath()
    for (i, n) in nodes.enumerated() {
        ctx.setFillColor(colors[i])
        ctx.fillEllipse(in: CGRect(x: n.x - nodeR, y: n.y - nodeR, width: 2 * nodeR, height: 2 * nodeR))
        ctx.addPath(sparkle(cx: n.x, cy: n.y, r: 52 * u))
        ctx.setFillColor(cream)
        ctx.fillPath()
    }
    ctx.setFillColor(umber)
    ctx.fillEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR))
    ctx.addPath(sparkle(cx: c.x, cy: c.y, r: 82 * u))
    ctx.setFillColor(cream)
    ctx.fillPath()
}

func hubMenuBar(_ ctx: CGContext, _ w: CGFloat) {
    let c = CGPoint(x: w / 2, y: w / 2)
    let ring = 0.34 * w, nodeR = 0.095 * w, hubR = 0.16 * w
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(0.05 * w)
    for i in 0..<5 {
        let a = .pi / 2 + CGFloat(i) * 2 * .pi / 5
        let n = CGPoint(x: c.x + cos(a) * ring, y: c.y + sin(a) * ring)
        ctx.move(to: c)
        ctx.addLine(to: n)
        ctx.strokePath()
        ctx.fillEllipse(in: CGRect(x: n.x - nodeR, y: n.y - nodeR, width: 2 * nodeR, height: 2 * nodeR))
    }
    ctx.fillEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR))
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    ctx.addPath(sparkle(cx: c.x, cy: c.y, r: hubR * 0.72))
    ctx.fillPath()
    ctx.restoreGState()
}

// Hub variant: the center is a "captain" with a big white crescent mustache; the colored nodes are the crew.
func captainIcon(_ ctx: CGContext, _ w: CGFloat) {
    let u = w / 1024
    tile(ctx, u)
    let c = CGPoint(x: 512 * u, y: 512 * u)
    let umber = CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 1)
    let cream = CGColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1)
    let colors = [
        CGColor(red: 0.85, green: 0.43, blue: 0.27, alpha: 1),
        CGColor(red: 0.20, green: 0.42, blue: 0.33, alpha: 1),
        CGColor(red: 0.25, green: 0.43, blue: 0.69, alpha: 1),
        CGColor(red: 0.89, green: 0.65, blue: 0.18, alpha: 1),
        CGColor(red: 0.55, green: 0.30, blue: 0.52, alpha: 1),
    ]
    let ring = 290 * u, nodeR = 74 * u, hubR = 165 * u
    var nodes: [CGPoint] = []
    for i in 0..<5 {
        let a = .pi / 2 + CGFloat(i) * 2 * .pi / 5
        nodes.append(CGPoint(x: c.x + cos(a) * ring, y: c.y + sin(a) * ring))
    }
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.17, blue: 0.14, alpha: 0.35))
    ctx.setLineWidth(16 * u)
    ctx.setLineCap(.round)
    for n in nodes {
        ctx.move(to: c)
        ctx.addLine(to: n)
    }
    ctx.strokePath()
    for (i, n) in nodes.enumerated() {
        ctx.setFillColor(colors[i])
        ctx.fillEllipse(in: CGRect(x: n.x - nodeR, y: n.y - nodeR, width: 2 * nodeR, height: 2 * nodeR))
        ctx.addPath(sparkle(cx: n.x, cy: n.y, r: 46 * u))
        ctx.setFillColor(cream)
        ctx.fillPath()
    }
    ctx.setFillColor(umber)
    ctx.fillEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR))
    // Crescent mustache: a wide ellipse minus the same ellipse shifted up, so the horns point up.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - 150 * u, y: c.y - 118 * u, width: 300 * u, height: 200 * u))
    ctx.clip()
    ctx.setFillColor(cream)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))
    ctx.setFillColor(umber)
    ctx.fillEllipse(in: CGRect(x: c.x - 156 * u, y: c.y - 56 * u, width: 312 * u, height: 212 * u))
    ctx.restoreGState()
    // Nose, so the crescent reads as a mustache and not as a smile.
    ctx.setFillColor(cream)
    ctx.fillEllipse(in: CGRect(x: c.x - 26 * u, y: c.y + 6 * u, width: 52 * u, height: 40 * u))
    // Eyes.
    ctx.setFillColor(cream)
    for dx in [-58.0, 58.0] {
        ctx.fillEllipse(in: CGRect(x: c.x + CGFloat(dx) * u - 19 * u, y: c.y + 92 * u - 19 * u, width: 38 * u, height: 38 * u))
    }
}

func captainMenuBar(_ ctx: CGContext, _ w: CGFloat) {
    let c = CGPoint(x: w / 2, y: w / 2)
    let ring = 0.36 * w, nodeR = 0.085 * w, hubR = 0.20 * w
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(0.045 * w)
    for i in 0..<5 {
        let a = .pi / 2 + CGFloat(i) * 2 * .pi / 5
        let n = CGPoint(x: c.x + cos(a) * ring, y: c.y + sin(a) * ring)
        ctx.move(to: c)
        ctx.addLine(to: n)
        ctx.strokePath()
        ctx.fillEllipse(in: CGRect(x: n.x - nodeR, y: n.y - nodeR, width: 2 * nodeR, height: 2 * nodeR))
    }
    ctx.fillEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR))
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    // Mustache: wide ellipse minus the same ellipse shifted up.
    ctx.addEllipse(in: CGRect(x: c.x - 0.15 * w, y: c.y - 0.12 * w, width: 0.30 * w, height: 0.20 * w))
    ctx.clip()
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))
    ctx.restoreGState()
    ctx.fillEllipse(in: CGRect(x: c.x - 0.15 * w, y: c.y - 0.06 * w, width: 0.30 * w, height: 0.20 * w))
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    for dx in [-0.06, 0.06] {
        ctx.fillEllipse(in: CGRect(x: c.x + CGFloat(dx) * w - 0.025 * w, y: c.y + 0.075 * w, width: 0.05 * w, height: 0.05 * w))
    }
    ctx.restoreGState()
}

let design = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "pinwheel"
let appIcon = ["leaf": leafIcon, "hub": hubIcon, "captain": captainIcon][design] ?? pinwheelIcon
let menuBarIcon = ["leaf": leafMenuBar, "hub": hubMenuBar, "captain": captainMenuBar][design] ?? pinwheelMenuBar

let iconset = out.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(render(size: base, draw: appIcon), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(render(size: base * 2, draw: appIcon), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
writePNG(render(size: 1024, draw: appIcon), to: out.appendingPathComponent("AppIcon-preview.png"))
writePNG(render(size: 36, draw: menuBarIcon), to: out.appendingPathComponent("MenuBarIcon.png"))
writePNG(render(size: 288, draw: menuBarIcon), to: out.appendingPathComponent("MenuBarIcon-preview.png"))
print("done")
