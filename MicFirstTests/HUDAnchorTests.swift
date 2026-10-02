import AppKit
import XCTest

final class HUDAnchorTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let workArea = CGRect(x: 0, y: 87, width: 1710, height: 987)
    private let hostSize = CGSize(width: 360, height: 136)
    private let capsuleSize = CGSize(width: 235, height: 52)

    private func anchor(x: CGFloat = 1200) -> HUDAnchor? {
        HUDAnchor(buttonFrame: CGRect(x: x, y: 1082, width: 34, height: 22),
                  statusWindowFrame: CGRect(x: x, y: 1074, width: 34, height: 38),
                  screenFrame: screen, visibleScreenFrame: workArea, backingScale: 2)
    }

    func testDirectButtonCenterAndMenuBarGapDetermineHUD() throws {
        let anchor = try XCTUnwrap(anchor())
        let frame = anchor.normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9)
        XCTAssertEqual(frame.midX, anchor.buttonFrame.midX)
        XCTAssertEqual(frame.minY + 94, workArea.maxY - 9)
    }

    func testMovedStatusItemMovesAnchorByTheSameAmount() throws {
        let before = try XCTUnwrap(anchor()).normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9)
        let after = try XCTUnwrap(anchor(x: 1337)).normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9)
        XCTAssertEqual(after.minX - before.minX, 137)
        XCTAssertEqual(after.minY, before.minY)
    }

    func testDetachedOffscreenAndTransientGeometryAreRejected() {
        XCTAssertNil(anchor(x: -10000))
        XCTAssertNil(HUDAnchor(buttonFrame: .zero, statusWindowFrame: .zero,
                               screenFrame: screen, visibleScreenFrame: workArea, backingScale: 2))
        XCTAssertNil(HUDAnchor(buttonFrame: CGRect(x: 1200, y: 1061, width: 34, height: 22),
                               statusWindowFrame: CGRect(x: 1200, y: 1053, width: 34, height: 38),
                               screenFrame: screen, visibleScreenFrame: workArea, backingScale: 2))
    }

    func testRevealedAutoHiddenBarUsesMeasuredStatusWindow() throws {
        let anchor = try XCTUnwrap(HUDAnchor(
            buttonFrame: CGRect(x: 1200, y: 1082, width: 34, height: 22),
            statusWindowFrame: CGRect(x: 1200, y: 1074, width: 34, height: 38),
            screenFrame: screen, visibleScreenFrame: screen, backingScale: 2
        ))
        XCTAssertEqual(anchor.normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9).minY + 94, 1065)
    }

    func testStatusWindowOverscanDoesNotChangePersistentMenuBarGap() throws {
        let external = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let anchor = try XCTUnwrap(HUDAnchor(
            buttonFrame: CGRect(x: 1911, y: 1414, width: 34, height: 22),
            statusWindowFrame: CGRect(x: 1911, y: 1406, width: 34, height: 38),
            screenFrame: external, visibleScreenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1410), backingScale: 2
        ))
        let normal = anchor.normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9)
        let placed = try XCTUnwrap(HUDPlacement().frame(anchoredAt: normal, capsuleSize: capsuleSize, on: external))
        XCTAssertEqual(placed.minY + 94, 1401, "The transparent canvas must not push the capsule down")
        XCTAssertEqual(placed.maxY, 1443, "Only transparent space extends above the display")
    }

    func testScreenClampingUsesVisibleCapsuleInsteadOfTransparentCanvas() throws {
        let anchor = try XCTUnwrap(anchor(x: 1680))
        let normal = anchor.normalWindowFrame(windowSize: hostSize, capsuleSize: capsuleSize, gap: 9)
        let placed = try XCTUnwrap(HUDPlacement().frame(anchoredAt: normal, capsuleSize: capsuleSize, on: screen))
        XCTAssertEqual(placed.minX + 62.5 + 235, screen.maxX - 6)
        XCTAssertGreaterThan(placed.maxX, screen.maxX)
    }
}

final class NativeHUDProbeTests: XCTestCase {
    private let owners: [pid_t: String] = [
        42: "com.apple.controlcenter", 43: "com.apple.MenuBarAgent", 44: "com.example.OtherApp"
    ]

    /// Defaults are the AirPods routing banner host measured on macOS 27.0.
    private func window(id: Int = 1, pid: Int = 43, level: Int = 101,
                        frame: CGRect = CGRect(x: 1305, y: 38, width: 352, height: 157),
                        alpha: Double = 1, onScreen: Bool = true) -> [String: Any] {
        [
            kCGWindowNumber as String: id, kCGWindowOwnerPID as String: pid, kCGWindowName as String: "",
            kCGWindowBounds as String: ["X": frame.minX, "Y": frame.minY, "Width": frame.width, "Height": frame.height],
            kCGWindowLayer as String: level, kCGWindowAlpha as String: alpha, kCGWindowIsOnscreen as String: onScreen
        ]
    }

