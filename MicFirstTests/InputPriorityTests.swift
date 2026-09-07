import CoreAudio
import XCTest

@MainActor
final class InputPriorityTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suite = "MicFirstTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testFreshInstallKeepsCurrentFirstAndAppendsNewDevices() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1), device(2, current: true)])
        store.observe([device(3), device(1), device(2, current: true)])
        XCTAssertEqual(store.devices.map(\.uid), ["2", "1", "3"])
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.preferredDevice(in: [device(1), device(2), device(3)])?.uid, "2")
    }

    func testOfflineOrderAndMetadataSurviveRestart() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1, current: true), device(2), device(3)])
        store.observe([device(2), device(3)])
        store.move(fromOffsets: [0], toOffset: 3)
        let restored = InputPriorityStore(defaults: defaults)
        XCTAssertEqual(restored.devices.map(\.uid), ["2", "3", "1"])
        XCTAssertFalse(restored.rows(for: [device(2), device(3)])[2].isOnline)
        XCTAssertEqual(restored.devices[2].name, "Device 1")
    }

    func testLegacyLockMigratesEvenWhenOffline() {
        defaults.set("usb", forKey: "preferredInputDeviceUID")
        defaults.set("DJI Mic Mini", forKey: "preferredInputDeviceName")
        defaults.set(true, forKey: "inputLockEnabled")
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(2, current: true)])
        XCTAssertEqual(store.devices.map(\.uid), ["usb", "2"])
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.preferredDevice(in: [device(2)])?.uid, "2")
        store.removeOfflineDevice(uid: "usb", onlineDevices: [device(2)])
        XCTAssertEqual(InputPriorityStore(defaults: defaults).devices.map(\.uid), ["2"])
    }

    func testLegacyDisabledOrUnlockedIntentStaysManual() {
        defaults.set("1", forKey: "preferredInputDeviceUID")
        defaults.set(false, forKey: "inputLockEnabled")
        XCTAssertFalse(InputPriorityStore(defaults: defaults).isEnabled)
        defaults.removeObject(forKey: "preferredInputDeviceUID")
        defaults.set(true, forKey: "inputLockEnabled")
        XCTAssertFalse(InputPriorityStore(defaults: defaults).isEnabled)
    }

    func testRemovedDeviceReturnsAtBottomAndOnlineDeviceCannotBeRemoved() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1, current: true), device(2)])
        store.removeOfflineDevice(uid: "2", onlineDevices: [device(2)])
        XCTAssertEqual(store.devices.count, 2)
        store.removeOfflineDevice(uid: "1", onlineDevices: [device(2)])
        store.observe([device(1), device(2)])
        XCTAssertEqual(store.devices.map(\.uid), ["2", "1"])
    }

    func testSameNamedUSBAndBluetoothRemainDistinct() {
        let store = InputPriorityStore(defaults: defaults)
        let usb = device(1, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeUSB)
        let bluetooth = device(2, name: "DJI Mic Mini", transport: kAudioDeviceTransportTypeBluetooth)
        store.observe([usb, bluetooth])
        let rows = store.rows(for: [bluetooth])
        XCTAssertEqual(rows.map(\.name), ["DJI Mic Mini · USB", "DJI Mic Mini · Bluetooth"])
        XCTAssertEqual(rows.map(\.isOnline), [false, true])
    }

    func testReconnectionUsesUIDDespiteDeviceIDAndNameChanges() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1), device(2)])
        let renamed = device(99, uid: "1", name: "Renamed microphone")
        store.observe([device(2), renamed])
        XCTAssertEqual(store.devices.map(\.uid), ["1", "2"])
        XCTAssertEqual(store.devices[0].name, "Renamed microphone")
        XCTAssertEqual(store.preferredDevice(in: [renamed, device(2)])?.id, 99)
    }

    func testExternalTakeoverRestoresOnceAndConfirmsHUD() async {
        let (model, audio, hud) = makeModel()
        audio.currentID = 2
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertEqual(audio.writes, [1])
        XCTAssertEqual(hud.shownNames, ["Device 1"])
        await audio.emitChange()
        XCTAssertEqual(audio.writes, [1])
        XCTAssertTrue(model.automaticInputIsEnabled)
    }

    func testFallbackAndReconnectChooseHighestAvailable() async {
        let (model, audio, _) = makeModel()
        audio.available = [device(2), device(3)]
        audio.currentID = 3
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 2)
        XCTAssertEqual(model.priorityRows.map(\.isOnline), [false, true, true])
        audio.available = [device(1), device(2), device(3)]
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 1)
    }

    func testAllOfflineKeepsModeAndRecoversWithoutDefaultRoute() async {
        let (model, audio, _) = makeModel()
        audio.available = []
        audio.currentID = nil
        await audio.emitChange()
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertEqual(model.priorityRows.count, 3)
        audio.available = [device(3)]
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 3)
    }

    func testManualSelectionStaysOffPastOldCountdownAndKeepsOrder() async throws {
        let (model, audio, _) = makeModel()
        model.selectDevice(uid: "3")
        XCTAssertFalse(model.automaticInputIsEnabled)
        XCTAssertEqual(audio.currentID, 3)
        try await Task.sleep(nanoseconds: 5_200_000_000)
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 3)
        XCTAssertFalse(InputPriorityStore(defaults: defaults).isEnabled)
        XCTAssertEqual(model.priorityRows.map(\.id), ["1", "2", "3"])
        model.setAutomaticInputEnabled(true)
        XCTAssertEqual(audio.currentID, 1)
    }

    func testClickCurrentOrOfflineDoesNotDisableAutomaticMode() async {
        let (model, audio, _) = makeModel()
        model.selectDevice(uid: "1")
        audio.available = [device(1), device(3)]
        await audio.emitChange()
        model.selectDevice(uid: "2")
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertTrue(audio.writes.isEmpty)
    }

    func testReorderingOfflineDeviceDoesNotSelectItUntilItReturns() async {
        let (model, audio, _) = makeModel()
        audio.available = [device(1), device(3)]
        await audio.emitChange()
        model.moveDevices(fromOffsets: [1], toOffset: 0)
        XCTAssertEqual(model.priorityRows.map(\.id), ["2", "1", "3"])
        XCTAssertEqual(audio.currentID, 1)
        audio.available = [device(1), device(2), device(3)]
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 2)
    }

    func testReorderingWhileManualPreservesInputUntilEnabled() {
        let (model, audio, _) = makeModel()
        model.setAutomaticInputEnabled(false)
        model.moveDevices(fromOffsets: [2], toOffset: 0)
        XCTAssertEqual(audio.currentID, 1)
        model.setAutomaticInputEnabled(true)
        XCTAssertEqual(audio.currentID, 3)
    }

    func testHUDChangesGlobalModeWithoutChangingPriority() async {
        let (model, audio, hud) = makeModel()
        audio.currentID = 2
        await audio.emitChange()
        hud.disable?()
        XCTAssertFalse(model.automaticInputIsEnabled)
        audio.currentID = 3
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 3)
        hud.enable?()
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertEqual(model.priorityRows.map(\.id), ["1", "2", "3"])
    }

    func testHotPlugIsNotIgnoredWhileAdjustingVolume() async {
        let (model, audio, _) = makeModel()
        audio.available = [device(2), device(3)]
        audio.currentID = 2
        await audio.emitChange()
        model.setCurrentVolume(0.7)
        audio.available = [device(1), device(2), device(3)]
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 1)
    }

    func testFailedManualSwitchRestoresModeAndReportsError() {
        let (model, audio, _) = makeModel()
        audio.rejectWrites = true
        model.selectDevice(uid: "2")
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertNotNil(model.errorMessage)
    }

    func testEnumerationFailureDoesNotDeleteHistoryOrAllowRemoval() {
        let (model, audio, _) = makeModel()
        audio.failEnumeration = true
        model.removeOfflineDevice(uid: "1")
        XCTAssertEqual(model.priorityRows.count, 3)
        XCTAssertNotNil(model.errorMessage)
    }

    func testReconnectWhileSettingsOpenPreventsDeletion() async {
        let (model, audio, _) = makeModel()
        audio.available = [device(1), device(3)]
        await audio.emitChange()
        XCTAssertFalse(model.priorityRows[1].isOnline)
        audio.available = [device(1), device(2), device(3)]
        model.removeOfflineDevice(uid: "2")
        XCTAssertEqual(model.priorityRows.count, 3)
        XCTAssertTrue(model.priorityRows[1].isOnline)
    }

    func testDelayedRouteIsRetriedAndHUDWaitsForConfirmation() async throws {
        let (model, audio, hud) = makeModel()
        audio.ignoredWrites = 1
        audio.currentID = 2
        await audio.emitChange()
        XCTAssertTrue(hud.shownNames.isEmpty)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertEqual(hud.shownNames, ["Device 1"])
        XCTAssertNil(model.errorMessage)
    }

    func testDisablingCancelsPendingRestoration() async throws {
        let (model, audio, hud) = makeModel()
        audio.ignoredWrites = 10
        audio.currentID = 2
        await audio.emitChange()
        model.setAutomaticInputEnabled(false)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(audio.writes.count, 1)
        XCTAssertTrue(hud.shownNames.isEmpty)
        XCTAssertEqual(audio.currentID, 2)
    }

    func testManualSelectionWhileFirstOfflineStaysOffOnReconnect() async {
        let (model, audio, _) = makeModel()
        audio.available = [device(2), device(3)]
        audio.currentID = 2
        await audio.emitChange()
        model.selectDevice(uid: "3")
        audio.available = [device(1), device(2), device(3)]
        await audio.emitChange()
        XCTAssertFalse(model.automaticInputIsEnabled)
        XCTAssertEqual(audio.currentID, 3)
        model.setAutomaticInputEnabled(true)
        XCTAssertEqual(audio.currentID, 1)
    }

    func testRetryChangesTargetWhenHigherDeviceDisconnects() async throws {
        let (model, audio, hud) = makeModel()
        audio.ignoredWrites = 1
        audio.currentID = 3
        await audio.emitChange()
        audio.available = [device(2), device(3)]
        await audio.emitChange()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(audio.writes, [1, 2])
        XCTAssertEqual(audio.currentID, 2)
        XCTAssertEqual(hud.shownNames, ["Device 2"])
        XCTAssertTrue(model.automaticInputIsEnabled)
    }

    func testFailedRestorationIsBoundedAndNeverShowsSuccessHUD() async throws {
        let (model, audio, hud) = makeModel()
        audio.rejectWrites = true
        audio.currentID = 2
        await audio.emitChange()
        try await Task.sleep(nanoseconds: 1_850_000_000)
        XCTAssertEqual(audio.writes.count, 4)
        XCTAssertEqual(audio.currentID, 2)
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(hud.shownNames.isEmpty)
    }

    func testOriginalPriorityPreferencesMigrateWithoutLosingOrderOrMode() throws {
        let oldPreferences = #"{"isEnabled":false,"devices":[{"uid":"2","name":"Old mic","iconSystemName":"mic","transportType":0},{"uid":"1","name":"Built-in","iconSystemName":"mic","transportType":0}]}"#
        defaults.set(Data(oldPreferences.utf8), forKey: InputPriorityStore.preferencesKey)
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1, current: true)])
        XCTAssertFalse(store.isEnabled)
        XCTAssertEqual(store.devices.map(\.uid), ["2", "1"])
        XCTAssertEqual(store.rows(for: [device(1)]).map(\.isShownInMenu), [false, true])
        XCTAssertFalse(store.devices[0].isHiddenFromMenu)
    }

    func testOfflineDeviceDisappearsAtFiveMinutesAndRemainsInSettings() {
        var date = Date(timeIntervalSince1970: 1_000)
        let store = InputPriorityStore(defaults: defaults, now: { date })
        store.observe([device(1), device(2)])
        store.observe([device(2)])
        date = date.addingTimeInterval(299)
        store.observe([device(2)]) // Repeated observations must not extend the deadline.
        XCTAssertTrue(store.rows(for: [device(2)])[0].isShownInMenu)
        date = date.addingTimeInterval(1)
        XCTAssertFalse(store.rows(for: [device(2)])[0].isShownInMenu)
        XCTAssertEqual(store.devices.map(\.uid), ["1", "2"])
        XCTAssertFalse(store.devices[0].isHiddenFromMenu)
        XCTAssertNil(store.nextMenuVisibilityRefreshDelay)
    }

    func testOfflineDeadlineSurvivesRestartAndReconnectRestoresPriority() {
        var date = Date(timeIntervalSince1970: 1_000)
        let store = InputPriorityStore(defaults: defaults, now: { date })
        store.observe([device(1), device(2)])
        store.observe([device(2)])
        date = date.addingTimeInterval(301)
        let restarted = InputPriorityStore(defaults: defaults, now: { date })
        restarted.observe([device(2)])
        XCTAssertFalse(restarted.rows(for: [device(2)])[0].isShownInMenu)
        restarted.observe([device(1), device(2)])
        XCTAssertTrue(restarted.rows(for: [device(1), device(2)])[0].isShownInMenu)
        XCTAssertEqual(restarted.preferredDevice(in: [device(1), device(2)])?.uid, "1")
        restarted.observe([device(2)])
        XCTAssertEqual(restarted.nextMenuVisibilityRefreshDelay, 300)
    }

    func testManualHidingSurvivesMetadataChangesAndReconnect() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1), device(2)])
        store.setHiddenFromMenu(true, uid: "1")
        store.observe([device(2)])
        let restarted = InputPriorityStore(defaults: defaults)
        let renamed = device(99, uid: "1", name: "New name")
        restarted.observe([renamed, device(2)])
        XCTAssertEqual(restarted.devices[0].name, "New name")
        XCTAssertTrue(restarted.devices[0].isHiddenFromMenu)
        XCTAssertFalse(restarted.rows(for: [renamed, device(2)])[0].isShownInMenu)
        XCTAssertEqual(restarted.preferredDevice(in: [renamed, device(2)])?.uid, "2")
        restarted.setHiddenFromMenu(false, uid: "1")
        XCTAssertEqual(restarted.preferredDevice(in: [renamed, device(2)])?.uid, "1")
    }

    func testMenuReorderPreservesHiddenSlotsAndUsesVisibleUIDs() {
        let store = InputPriorityStore(defaults: defaults)
        store.observe([device(1), device(2), device(3), device(4)])
        store.setHiddenFromMenu(true, uid: "2")
        store.move(uid: "4", beforeUID: "1", within: ["1", "3", "4"])
        XCTAssertEqual(store.devices.map(\.uid), ["4", "2", "1", "3"])
        store.move(uid: "4", beforeUID: nil, within: ["4", "1", "3"])
        XCTAssertEqual(store.devices.map(\.uid), ["1", "2", "3", "4"])
        store.move(uid: "1", beforeUID: nil, within: ["4", "1", "3"]) // Stale projection.
        XCTAssertEqual(store.devices.map(\.uid), ["1", "2", "3", "4"])
        store.move(uid: "1", beforeUID: "2", within: ["1", "3", "4"]) // Hidden anchor.
        XCTAssertEqual(store.devices.map(\.uid), ["1", "2", "3", "4"])
    }

    func testHidingCurrentInputFallsBackAndStillDefendsAgainstTakeover() async {
        let (model, audio, _) = makeModel()
        model.setDeviceShownInMenu(false, uid: "1")
        XCTAssertEqual(audio.currentID, 2)
        XCTAssertEqual(model.menuRows.map(\.id), ["2", "3"])
        XCTAssertEqual(model.priorityRows.map(\.priority), [1, 2, 3])
        audio.currentID = 1
        await audio.emitChange()
        XCTAssertEqual(audio.currentID, 2)
        model.setDeviceShownInMenu(true, uid: "1")
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertTrue(model.automaticInputIsEnabled)
    }

    func testHidingWhileManualDoesNotSwitchInput() {
        let (model, audio, _) = makeModel()
        model.setAutomaticInputEnabled(false)
        model.setDeviceShownInMenu(false, uid: "1")
        XCTAssertEqual(audio.currentID, 1)
        XCTAssertTrue(audio.writes.isEmpty)
        model.setAutomaticInputEnabled(true)
        XCTAssertEqual(audio.currentID, 2)
    }

    func testAllHiddenKeepsAutomaticModeAndRecoversWhenShown() {
        let (model, audio, _) = makeModel()
        for uid in ["1", "2", "3"] { model.setDeviceShownInMenu(false, uid: uid) }
        XCTAssertTrue(model.automaticInputIsEnabled)
        XCTAssertTrue(model.menuRows.isEmpty)
        XCTAssertEqual(model.priorityRows.count, 3)
        XCTAssertEqual(audio.currentID, 3)
        model.setDeviceShownInMenu(true, uid: "1")
        XCTAssertEqual(audio.currentID, 1)
    }

    func testMenuExpiryRefreshesWithoutAnotherAudioEvent() async throws {
        let audio = FakeAudioManager()
        let store = InputPriorityStore(defaults: defaults, offlineMenuGracePeriod: 0.06)
        let model = AudioInputViewModel(audioManager: audio, preferences: store, hud: FakeHUD())
        audio.available = [device(2), device(3)]
        await audio.emitChange()
        XCTAssertEqual(model.menuRows.map(\.id), ["1", "2", "3"])
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(model.menuRows.map(\.id), ["2", "3"])
        XCTAssertEqual(model.priorityRows.count, 3)
        audio.available = [device(1), device(2), device(3)]
        await audio.emitChange()
        XCTAssertEqual(model.menuRows.map(\.id), ["1", "2", "3"])
        XCTAssertEqual(audio.currentID, 1)
    }

    private func makeModel() -> (AudioInputViewModel, FakeAudioManager, FakeHUD) {
        let audio = FakeAudioManager()
        let hud = FakeHUD()
        let model = AudioInputViewModel(
            audioManager: audio, preferences: InputPriorityStore(defaults: defaults), hud: hud)
        return (model, audio, hud)
    }
}

