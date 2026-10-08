import AppKit
import ImageIO
import UniformTypeIdentifiers

// Native, offscreen layout proof. No desktop capture or browser is involved.
// Run after export-menu-icons.swift. Dimensions mirror PreferredInputHUDView.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let width: CGFloat = 1120
let height: CGFloat = 844
let scale: CGFloat = 2

func color(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: alpha)
}

func rect(_ r: CGRect, fill: NSColor, radius: CGFloat = 0, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    fill.setFill(); path.fill()
    if let stroke { stroke.setStroke(); path.lineWidth = 0.75; path.stroke() }
}

func text(_ value: String, in frame: CGRect, size: CGFloat, weight: NSFont.Weight = .regular,
          ink: UInt32 = 0x242624, align: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color(ink), .paragraphStyle: paragraph
    ]
    NSAttributedString(string: value, attributes: attributes).draw(in: frame)
}

func image(_ url: URL, in frame: CGRect, white: Bool = false) {
    guard let source = NSImage(contentsOf: url) else { fatalError("Missing image: \(url.path)") }
    let rendered: NSImage
    if white {
        rendered = NSImage(size: source.size)
        rendered.lockFocus()
        source.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: source.size).fill(using: .sourceAtop)
        rendered.unlockFocus()
    } else { rendered = source }
    rendered.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.high])
}

func scene(variant: String, in bounds: CGRect, dark: Bool, active: Bool) {
    let ink: UInt32 = dark ? 0xf1f3ef : 0x262a27
    rect(bounds, fill: color(dark ? 0x2e3b3d : 0xdde4dc), radius: 12)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).addClip()
    rect(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 28), fill: color(dark ? 0x202c30 : 0xebeee7))
    NSGraphicsContext.restoreGraphicsState()
    text(dark ? "深色" : "浅色", in: CGRect(x: bounds.minX + 14, y: bounds.minY + 7, width: 50, height: 15), size: 10, ink: dark ? 0xa5b2b0 : 0x849082)
    let iconName = active ? "MenuBarIconEnabled" : "MenuBarIcon"
    image(root.appendingPathComponent("../2026-10-07-number-one/\(variant)/\(iconName).imageset/icon@2x.png"),
          in: CGRect(x: bounds.maxX - 205, y: bounds.minY + 5, width: 18, height: 18), white: dark)
    for (name, offset, symbolWidth) in [("wifi", CGFloat(163), CGFloat(21)), ("battery.100percent", CGFloat(124), CGFloat(26)), ("switch.2", CGFloat(83), CGFloat(20))] {
        image(root.appendingPathComponent("../2026-10-07-number-one/preview-symbols/\(name).png"),
              in: CGRect(x: bounds.maxX - offset, y: bounds.minY + 5, width: symbolWidth, height: 18), white: dark)
    }
    text("10:07", in: CGRect(x: bounds.maxX - 49, y: bounds.minY + 7, width: 39, height: 16), size: 11, weight: .medium, ink: ink)

    let hud = CGRect(x: bounds.midX - 117.5, y: bounds.minY + 39, width: 235, height: 52)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.19 : 0.08)
    shadow.shadowBlurRadius = 13
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.set()
    rect(hud, fill: color(dark ? 0x424e4f : 0xf0f4ef), radius: 26)
    NSGraphicsContext.restoreGraphicsState()
    rect(hud, fill: .clear, radius: 26, stroke: color(dark ? 0x5a6464 : 0xffffff))
    image(root.appendingPathComponent(active ? "../2026-10-07-number-one/enabled/hud-microphone.png" : "disabled/hud-microphone.png"),
          in: CGRect(x: hud.minX + 15, y: hud.minY + 9, width: 34, height: 34))
    text("DJI Mic Mini · USB", in: CGRect(x: hud.midX - 64, y: hud.minY + 10, width: 128, height: 17), size: 13, weight: .semibold, ink: ink, align: .center)
    text(active ? "输入优先级已开启" : "输入优先级已关闭", in: CGRect(x: hud.midX - 64, y: hud.minY + 26, width: 128, height: 17), size: 12, ink: dark ? 0xc1c7c6 : 0x737b75, align: .center)
    let lock = CGRect(x: hud.maxX - 37, y: hud.minY + 14, width: 24, height: 24)
    rect(lock, fill: color(active ? 0x007aff : (dark ? 0x626c6c : 0xd6ddd7)), radius: 12)
    image(root.appendingPathComponent("../2026-10-07-number-one/preview-symbols/\(active ? "lock.fill" : "lock.open.fill").png"),
          in: CGRect(x: lock.minX + 3, y: lock.minY + 4, width: 18, height: 16), white: active || dark)
    text("菜单栏 18 pt    /    HUD 图 34 pt    /    界面原尺寸", in: CGRect(x: bounds.minX, y: bounds.maxY - 22, width: bounds.width, height: 15), size: 9, ink: dark ? 0x9caaa8 : 0x819080, align: .center)
}