    private func hosts(_ windows: [[String: Any]]) -> [NativeHUDHost] {
        NativeHUDProbe.hosts(in: windows, primaryScreenMaxY: 1112) { owners[$0] }
    }

    func testMenuBarAgentBannerHostIsReportedInAppKitCoordinates() {
        XCTAssertEqual(hosts([window()]), [NativeHUDHost(
            id: 1, ownerBundleID: "com.apple.MenuBarAgent", level: 101,
            frame: CGRect(x: 1305, y: 917, width: 352, height: 157)
        )])
    }

    func testOccupiedFrameIsTheWidestCapsuleCenteredInTheHost() throws {
        let host = try XCTUnwrap(hosts([window()]).first)
        XCTAssertEqual(host.occupiedFrame, CGRect(x: 1336, y: 917, width: 290, height: 157))
        let narrow = NativeHUDHost(id: 2, ownerBundleID: "com.apple.MenuBarAgent", level: 101,
                                   frame: CGRect(x: 100, y: 900, width: 270, height: 100))
        XCTAssertEqual(narrow.occupiedFrame, narrow.frame)
    }

    func testHostPastTheScreenEdgeKeepsItsMeasuredFrame() throws {
        // The display-brightness banner under Control Center: the host ends 20 pt beyond a 1710-pt display.
        let host = try XCTUnwrap(hosts([window(frame: CGRect(x: 1378, y: 38, width: 352, height: 157))]).first)
        XCTAssertEqual(host.frame.maxX, 1730)
        XCTAssertEqual(host.occupiedFrame.maxX, 1699)
    }

    func testMenuBarOtherOwnersAndLargePanelsAreIgnored() {
        XCTAssertEqual(hosts([
            window(level: 24, frame: CGRect(x: 0, y: 0, width: 1710, height: 38)),
            window(pid: 44),
            window(pid: 99),
            window(frame: CGRect(x: 1188, y: 38, width: 522, height: 1045))
        ]), [])
    }

    func testHiddenOrTransparentHostsAreIgnored() {
        XCTAssertEqual(hosts([window(onScreen: false), window(alpha: 0)]), [])
    }

    func testControlCenterNeedsItsMacOS26BannerLevel() {
        XCTAssertEqual(hosts([window(pid: 42, level: 101)]), [])
        XCTAssertEqual(hosts([window(pid: 42, level: 2005)]).first?.ownerBundleID, "com.apple.controlcenter")
    }

    func testOwnerIsResolvedOnlyForBannerShapedWindows() {
        var lookups = 0
        let found = NativeHUDProbe.hosts(in: [
            window(id: 1, level: 0),
            window(id: 2, frame: CGRect(x: 0, y: 0, width: 1710, height: 1112)),
            window(id: 3)
        ], primaryScreenMaxY: 1112) { lookups += 1; return owners[$0] }
        XCTAssertEqual(found.map(\.id), [3])
        XCTAssertEqual(lookups, 1)
    }

    func testHostsAreNotEncodedWithWindowTitles() throws {
        var titled = window()
        titled[kCGWindowName as String] = "Private device or window title"
        let data = try JSONEncoder().encode(hosts([titled]))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private device or window title"))
    }
}

