// Read-only public Accessibility probe; no popup/app-tree traversal or permission prompt.
import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func text(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}
func position(_ element: AXUIElement) -> CGPoint? {
    guard let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
}
func size(_ element: AXUIElement) -> CGSize? {
    guard let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
}
struct Anchor: Codable {
    let identifier: String
    let buttonFrame: CGRect
    let screenFrame: CGRect
}
func readAnchors() -> [Anchor] {
    guard AXIsProcessTrusted() else { return [] }
    let screens = NSScreen.screens
    let primaryMaxY = screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? 0
    var anchors: [Anchor] = []
    for bundle in ["com.apple.controlcenter", "com.apple.MenuBarAgent", "com.apple.systemuiserver", "com.tungloong.AudioInputLocker"] {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundle) {
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.1)
            for name in [kAXMenuBarAttribute, kAXExtrasMenuBarAttribute] {
                guard let value = attribute(root, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
                let items = (attribute(value as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement] ?? []).prefix(128)
                var candidates = Array(items)
                for group in items where text(group, kAXRoleAttribute) == "AXGroup" {
                    candidates += (attribute(group, kAXChildrenAttribute) as? [AXUIElement] ?? []).prefix(16)
                }
                for item in candidates {
                    let identifier = text(item, kAXIdentifierAttribute)
                    guard ["com.apple.menuextra.sound", "com.apple.menuextra.controlcenter", "micfirst-status-item"].contains(identifier),
                          let p = position(item), let s = size(item), s.width > 0, s.height > 0 else { continue }
                    let frame = CGRect(x: p.x, y: primaryMaxY - p.y - s.height, width: s.width, height: s.height)
                    guard let screen = screens.first(where: { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }),
                          screen.frame.maxY - frame.midY < 100 else { continue }
                    anchors.append(Anchor(identifier: identifier, buttonFrame: frame, screenFrame: screen.frame))
                }
            }
        }
    }
    return anchors
}
let args = CommandLine.arguments
let anchors = readAnchors()
if let index = args.firstIndex(of: "--deliver"), index + 1 < args.count, let pid = Int32(args[index + 1]) {
    let json = String(decoding: try JSONEncoder().encode(anchors), as: UTF8.self)
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("MicFirst.MenuAnchorSnapshot.\(pid)"), object: json, userInfo: nil, deliverImmediately: true)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
} else if args.contains("--json") {
    print(String(decoding: try JSONEncoder().encode(anchors), as: UTF8.self))
} else {
    print("Accessibility authorized:", AXIsProcessTrusted())
    for anchor in anchors { print(anchor.identifier, "AppKit frame:", anchor.buttonFrame, "center X:", anchor.buttonFrame.midX) }
}
