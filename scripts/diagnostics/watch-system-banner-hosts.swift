// Read-only: prints MenuBarAgent and Control Center windows above the menu bar as they come
// and go, from public window metadata. Use it to re-check NativeHUDProbe's host signature on
// another macOS version. No permission, title, image, or private API.
import AppKit

let owners = ["com.apple.MenuBarAgent", "com.apple.controlcenter"]
let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
let seconds = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 60
let started = ProcessInfo.processInfo.systemUptime
func elapsed() -> String { String(format: "%6.2f", ProcessInfo.processInfo.systemUptime - started) }

setbuf(stdout, nil)
print("Watching for \(Int(seconds)) s. Press a volume or brightness key, or connect AirPods.")
var shown: [Int: String] = [:]
while ProcessInfo.processInfo.systemUptime - started < seconds {
    var current: [Int: String] = [:]
    let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    for info in infos as? [[String: Any]] ?? [] {
        guard let level = (info[kCGWindowLayer as String] as? NSNumber)?.intValue, level > menuBarLevel,
              let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
              let owner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, owners.contains(owner),
              let id = (info[kCGWindowNumber as String] as? NSNumber)?.intValue,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
        let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
        current[id] = "\(owner) level \(level) alpha \(alpha) top-left frame \(frame)"
    }
    for (id, line) in current.sorted(by: { $0.key < $1.key }) where shown[id] != line { print(elapsed(), "shown ", id, line) }
    for id in shown.keys.sorted() where current[id] == nil { print(elapsed(), "hidden", id) }
    shown = current
    Thread.sleep(forTimeInterval: 0.05)
}
