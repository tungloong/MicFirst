// Read-only public Accessibility probe; no popup/app-tree traversal or permission prompt.
import AppKit
import ApplicationServices

struct Anchor: Codable {
    let identifier: String
    let buttonFrame: CGRect
    let screenFrame: CGRect
}
struct MenuAnchorReader {
    var deadline: TimeInterval = .infinity

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return nil }
        // Timeouts belong to each AX element, not just the application root.
        AXUIElementSetMessagingTimeout(element, Float(min(0.1, remaining)))
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private func text(_ element: AXUIElement, _ name: String) -> String {
        attribute(element, name) as? String ?? ""
    }
    private func position(_ element: AXUIElement) -> CGPoint? {
        guard let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }
    private func size(_ element: AXUIElement) -> CGSize? {
        guard let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    func read(targetPID: pid_t? = nil) -> [Anchor] {
        guard AXIsProcessTrusted() else { return [] }
        let screens = NSScreen.screens
        let primaryMaxY = screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? 0
        var anchors: [Anchor] = []
        for bundle in ["com.apple.controlcenter", "com.apple.MenuBarAgent", "com.apple.systemuiserver", "com.tungloong.AudioInputLocker"] {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundle) {
                if bundle == "com.tungloong.AudioInputLocker", let targetPID, app.processIdentifier != targetPID { continue }
                let root = AXUIElementCreateApplication(app.processIdentifier)
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
}

struct SnapshotDelivery: Encodable {
    let deliveryID: UUID
    let anchors: [Anchor]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func deliver(to pid: pid_t) throws {
    guard AXIsProcessTrusted() else {
        fail("HUD startup snapshot requires an already-authorized Accessibility execution context.")
    }
    let center = DistributedNotificationCenter.default()
    let deliveryID = UUID()
    var acknowledged = false
    // Listen before sending so a fast receiver cannot race its acknowledgement.
    let observer = center.addObserver(
        forName: Notification.Name("MicFirst.MenuAnchorSnapshotAccepted.\(pid)"),
        object: deliveryID.uuidString, queue: .main
    ) { _ in acknowledged = true }
    defer { center.removeObserver(observer) }

    let deadline = ProcessInfo.processInfo.systemUptime + 10
    let reader = MenuAnchorReader(deadline: deadline)
    while !acknowledged, ProcessInfo.processInfo.systemUptime < deadline {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            fail("MicFirst exited before acknowledging its HUD startup snapshot.")
        }
        if app.isFinishedLaunching {
            let anchors = reader.read(targetPID: pid)
            let json = String(decoding: try JSONEncoder().encode(SnapshotDelivery(deliveryID: deliveryID, anchors: anchors)), as: UTF8.self)
            center.postNotificationName(
                Notification.Name("MicFirst.MenuAnchorSnapshot.\(pid)"), object: json, userInfo: nil, deliverImmediately: true
            )
        }
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(min(0.25, remaining))) }
    }
    guard acknowledged else {
        fail("Timed out after 10 seconds waiting for MicFirst to accept a usable HUD menu-button snapshot. Relaunch with its menu icon visible.")
    }
    center.postNotificationName(
        Notification.Name("MicFirst.MenuAnchorSnapshotFinished.\(pid)"),
        object: deliveryID.uuidString, userInfo: nil, deliverImmediately: true
    )
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}

let args = CommandLine.arguments
if let index = args.firstIndex(of: "--deliver") {
    guard index + 1 < args.count, let pid = Int32(args[index + 1]), pid > 0 else { fail("Usage: \(args[0]) --deliver PID") }
    try deliver(to: pid)
} else {
    let anchors = MenuAnchorReader().read()
    if args.contains("--json") {
        print(String(decoding: try JSONEncoder().encode(anchors), as: UTF8.self))
    } else {
        print("Accessibility authorized:", AXIsProcessTrusted())
        for anchor in anchors { print(anchor.identifier, "AppKit frame:", anchor.buttonFrame, "center X:", anchor.buttonFrame.midX) }
    }
}
