import XCTest
@testable import Time_Boxed

final class TimeBoxedTests: XCTestCase {
    func testLegacyDayDecodesWithoutInterval() throws {
        let json = #"{"priorities":["Ship it"],"brainDump":"","blocks":[{"id":"00000000-0000-0000-0000-000000000001","startMinute":750,"durationMinutes":30,"text":"Lunch"}]}"#
        let sheet = try JSONDecoder().decode(DaySheet.self, from: Data(json.utf8))

        XCTAssertNil(sheet.intervalMinutes)
        XCTAssertEqual(sheet.blocks.first?.startMinute, 750)
        XCTAssertEqual(sheet.blocks.first?.durationMinutes, 30)
    }

    @MainActor
    func testFilledDayKeepsItsIntervalAndBlocksWhenDefaultChanges() async throws {
        let fixture = try makeFixture(interval: 30)
        await fixture.store.waitForPendingOperations()
        let firstID = UUID()
        let secondID = UUID()
        fixture.store.sheet = DaySheet(
            blocks: [
                TimeBlock(id: firstID, startMinute: 12 * 60, durationMinutes: 30, text: "First"),
                TimeBlock(id: secondID, startMinute: 12 * 60 + 30, durationMinutes: 30, text: "Second")
            ],
            intervalMinutes: 30
        )
        let originalBlocks = fixture.store.sheet.blocks

        fixture.settings.setIntervalMinutes(60)
        let adopted = fixture.store.adoptDefaultIntervalIfEmpty(60)

        XCTAssertFalse(adopted)
        XCTAssertEqual(fixture.store.effectiveIntervalMinutes, 30)
        XCTAssertEqual(fixture.store.sheet.blocks, originalBlocks)
    }

    @MainActor
    func testEmptyDayAdoptsNewDefaultInterval() async throws {
        let fixture = try makeFixture(interval: 30)
        await fixture.store.waitForPendingOperations()

        fixture.settings.setIntervalMinutes(60)
        XCTAssertTrue(fixture.store.adoptDefaultIntervalIfEmpty(60))
        XCTAssertEqual(fixture.store.effectiveIntervalMinutes, 60)
        XCTAssertTrue(fixture.store.sheet.blocks.isEmpty)
    }

    @MainActor
    func testMergeAndUnmergeRoundTrip() async throws {
        let fixture = try makeFixture(interval: 30)
        await fixture.store.waitForPendingOperations()
        let first = TimeBlock(startMinute: 9 * 60, durationMinutes: 30, text: "Focus")
        let second = TimeBlock(startMinute: 9 * 60 + 30, durationMinutes: 30, text: "Focus")
        fixture.store.sheet = DaySheet(blocks: [first, second], intervalMinutes: 30)

        XCTAssertTrue(fixture.store.canMergeWithPrevious(blockID: second.id, intervalMinutes: 30))
        fixture.store.mergeWithPrevious(blockID: second.id, intervalMinutes: 30)
        XCTAssertEqual(fixture.store.sheet.blocks, [TimeBlock(id: first.id, startMinute: 9 * 60, durationMinutes: 60, text: "Focus")])

        fixture.store.unmerge(blockID: first.id, intervalMinutes: 30)
        XCTAssertEqual(fixture.store.sheet.blocks.map(\.startMinute), [9 * 60, 9 * 60 + 30])
        XCTAssertEqual(fixture.store.sheet.blocks.map(\.durationMinutes), [30, 30])
    }

    func testPersistenceSavesLoadsAndRemovesDay() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeBoxedPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        let persistence = DayPersistence(storageDirectory: directory)
        let key = "2026-08-15"
        let sheet = DaySheet(
            priorities: ["Important"],
            blocks: [TimeBlock(startMinute: 600, durationMinutes: 60, text: "Deep work")],
            intervalMinutes: 60
        )

        let initialKeys = try await persistence.prepare()
        XCTAssertEqual(initialKeys, Set<String>())
        let saveResult = try await persistence.saveDay(sheet, key: key)
        guard case .saved = saveResult else { return XCTFail("Expected the day to be saved") }
        let loadedSheet = try await persistence.loadDay(key: key)
        XCTAssertEqual(loadedSheet, sheet)
        let savedKeys = try await persistence.prepare()
        XCTAssertEqual(savedKeys, Set([key]))

        let removalResult = try await persistence.saveDay(DaySheet(intervalMinutes: 60), key: key)
        guard case .removed = removalResult else { return XCTFail("Expected the empty day to be removed") }
        let removedSheet = try await persistence.loadDay(key: key)
        XCTAssertNil(removedSheet)
    }

    @MainActor
    func testSettingsNormalizeAndPersistSchedule() {
        let suiteName = "TimeBoxedSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(5 * 60 + 17, forKey: "planner.startMinute")
        defaults.set(22 * 60 + 7, forKey: "planner.endMinute")
        defaults.set(60, forKey: "planner.intervalMinutes")

        let settings = PlannerSettings(defaults: defaults)

        XCTAssertEqual(settings.startMinute, 5 * 60)
        XCTAssertEqual(settings.endMinute, 23 * 60)
        XCTAssertEqual(settings.slotStarts.first, 5 * 60)
        XCTAssertEqual(settings.slotStarts.last, 22 * 60)
    }

    @MainActor
    private func makeFixture(interval: Int) throws -> (settings: PlannerSettings, store: DayStore) {
        let suiteName = "TimeBoxedStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(interval, forKey: "planner.intervalMinutes")
        let settings = PlannerSettings(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeBoxedStoreTests-\(UUID().uuidString)", isDirectory: true)
        return (settings, DayStore(settings: settings, storageDirectory: directory))
    }
}