final class HUDHorizontalPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let size = CGSize(width: 235, height: 52)
    /// The 290-pt strip a banner host keeps clear, centered under a menu button.
    private func banner(_ center: CGFloat) -> CGRect { CGRect(x: center - 145, y: 917, width: 290, height: 157) }
    private func own(_ center: CGFloat) -> CGRect { CGRect(x: center - 180, y: 971, width: 360, height: 136) }
    private func place(_ center: CGFloat, _ banners: [CGRect], keeping current: CGRect? = nil) -> CGRect? {
        HUDPlacement().frame(anchoredAt: own(center), capsuleSize: size, on: screen, avoiding: banners, keeping: current)
    }

    func testNoBannerOrADistantBannerKeepsOwnPosition() {
        XCTAssertEqual(place(1343, []), own(1343))
        XCTAssertEqual(place(400, [banner(1481)]), own(400))
    }

    func testBannerUnderSoundMovesHUDLeftInTheSameRow() throws {
        // MicFirst's icon at 1343 and Sound at 1481, as measured. The right side is past the display.
        let frame = try XCTUnwrap(place(1343, [banner(1481)]))
        XCTAssertEqual(frame.minX + 62.5 + 235, 1336 - 12)
        XCTAssertEqual(frame.minY, own(1343).minY)
    }

    func testNearestFreeSideWins() throws {
        let right = try XCTUnwrap(place(900, [banner(800)]))
        XCTAssertEqual(right.minX + 62.5, 945 + 12)
        let left = try XCTUnwrap(place(700, [banner(800)]))
        XCTAssertEqual(left.minX + 62.5 + 235, 655 - 12)
    }

    func testExactGapDoesNotMoveHUD() {
        let center: CGFloat = 1336 - 12 - 117.5
        XCTAssertEqual(place(center, [banner(1481)]), own(center))
    }

    func testBannerInAnotherRowIsIgnored() {
        XCTAssertEqual(place(1343, [CGRect(x: 1336, y: 700, width: 290, height: 157)]), own(1343))
    }

    func testMovedHUDStaysAfterTheBannerLeaves() throws {
        let moved = try XCTUnwrap(place(1343, [banner(1481)]))
        XCTAssertEqual(place(1343, [], keeping: moved), moved)
    }

    func testKeptPositionYieldsWhenItBecomesBlocked() throws {
        let moved = try XCTUnwrap(place(1343, [banner(1481)]))
        // Blocks the moved capsule (1089...1324) but not the own anchor (1225.5...1460.5).
        XCTAssertEqual(place(1343, [CGRect(x: 1000, y: 917, width: 200, height: 157)], keeping: moved), own(1343))
    }

    func testKeptPositionFromAnotherRowIsDropped() {
        XCTAssertEqual(place(1343, [], keeping: own(1100).offsetBy(dx: 0, dy: -30)), own(1343))
    }

    func testTwoBannersLeaveTheNearestFreeSide() throws {
        // AirPods under Sound together with display brightness under Control Center.
        let frame = try XCTUnwrap(place(1343, [banner(1481), banner(1554)]))
        XCTAssertEqual(frame.minX + 62.5 + 235, 1336 - 12)
    }

    func testNoRoomOnEitherSideSkipsWithoutLowerRow() {
        let tiny = CGRect(x: 0, y: 0, width: 450, height: 1112)
        XCTAssertNil(HUDPlacement().frame(anchoredAt: own(225), capsuleSize: size, on: tiny, avoiding: [banner(225)]))
    }

    func testMeasuredStatusBarWindowKeepsTheButtonCenter() throws {
        let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        let visible = CGRect(x: 0, y: 87, width: 1710, height: 987)
        let button = CGRect(x: 1383, y: 1074, width: 34, height: 38)
        let menu = CGRect(x: button.minX, y: visible.maxY, width: button.width, height: screen.maxY - visible.maxY)
        let anchor = try XCTUnwrap(HUDAnchor(
            buttonFrame: button, statusWindowFrame: menu, screenFrame: screen,
            visibleScreenFrame: visible, backingScale: 2
        ))
        XCTAssertEqual(anchor.buttonFrame.midX, 1400, "The status-bar window center matches the Accessibility button")
    }
}

final class OwnMenuBarButtonTests: XCTestCase {
    private let builtIn = MenuBarScreenRecord(
        frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
        visibleFrame: CGRect(x: 0, y: 87, width: 1710, height: 987)
    )
    private let external = MenuBarScreenRecord(
        frame: CGRect(x: 1710, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1710, y: 80, width: 1920, height: 960)
    )

    func testChoosesTheStatusBarWindowOnTheMouseScreen() {
        let builtInButton = MenuBarWindowRecord(frame: CGRect(x: 1383, y: 1074, width: 34, height: 38), className: "NSStatusBarWindow")
        let externalButton = MenuBarWindowRecord(frame: CGRect(x: 3400, y: 1042, width: 34, height: 38), className: "NSStatusBarWindow")
        let popup = MenuBarWindowRecord(frame: CGRect(x: 1100, y: 700, width: 308, height: 360), className: "MenuBarExtraWindow")
        let hiddenReplica = MenuBarWindowRecord(frame: CGRect(x: 0, y: -38, width: 34, height: 38), className: "NSStatusBarWindow")
        let windows = [popup, hiddenReplica, externalButton, builtInButton]
        XCTAssertEqual(
            OwnMenuBarButton.frame(among: windows, on: [builtIn, external], near: CGPoint(x: 800, y: 400)),
            builtInButton.frame
        )
        XCTAssertEqual(
            OwnMenuBarButton.frame(among: windows, on: [builtIn, external], near: CGPoint(x: 2000, y: 400)),
            externalButton.frame
        )
    }

    func testIgnoresWindowsThatAreNotMenuBarButtons() {
        let windows = [
            MenuBarWindowRecord(frame: CGRect(x: 1383, y: 1074, width: 400, height: 38), className: "NSStatusBarWindow"),
            MenuBarWindowRecord(frame: CGRect(x: 1383, y: 500, width: 34, height: 38), className: "NSStatusBarWindow"),
            MenuBarWindowRecord(frame: CGRect(x: 1383, y: 1074, width: 34, height: 38), className: "NSWindow")
        ]
        XCTAssertNil(OwnMenuBarButton.frame(among: windows, on: [builtIn], near: CGPoint(x: 800, y: 400)))
    }
}