let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: Int(width * scale) * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.translateBy(x: 0, y: height * scale)
context.scaleBy(x: scale, y: -scale)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
rect(CGRect(x: 0, y: 0, width: width, height: height), fill: color(0xf6f5f2))
image(root.appendingPathComponent("../../../assets/micfirst-app-icon-256.png").standardizedFileURL,
      in: CGRect(x: 36, y: 36, width: 56, height: 56))
text("MICFIRST / B · ROUND 7 / 2026.10.07", in: CGRect(x: 106, y: 32, width: 600, height: 18), size: 10, weight: .semibold, ink: 0x82877b)
text("抱臂等下一棒", in: CGRect(x: 106, y: 50, width: 650, height: 38), size: 27, weight: .semibold)
text("关闭态：翘二郎腿，双手抱臂，坐在方块上等候。", in: CGRect(x: 106, y: 87, width: 740, height: 20), size: 12, ink: 0x7c8175)

for (index, active) in [true, false].enumerated() {
    let state = active ? "enabled" : "disabled"
    let x: CGFloat = index == 0 ? 36 : 572
    rect(CGRect(x: x, y: 136, width: 512, height: 624), fill: .white, radius: 20, stroke: color(0xe4e6dd))
    text(active ? "ON" : "OFF", in: CGRect(x: x + 24, y: 160, width: 34, height: 22), size: 11, weight: .semibold, ink: 0x9a9f91)
    text(active ? "开启 · 拿棒领跑" : "关闭 · 抱臂等候", in: CGRect(x: x + 65, y: 154, width: 350, height: 32), size: 21, weight: .semibold)
    let description = active ? "麦克风头部显示「1」，表达首选优先。\nHUD 延续拿着「1」号接力棒跑步的小人。" : "关闭优先级后，头部恢复普通麦克风格栅。\n头部正立，双臂胸前交叉，保留翘二郎腿。"
    text(description, in: CGRect(x: x + 24, y: 194, width: 462, height: 45), size: 12, ink: 0x7d8376)
    image(root.appendingPathComponent("../2026-10-07-number-one/\(state)/menu-large.png"), in: CGRect(x: x + 83, y: 297, width: 80, height: 80))
    image(root.appendingPathComponent(active ? "../2026-10-07-number-one/enabled/hud-microphone.png" : "disabled/hud-microphone.png"), in: CGRect(x: x + 253, y: 238, width: 226, height: 226))
    text(active ? "菜单栏 · 首选「1」" : "菜单栏 · 普通麦克风", in: CGRect(x: x + 28, y: 442, width: 190, height: 17), size: 10, ink: 0x95998e, align: .center)
    text(active ? "HUD · 跑步" : "HUD · 翘腿抱臂", in: CGRect(x: x + 260, y: 470, width: 220, height: 17), size: 10, ink: 0x95998e, align: .center)
    scene(variant: state, in: CGRect(x: x + 20, y: 498, width: 472, height: 116), dark: false, active: active)
    scene(variant: state, in: CGRect(x: x + 20, y: 624, width: 472, height: 116), dark: true, active: active)
}
text("实际尺寸检查：菜单栏 18 pt，HUD 插画 34 pt，胶囊 235 × 52 pt。背景材质为示意。", in: CGRect(x: 38, y: 785, width: 950, height: 20), size: 11, ink: 0x838b7b)
NSGraphicsContext.restoreGraphicsState()
let output = root.appendingPathComponent("states-comparison.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write review image.") }
print(output.path)
