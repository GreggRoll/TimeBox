import Foundation
import Observation
import SwiftUI

enum DayPersistenceSaveResult: Sendable {
    case saved
    case removed
}

actor DayPersistence {
    private let storageDirectory: URL
    private let fileManager: FileManager

    init(storageDirectory: URL, fileManager: FileManager = .default) {
        self.storageDirectory = storageDirectory
        self.fileManager = fileManager
    }

    func prepare() throws -> Set<String> {
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        let urls = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return Set(
            urls
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
    }

    func loadDay(key: String) throws -> DaySheet? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(DaySheet.self, from: Data(contentsOf: url))
    }

    func saveDay(_ sheet: DaySheet, key: String) throws -> DayPersistenceSaveResult {
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        let url = fileURL(for: key)
        let normalized = sheet.normalizedForPersistence()

        if normalized.hasMeaningfulData {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(normalized).write(to: url, options: [.atomic])
            return .saved
        }

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        return .removed
    }

    private func fileURL(for key: String) -> URL {
        storageDirectory.appendingPathComponent("\(key).json", isDirectory: false)
    }
}

@MainActor
@Observable
final class DayStore {
    private(set) var selectedDate: Date
    var sheet: DaySheet
    private(set) var savedDayKeys: Set<String> = []
    private(set) var isLoading = true
    var persistenceError: String?

    var effectiveIntervalMinutes: Int {
        sheet.intervalMinutes == 60 ? 60 : 30
    }

    @ObservationIgnored private let settings: PlannerSettings
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let persistence: DayPersistence
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var selectionTask: Task<Void, Never>?
    @ObservationIgnored private var initializationTask: Task<Void, Never>?
    @ObservationIgnored private var sheetDate: Date

    init(settings: PlannerSettings, storageDirectory: URL? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.settings = settings
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        sheetDate = today
        sheet = DaySheet(
            priorities: Array(repeating: "", count: settings.priorityCount),
            intervalMinutes: settings.intervalMinutes
        )

        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = storageDirectory
            ?? applicationSupport
                .appendingPathComponent("TimeBoxed", isDirectory: true)
                .appendingPathComponent("Days", isDirectory: true)
        persistence = DayPersistence(storageDirectory: directory)

        let initialDate = selectedDate
        initializationTask = Task { [weak self] in
            await self?.loadInitialDay(for: initialDate)
        }
    }

    func select(date: Date) {
        let targetDate = calendar.startOfDay(for: date)
        guard targetDate != selectedDate else { return }

        autosaveTask?.cancel()
        autosaveTask = nil
        selectionTask?.cancel()
        initializationTask?.cancel()
        let oldSheet = sheet
        let oldKey = key(for: sheetDate)

        selectedDate = targetDate
        isLoading = true

        selectionTask = Task { [weak self] in
            guard let self else { return }
            await self.persist(oldSheet, key: oldKey)
            guard !Task.isCancelled else { return }

            do {
                let loaded = try await persistence.loadDay(key: key(for: targetDate))
                guard !Task.isCancelled, targetDate == selectedDate else { return }
                sheet = migrated(loaded ?? blankSheet())
                sheetDate = targetDate
                ensurePriorityCapacity(settings.priorityCount)
                isLoading = false
            } catch {
                guard targetDate == selectedDate else { return }
                persistenceError = "Unable to load this day. \(error.localizedDescription)"
                sheet = blankSheet()
                sheetDate = targetDate
                isLoading = false
            }
        }
    }

