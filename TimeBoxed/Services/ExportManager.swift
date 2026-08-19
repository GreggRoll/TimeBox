import EventKit
import Foundation

@MainActor
final class ExportManager {
    private let eventStore = EKEventStore()
    private let calendar = Calendar.autoupdatingCurrent

    func export(block: TimeBlock, on selectedDay: Date, destination: ExportDestination) async throws -> String {
        let title = block.text.trimmed
        guard !title.isEmpty else {
            throw ExportManagerError.emptyBlock
        }

        switch destination {
        case .calendar:
            try await requestCalendarPermission()
            try exportToCalendar(title: title, block: block, on: selectedDay)
        case .reminders:
            try await requestReminderPermission()
            try exportToReminders(title: title, block: block, on: selectedDay)
        }

        return destination.confirmationMessage
    }

    private func requestCalendarPermission() async throws {
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            eventStore.requestWriteOnlyAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: granted)
            }
        }

        guard granted else {
            throw ExportManagerError.permissionDenied(name: "Calendar")
        }
    }

    private func requestReminderPermission() async throws {
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: granted)
            }
        }

        guard granted else {
            throw ExportManagerError.permissionDenied(name: "Reminders")
        }
    }

    private func exportToCalendar(title: String, block: TimeBlock, on selectedDay: Date) throws {
        guard let eventCalendar = eventStore.defaultCalendarForNewEvents
            ?? eventStore.calendars(for: .event).first(where: \.allowsContentModifications) else {
            throw ExportManagerError.destinationUnavailable(name: "Calendar")
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventCalendar
        event.title = title
        event.startDate = date(for: block.startMinute, on: selectedDay)
        event.endDate = date(for: block.endMinute, on: selectedDay)

        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    private func exportToReminders(title: String, block: TimeBlock, on selectedDay: Date) throws {
        guard let remindersCalendar = eventStore.calendars(for: .reminder).first(where: \.allowsContentModifications) else {
            throw ExportManagerError.destinationUnavailable(name: "Reminders")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = remindersCalendar
        reminder.title = title

        let dueDate = date(for: block.startMinute, on: selectedDay)
        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)

        try eventStore.save(reminder, commit: true)
    }

    private func date(for minute: Int, on selectedDay: Date) -> Date {
        let dayStart = calendar.startOfDay(for: selectedDay)
        return calendar.date(byAdding: .minute, value: minute, to: dayStart) ?? dayStart
    }
}

enum ExportManagerError: LocalizedError {
    case emptyBlock
    case permissionDenied(name: String)
    case destinationUnavailable(name: String)

    var errorDescription: String? {
        switch self {
        case .emptyBlock:
            return "Only filled blocks can be exported."
        case let .permissionDenied(name):
            return "\(name) access is required to export this block."
        case let .destinationUnavailable(name):
            return "No writable \(name.lowercased()) destination is available."
        }
    }
}
