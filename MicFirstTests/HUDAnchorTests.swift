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
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let owners: [pid_t: String] = [42: "com.apple.controlcenter", 43: "com.apple.MenuBarAgent"]

    private func window(pid: Int = 42, owner: String = "Control Center", level: Int = 2000,
                        frame: CGRect = CGRect(x: 1000, y: 5, width: 360, height: 136), title: String? = "") -> [String: Any] {
        var result: [String: Any] = [
            kCGWindowNumber as String: 1, kCGWindowOwnerPID as String: pid, kCGWindowOwnerName as String: owner,
            kCGWindowBounds as String: ["X": frame.minX, "Y": frame.minY, "Width": frame.width, "Height": frame.height],
            kCGWindowLayer as String: level, kCGWindowAlpha as String: 1, kCGWindowIsOnscreen as String: true
        ]
        if let title { result[kCGWindowName as String] = title }
        return result
    }

    private func inspect(_ windows: [[String: Any]]?) -> NativeHUDProbeResult {
        NativeHUDProbe.inspect(windowInfos: windows, ownerBundlesByPID: owners, primaryScreenMaxY: 1112, targetScreen: screen)
    }

    func testUnavailableEnumerationIsUnknown() {
        XCTAssertEqual(inspect(nil).presence, .unknown)
        XCTAssertEqual(inspect(nil).reason, "window-enumeration-unavailable")
    }

    func testNoCandidateIsNotReportedAsAbsence() {
        XCTAssertEqual(inspect([]).presence, .unknown)
        XCTAssertEqual(inspect([]).reason, "no-legacy-match-not-proof-of-absence")
    }

    func testLegacyMatchRemainsUnverifiedAndMarksCapsuleAsAssumed() throws {
        let result = inspect([window()])
        XCTAssertEqual(result.presence, .unknown)
        let sample = try XCTUnwrap(result.windows.first)
        XCTAssertTrue(sample.matchesLegacyFilter)
        XCTAssertEqual(sample.appKitFrame, CGRect(x: 1000, y: 971, width: 360, height: 136))
        XCTAssertEqual(sample.legacyAssumedCapsuleFrame, CGRect(x: 1062.5, y: 1013, width: 235, height: 52))
    }

    func testMenuPopoverIsNotPromotedToNativeHUD() {
        let result = inspect([window(pid: 43, owner: "MenuBarAgent", level: 101, frame: CGRect(x: 1260, y: 38, width: 352, height: 157))])
        XCTAssertEqual(result.presence, .unknown)
        XCTAssertEqual(result.windows.count, 1)
        XCTAssertFalse(result.windows[0].matchesLegacyFilter)
        XCTAssertNil(result.windows[0].legacyAssumedCapsuleFrame)
    }

    func testWindowTitlesAreNotStoredInDiagnosticOutput() throws {
        let result = inspect([window(title: "Private device or window title")])
        let data = try JSONEncoder().encode(result)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private device or window title"))
        XCTAssertEqual(result.windows.first?.titleAvailability, "nonempty")
    }

    func testCandidateOnAnotherDisplayDoesNotMatchCurrentHUDScreen() {
        let result = inspect([window(frame: CGRect(x: -1000, y: 5, width: 360, height: 136))])
        XCTAssertEqual(result.presence, .unknown)
        XCTAssertEqual(result.windows.first?.isOnTargetScreen, false)
        XCTAssertEqual(result.windows.first?.matchesLegacyFilter, false)
    }
}

final class HUDHorizontalPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let size = CGSize(width: 235, height: 52)
    private func system(_ center: CGFloat, id: String = "com.apple.menuextra.sound", screen: CGRect? = nil) -> HUDSystemMenuAnchor {
        let display = screen ?? self.screen
        return HUDSystemMenuAnchor(identifier: id,
            buttonFrame: CGRect(x: center - 11, y: display.maxY - 30, width: 22, height: 22), screenFrame: display)
    }
    private func own(_ center: CGFloat) -> CGRect { CGRect(x: center - 180, y: 971, width: 360, height: 136) }
    private func place(_ center: CGFloat, _ native: HUDSystemMenuAnchor?) -> CGRect? {
        HUDPlacement().frame(anchoredAt: own(center), capsuleSize: size, on: screen, nativeAnchor: native)
    }
    func testDistantIconsKeepOwnPosition() {
        XCTAssertEqual(place(400, system(1436)), own(400))
    }
    func testOverlapNearRightEdgeMovesLeftWithSameY() throws {
        let frame = try XCTUnwrap(place(1400, system(1562)))
        XCTAssertEqual(frame.minX + 62.5 + 235, 1562 - 117.5 - 12)
        XCTAssertEqual(frame.minY, own(1400).minY)
    }
    func testOverlapUsesRightWhenWholeCapsuleFits() throws {
        let frame = try XCTUnwrap(place(950, system(1000)))
        XCTAssertEqual(frame.minX + 62.5, 1000 + 117.5 + 12)
        XCTAssertEqual(frame.minY, own(950).minY)
    }
    func testSoundPreferredAndControlCenterFallback() {
        let cc = system(1562, id: "com.apple.menuextra.controlcenter")
        let sound = system(1436)
        XCTAssertEqual(HUDSystemMenuAnchor.preferred(in: [cc, sound], on: screen), sound)
        XCTAssertEqual(HUDSystemMenuAnchor.preferred(in: [cc], on: screen), cc)
    }
    func testOtherDisplayAndInvalidGeometryIgnored() {
        let other = system(-400, screen: screen.offsetBy(dx: -1710, dy: 0))
        XCTAssertNil(HUDSystemMenuAnchor.preferred(in: [other], on: screen))
        let invalid = HUDSystemMenuAnchor(identifier: "com.apple.menuextra.sound", buttonFrame: .zero, screenFrame: screen)
        XCTAssertNil(HUDSystemMenuAnchor.preferred(in: [invalid], on: screen))
        XCTAssertEqual(place(400, nil), own(400))
    }
    func testNativeCapsuleClampsBeforeAvoidance() throws {
        let frame = try XCTUnwrap(place(1600, system(1690)))
        XCTAssertEqual(frame.minX + 62.5 + 235, 1710 - 6 - 235 - 12)
    }
    func testNoRoomOnEitherSideSkipsWithoutLowerRow() {
        let tiny = CGRect(x: 0, y: 0, width: 450, height: 1112)
        XCTAssertNil(HUDPlacement().frame(anchoredAt: own(225), capsuleSize: size, on: tiny,
            nativeAnchor: system(225, screen: tiny)))
    }
    func testExactGapDoesNotMoveHUD() {
        let center: CGFloat = 1000 - 235 - 12
        XCTAssertEqual(place(center, system(1000)), own(center))
    }
}