private func device(
    _ id: AudioDeviceID, uid: String? = nil, name: String? = nil,
    transport: UInt32 = kAudioDeviceTransportTypeUSB, current: Bool = false
) -> InputDevice {
    InputDevice(
        id: id, uid: uid ?? String(id), name: name ?? "Device \(id)", manufacturer: "",
        modelUID: "", transportType: transport, inputChannels: 1, isDefault: current,
        supportsInputVolume: true, inputVolume: 0.5)
}

private final class FakeAudioManager: InputAudioManaging {
    var available = [device(1), device(2), device(3)]
    var currentID: AudioDeviceID? = 1
    var writes: [AudioDeviceID] = []
    var rejectWrites = false
    var failEnumeration = false
    var ignoredWrites = 0
    var changeHandler: (() -> Void)?

    func loadInputDevices() throws -> [InputDevice] {
        if failEnumeration { throw CoreAudioInputError.unavailable("Enumeration failed") }
        return available.map {
            device($0.id, uid: $0.uid, name: $0.name, transport: $0.transportType, current: $0.id == currentID)
        }
    }
    func defaultInputDeviceID() throws -> AudioDeviceID { currentID ?? 0 }
    func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        writes.append(deviceID)
        if rejectWrites { throw CoreAudioInputError.unavailable("Switch failed") }
        if ignoredWrites > 0 {
            ignoredWrites -= 1
            return
        }
        currentID = deviceID
    }
    func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) throws {}
    func startMonitoring(_ onChange: @escaping () -> Void) { changeHandler = onChange }
    func stopMonitoring() { changeHandler = nil }
    func monitorVolume(for deviceID: AudioDeviceID?) {}
    @MainActor func emitChange() async {
        changeHandler?()
        // Drain the callback's main-actor task without depending on real audio hardware.
        await Task.yield()
        await Task.yield()
    }
}

@MainActor
private final class FakeHUD: InputPriorityHUDPresenting {
    var shownNames: [String] = []
    var disable: (() -> Void)?
    var enable: (() -> Void)?
    func show(
        deviceName: String, detail: String, stackBelowNativeHUD: Bool, unlock: @escaping () -> Void,
        lock: @escaping () -> Void
    ) {
        shownNames.append(deviceName)
        disable = unlock
        enable = lock
    }
    func dismissForMenuOpening() {}
}