@MainActor
final class HUDMenuAnchorReceiverTests: XCTestCase {
    private let center = DistributedNotificationCenter.default()
    private let processID = ProcessInfo.processInfo.processIdentifier
    private let ownAnchor = HUDSystemMenuAnchor(
        identifier: "micfirst-status-item",
        buttonFrame: CGRect(x: 1200, y: 1082, width: 34, height: 22),
        screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112)
    )

    private func send(_ anchors: [HUDSystemMenuAnchor], id: UUID) throws {
        let json = String(decoding: try JSONEncoder().encode(HUDMenuAnchorSnapshot(deliveryID: id, anchors: anchors)), as: UTF8.self)
        center.postNotificationName(Notification.Name("MicFirst.MenuAnchorSnapshot.\(processID)"),
                                    object: json, userInfo: nil, deliverImmediately: true)
    }

    private func sendAndAwaitAcknowledgement(_ anchors: [HUDSystemMenuAnchor], id: UUID) async throws {
        let acknowledgement = expectation(description: "Snapshot is accepted")
        let observer = center.addObserver(
            forName: Notification.Name("MicFirst.MenuAnchorSnapshotAccepted.\(processID)"),
            object: id.uuidString, queue: .main
        ) { _ in acknowledgement.fulfill() }
        defer { center.removeObserver(observer) }
        try send(anchors, id: id)
        await fulfillment(of: [acknowledgement], timeout: 2)
    }

    private func finish(_ id: UUID) {
        center.postNotificationName(Notification.Name("MicFirst.MenuAnchorSnapshotFinished.\(processID)"),
                                    object: id.uuidString, userInfo: nil, deliverImmediately: true)
    }

    func testIncompleteSnapshotsLeaveReceiverAvailableForValidRetry() async throws {
        var applied: [[HUDSystemMenuAnchor]] = []
        let receiver = HUDMenuAnchorReceiver { applied.append($0); return true }
        receiver.start()
        defer { receiver.stop() }
        let id = UUID()
        let systemOnly = HUDSystemMenuAnchor(identifier: "com.apple.menuextra.sound",
                                             buttonFrame: ownAnchor.buttonFrame, screenFrame: ownAnchor.screenFrame)
        let invalidOwn = HUDSystemMenuAnchor(identifier: "micfirst-status-item", buttonFrame: .zero, screenFrame: ownAnchor.screenFrame)
        center.postNotificationName(Notification.Name("MicFirst.MenuAnchorSnapshot.\(processID)"),
                                    object: "malformed", userInfo: nil, deliverImmediately: true)
        try send([], id: id)
        try send([systemOnly], id: id)
        try send([invalidOwn], id: id)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(applied.isEmpty)
        XCTAssertTrue(receiver.isListening)
        try await sendAndAwaitAcknowledgement([ownAnchor, systemOnly], id: id)
        XCTAssertEqual(applied, [[ownAnchor, systemOnly]])
    }

    func testUnusableDisplayGeometryCanBeRetriedUntilAccepted() async throws {
        var ready = false
        var applications = 0
        let rejected = expectation(description: "The controller rejects a transient anchor")
        let receiver = HUDMenuAnchorReceiver { _ in
            guard ready else { rejected.fulfill(); return false }
            applications += 1
            return true
        }
        receiver.start()
        defer { receiver.stop() }
        let id = UUID()
        try send([ownAnchor], id: id)
        await fulfillment(of: [rejected], timeout: 2)
        ready = true
        try await sendAndAwaitAcknowledgement([ownAnchor], id: id)
        XCTAssertEqual(applications, 1)
    }

    func testLostAcknowledgementCanBeRetriedWithoutReplacingSnapshot() async throws {
        var applications = 0
        let receiver = HUDMenuAnchorReceiver { _ in applications += 1; return true }
        receiver.start()
        defer { receiver.stop() }
        let id = UUID()
        try await sendAndAwaitAcknowledgement([ownAnchor], id: id)
        // The sender retries if its first acknowledgement did not arrive.
        try await sendAndAwaitAcknowledgement([ownAnchor], id: id)
        XCTAssertEqual(applications, 1)
        let unrelatedID = UUID()
        try send([ownAnchor], id: unrelatedID)
        finish(unrelatedID)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(applications, 1)
        XCTAssertTrue(receiver.isListening)
        finish(id)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(receiver.isListening)
    }

    func testAbandonedHandshakeExpiresWithoutKeepingObservers() async throws {
        let receiver = HUDMenuAnchorReceiver { _ in XCTFail("Expired receiver must not apply snapshots"); return true }
        receiver.start(timeout: 0.05)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(receiver.isListening)
        try send([ownAnchor], id: UUID())
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}