    func priorityBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { self.sheet.priorities.indices.contains(index) ? self.sheet.priorities[index] : "" },
            set: { newValue in
                self.ensurePriorityCapacity(index + 1)
                self.sheet.priorities[index] = newValue
                self.scheduleAutosave()
            }
        )
    }

    func brainDumpBinding() -> Binding<String> {
        Binding(
            get: { self.sheet.brainDump },
            set: { newValue in
                self.sheet.brainDump = newValue
                self.scheduleAutosave()
            }
        )
    }

    func blockBinding(at startMinute: Int, intervalMinutes: Int) -> Binding<String> {
        Binding(
            get: { self.block(startingAt: startMinute)?.text ?? "" },
            set: { self.updateBlockText($0, at: startMinute, intervalMinutes: intervalMinutes) }
        )
    }

    @discardableResult
    func adoptDefaultIntervalIfEmpty(_ intervalMinutes: Int) -> Bool {
        guard !sheet.hasMeaningfulData else { return false }
        sheet.intervalMinutes = intervalMinutes
        sheet.blocks.removeAll(where: { !$0.isMeaningful })
        scheduleAutosave()
        return true
    }

    func finalizeBlockEditing(at startMinute: Int) {
        guard let index = sheet.blocks.firstIndex(where: { $0.startMinute == startMinute }) else { return }
        if sheet.blocks[index].text.trimmed.isEmpty { sheet.blocks.remove(at: index) }
        scheduleAutosave()
    }

    func clearBlock(id: UUID) {
        guard let index = sheet.blocks.firstIndex(where: { $0.id == id }) else { return }
        sheet.blocks.remove(at: index)
        scheduleAutosave()
    }

    func canMergeWithPrevious(blockID: UUID, intervalMinutes: Int) -> Bool {
        guard let block = sheet.blocks.first(where: { $0.id == blockID }), block.isMeaningful else { return false }
        guard block.durationMinutes == intervalMinutes, let previous = previousBlock(for: block) else { return false }
        return previous.text.trimmed == block.text.trimmed
    }

    func mergeWithPrevious(blockID: UUID, intervalMinutes: Int) {
        guard canMergeWithPrevious(blockID: blockID, intervalMinutes: intervalMinutes),
              let currentIndex = sheet.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let block = sheet.blocks[currentIndex]
        guard let previous = previousBlock(for: block),
              let previousIndex = sheet.blocks.firstIndex(where: { $0.id == previous.id }) else { return }
        sheet.blocks[previousIndex].durationMinutes += block.durationMinutes
        sheet.blocks.remove(at: currentIndex)
        scheduleAutosave()
    }

    func canUnmerge(blockID: UUID, intervalMinutes: Int) -> Bool {
        guard let block = sheet.blocks.first(where: { $0.id == blockID }) else { return false }
        return block.durationMinutes > intervalMinutes
    }

    func unmerge(blockID: UUID, intervalMinutes: Int) {
        guard let index = sheet.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let block = sheet.blocks[index]
        guard block.durationMinutes > intervalMinutes else { return }
        let remainingDuration = block.durationMinutes - intervalMinutes
        sheet.blocks[index].durationMinutes = remainingDuration
        sheet.blocks.append(
            TimeBlock(
                startMinute: block.startMinute + remainingDuration,
                durationMinutes: intervalMinutes,
                text: block.text
            )
        )
        sortBlocks()
        scheduleAutosave()
    }

    func ensurePriorityCapacity(_ count: Int) {
        guard count > sheet.priorities.count else { return }
        sheet.priorities.append(contentsOf: Array(repeating: "", count: count - sheet.priorities.count))
    }

    func clearPersistenceError() {
        persistenceError = nil
    }

    func flushAutosave() async {
        autosaveTask?.cancel()
        autosaveTask = nil
        if isLoading {
            await selectionTask?.value
            await initializationTask?.value
        }
        await persist(sheet, key: key(for: sheetDate))
    }

    func waitForPendingOperations() async {
        await initializationTask?.value
        await selectionTask?.value
        await autosaveTask?.value
    }

    private func loadInitialDay(for date: Date) async {
        do {
            let keys = try await persistence.prepare()
            guard !Task.isCancelled, date == selectedDate else { return }
            savedDayKeys = keys
            let loaded = try await persistence.loadDay(key: key(for: date))
            guard !Task.isCancelled, date == selectedDate else { return }
            sheet = migrated(loaded ?? blankSheet())
            sheetDate = date
            ensurePriorityCapacity(settings.priorityCount)
            isLoading = false
        } catch {
            guard !Task.isCancelled, date == selectedDate else { return }
            persistenceError = "Unable to open saved days. \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func migrated(_ sheet: DaySheet) -> DaySheet {
        var copy = sheet
        // Before per-day intervals existed every day used a 30-minute grid.
        if copy.intervalMinutes == nil { copy.intervalMinutes = 30 }
        return copy
    }

    private func blankSheet() -> DaySheet {
        DaySheet(
            priorities: Array(repeating: "", count: settings.priorityCount),
            intervalMinutes: settings.intervalMinutes
        )
    }

    private func updateBlockText(_ text: String, at startMinute: Int, intervalMinutes: Int) {
        if let index = sheet.blocks.firstIndex(where: { $0.startMinute == startMinute }) {
            sheet.blocks[index].text = text
        } else {
            guard !text.isEmpty else { return }
            sheet.blocks.append(
                TimeBlock(
                    startMinute: startMinute,
                    durationMinutes: intervalMinutes,
                    text: text
                )
            )
            sortBlocks()
        }
        scheduleAutosave()
    }

    private func previousBlock(for block: TimeBlock) -> TimeBlock? {
        sheet.blocks
            .filter { $0.id != block.id && $0.endMinute == block.startMinute && $0.isMeaningful }
            .sorted { $0.startMinute < $1.startMinute }
            .last
    }

    private func block(startingAt startMinute: Int) -> TimeBlock? {
        sheet.blocks.first(where: { $0.startMinute == startMinute })
    }

    private func sortBlocks() {
        sheet.blocks.sort {
            $0.startMinute == $1.startMinute
                ? $0.id.uuidString < $1.id.uuidString
                : $0.startMinute < $1.startMinute
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            await self.persist(self.sheet, key: self.key(for: self.sheetDate))
        }
    }

    private func persist(_ sheet: DaySheet, key: String) async {
        do {
            switch try await persistence.saveDay(sheet, key: key) {
            case .saved:
                savedDayKeys.insert(key)
            case .removed:
                savedDayKeys.remove(key)
            }
        } catch {
            persistenceError = "Unable to save changes. \(error.localizedDescription)"
        }
    }

    private func key(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
