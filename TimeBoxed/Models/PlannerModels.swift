import Foundation

enum AppAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

enum ExportDestination: String, CaseIterable, Codable, Identifiable, Sendable {
    case calendar
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar:
            return "Calendar"
        case .reminders:
            return "Reminders"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .calendar:
            return "Added to Calendar"
        case .reminders:
            return "Added to Reminders"
        }
    }
}

struct TimeBlock: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var startMinute: Int
    var durationMinutes: Int
    var text: String

    init(
        id: UUID = UUID(),
        startMinute: Int,
        durationMinutes: Int,
        text: String = ""
    ) {
        self.id = id
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.text = text
    }

    var endMinute: Int {
        startMinute + durationMinutes
    }

    var isMeaningful: Bool {
        !text.trimmed.isEmpty
    }
}

struct DaySheet: Codable, Equatable, Sendable {
    var priorities: [String]
    var brainDump: String
    var blocks: [TimeBlock]
    /// The grid used when this day was created. `nil` only occurs in legacy files.
    var intervalMinutes: Int?

    init(
        priorities: [String] = [],
        brainDump: String = "",
        blocks: [TimeBlock] = [],
        intervalMinutes: Int? = nil
    ) {
        self.priorities = priorities
        self.brainDump = brainDump
        self.blocks = blocks
        self.intervalMinutes = intervalMinutes
    }

    var hasMeaningfulData: Bool {
        priorities.contains { !$0.trimmed.isEmpty }
        || !brainDump.trimmed.isEmpty
        || blocks.contains(where: \.isMeaningful)
    }

    func normalizedForPersistence() -> DaySheet {
        var copy = self
        copy.priorities = copy.priorities.trimmingTrailingEmptyEntries()
        copy.blocks = copy.blocks
            .filter(\.isMeaningful)
            .sorted { lhs, rhs in
                if lhs.startMinute == rhs.startMinute {
                    return lhs.id.uuidString < rhs.id.uuidString
                }

                return lhs.startMinute < rhs.startMinute
            }
        return copy
    }
}

extension Array where Element == String {
    func trimmingTrailingEmptyEntries() -> [String] {
        var copy = self

        while let last = copy.last, last.trimmed.isEmpty {
            copy.removeLast()
        }

        return copy
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
