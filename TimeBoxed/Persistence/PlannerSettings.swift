import Foundation
import Observation

@MainActor
@Observable
final class PlannerSettings {
    var priorityCount: Int {
        didSet {
            let clamped = priorityCount.clamped(to: 1...6)
            if priorityCount != clamped {
                priorityCount = clamped
                return
            }

            defaults.set(priorityCount, forKey: Keys.priorityCount)
        }
    }

    private(set) var startMinute: Int
    private(set) var endMinute: Int
    private(set) var intervalMinutes: Int

    var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    var exportDefault: ExportDestination {
        didSet {
            defaults.set(exportDefault.rawValue, forKey: Keys.exportDefault)
        }
    }

    var slotStarts: [Int] {
        slotStarts(intervalMinutes: intervalMinutes)
    }

    func slotStarts(intervalMinutes: Int) -> [Int] {
        guard endMinute > startMinute else { return [] }
        return Array(stride(from: startMinute, to: endMinute, by: intervalMinutes))
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        priorityCount = (defaults.object(forKey: Keys.priorityCount) as? Int ?? 3).clamped(to: 1...6)
        let normalizedSchedule = Self.normalizedSchedule(
            startMinute: defaults.object(forKey: Keys.startMinute) as? Int ?? 6 * 60,
            endMinute: defaults.object(forKey: Keys.endMinute) as? Int ?? 21 * 60,
            intervalMinutes: defaults.object(forKey: Keys.intervalMinutes) as? Int ?? 30
        )
        startMinute = normalizedSchedule.startMinute
        endMinute = normalizedSchedule.endMinute
        intervalMinutes = normalizedSchedule.intervalMinutes
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .light
        exportDefault = ExportDestination(rawValue: defaults.string(forKey: Keys.exportDefault) ?? "") ?? .calendar

        persistSchedule()
    }

    func setStartMinute(_ minute: Int) {
        applySchedule(
            startMinute: minute,
            endMinute: endMinute,
            intervalMinutes: intervalMinutes
        )
    }

    func setEndMinute(_ minute: Int) {
        applySchedule(
            startMinute: startMinute,
            endMinute: minute,
            intervalMinutes: intervalMinutes
        )
    }

    func setIntervalMinutes(_ minutes: Int) {
        applySchedule(
            startMinute: startMinute,
            endMinute: endMinute,
            intervalMinutes: minutes
        )
    }

    private func applySchedule(startMinute: Int, endMinute: Int, intervalMinutes: Int) {
        let normalized = Self.normalizedSchedule(
            startMinute: startMinute,
            endMinute: endMinute,
            intervalMinutes: intervalMinutes
        )

        if self.startMinute != normalized.startMinute {
            self.startMinute = normalized.startMinute
        }

        if self.endMinute != normalized.endMinute {
            self.endMinute = normalized.endMinute
        }

        if self.intervalMinutes != normalized.intervalMinutes {
            self.intervalMinutes = normalized.intervalMinutes
        }

        persistSchedule()
    }

    private func persistSchedule() {
        defaults.set(startMinute, forKey: Keys.startMinute)
        defaults.set(endMinute, forKey: Keys.endMinute)
        defaults.set(intervalMinutes, forKey: Keys.intervalMinutes)
    }

    private static func normalizedSchedule(
        startMinute: Int,
        endMinute: Int,
        intervalMinutes: Int
    ) -> NormalizedSchedule {
        let safeInterval = (intervalMinutes == 60) ? 60 : 30

        var normalizedStart = snap(startMinute, interval: safeInterval, direction: .down)
        var normalizedEnd = snap(endMinute, interval: safeInterval, direction: .up)

        normalizedStart = normalizedStart.clamped(to: 0...(24 * 60 - safeInterval))
        normalizedEnd = normalizedEnd.clamped(to: safeInterval...(24 * 60))

        if normalizedEnd <= normalizedStart {
            normalizedEnd = min(24 * 60, normalizedStart + safeInterval)
        }

        if (normalizedEnd - normalizedStart) < safeInterval {
            normalizedEnd = min(24 * 60, normalizedStart + safeInterval)
            if normalizedEnd == normalizedStart {
                normalizedStart = max(0, normalizedEnd - safeInterval)
            }
        }

        return NormalizedSchedule(
            startMinute: normalizedStart,
            endMinute: normalizedEnd,
            intervalMinutes: safeInterval
        )
    }

    private static func snap(_ minute: Int, interval: Int, direction: SnapDirection) -> Int {
        switch direction {
        case .down:
            return (minute / interval) * interval
        case .up:
            let remainder = minute % interval
            if remainder == 0 {
                return minute
            }
            return minute + (interval - remainder)
        }
    }

    private enum SnapDirection {
        case down
        case up
    }

    private struct NormalizedSchedule {
        let startMinute: Int
        let endMinute: Int
        let intervalMinutes: Int
    }

    private enum Keys {
        static let priorityCount = "planner.priorityCount"
        static let startMinute = "planner.startMinute"
        static let endMinute = "planner.endMinute"
        static let intervalMinutes = "planner.intervalMinutes"
        static let appearance = "planner.appearance"
        static let exportDefault = "planner.exportDefault"
    }
}
