#if DEBUG
import AppKit
import Foundation
import OSLog

/// Opt-in, time-bounded, read-only sampling. No private service request, screenshot,
/// window title, device UID, or guessed native visibility is recorded.
@MainActor
final class HUDDiagnostics {
    static let shared = HUDDiagnostics()
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--hud-diagnostics") }

    private struct Snapshot: Codable {
        let anchor: HUDAnchor?
        let systemMenuAnchors: [HUDSystemMenuAnchor]
        let hud: HUDDiagnosticPresentation
        let native: NativeHUDProbeResult
        let capsuleCenterDeltaFromButton: CGFloat?
    }

    private struct Record: Encodable {
        let schemaVersion = 1
        let systemVersion: String
        let deviceSource: String
        let timestamp: Date
        let elapsed: TimeInterval
        let event: String
        let coordinates: String
        let snapshot: Snapshot
    }

    private let logger = Logger(subsystem: "com.tungloong.AudioInputLocker", category: "HUDDiagnostics")
    private let writeQueue = DispatchQueue(label: "MicFirst.HUDDiagnostics.Write")
    private var file: FileHandle?
    private var timer: Timer?
    private var anchor: (() -> HUDAnchor?)?
    private var presentation: (() -> HUDDiagnosticPresentation)?
    private var started: TimeInterval = 0
    private var lastWrite: TimeInterval = 0
    private var previous: Data?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func start(anchor: @escaping () -> HUDAnchor?, presentation: @escaping () -> HUDDiagnosticPresentation) {
        guard Self.isEnabled, timer == nil else { return }
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MicFirst/HUDDiagnostics", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("hud-\(UUID().uuidString).jsonl")
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            file = try FileHandle(forWritingTo: url)
            self.anchor = anchor
            self.presentation = presentation
            started = ProcessInfo.processInfo.systemUptime
            previous = nil
            lastWrite = 0
            logger.notice("Read-only HUD diagnostic log: \(url.path, privacy: .public)")
            record(event: "session-start")
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if ProcessInfo.processInfo.systemUptime - self.started >= 120 {
                        self.stop()
                    } else {
                        self.record(event: nil)
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } catch {
            logger.error("Unable to start HUD diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    func record(event: String?) {
        guard let file, let presentation else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let anchor = anchor?()
        let hud = presentation()
        let owners = Dictionary(uniqueKeysWithValues: NativeHUDProbe.ownerBundles.flatMap { bundle in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundle).map { ($0.processIdentifier, bundle) }
        })
        let primaryMaxY = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? 0
        let native = NativeHUDProbe.inspect(
            windowInfos: CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]],
            ownerBundlesByPID: owners, primaryScreenMaxY: primaryMaxY, targetScreen: anchor?.screenFrame
        )
        let snapshot = Snapshot(
            anchor: anchor, systemMenuAnchors: PreferredInputHUD.shared.systemMenuAnchors, hud: hud, native: native,
            capsuleCenterDeltaFromButton: hud.capsuleFrame.flatMap { frame in anchor.map { frame.midX - $0.buttonFrame.midX } }
        )
        guard let signature = try? encoder.encode(snapshot) else { return }
        guard event != nil || signature != previous || now - lastWrite >= 1 else { return }
        previous = signature
        lastWrite = now
        guard var data = try? encoder.encode(Record(
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceSource: ProcessInfo.processInfo.arguments.contains("--priority-preview") ? "simulated" : "real",
            timestamp: Date(), elapsed: now - started, event: event ?? "sample",
            coordinates: "AppKit screen points (bottom-left); rawCGFrame uses top-left", snapshot: snapshot
        )) else { return }
        data.append(0x0A)
        let recordData = data
        writeQueue.async { try? file.write(contentsOf: recordData) }
    }

    func stop() {
        guard let file else { return }
        record(event: "session-stop")
        timer?.invalidate()
        timer = nil
        self.file = nil
        // Flush queued records before closing the handle, including termination.
        writeQueue.sync { try? file.close() }
        anchor = nil
        presentation = nil
    }
}
#endif
