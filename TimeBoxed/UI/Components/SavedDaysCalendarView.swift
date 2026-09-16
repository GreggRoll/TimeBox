import SwiftUI
import UIKit

struct SavedDaysCalendarView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    let selection: Date
    let savedDayKeys: Set<String>
    let onSelect: (Date) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CalendarContainerView {
        let containerView = CalendarContainerView()
        let calendarView = containerView.calendarView
        calendarView.calendar = context.coordinator.calendar
        calendarView.locale = .autoupdatingCurrent
        calendarView.tintColor = AppTheme.accentUIColor
        calendarView.wantsDateDecorations = true
        calendarView.delegate = context.coordinator
        calendarView.backgroundColor = .clear
        calendarView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selectionBehavior
        context.coordinator.selectionBehavior = selectionBehavior
        context.coordinator.calendarView = calendarView

        let selectedComponents = context.coordinator.dateComponents(for: selection)
        selectionBehavior.setSelected(selectedComponents, animated: false)
        calendarView.visibleDateComponents = selectedComponents
        context.coordinator.lastSelectionKey = context.coordinator.key(for: selectedComponents)
        context.coordinator.lastVisibleMonthKey = context.coordinator.monthKey(for: selectedComponents)
        context.coordinator.lastSavedDayKeys = savedDayKeys

        return containerView
    }

    func updateUIView(_ uiView: CalendarContainerView, context: Context) {
        context.coordinator.parent = self
        let calendarView = uiView.calendarView
        calendarView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let selectedComponents = context.coordinator.dateComponents(for: selection)
        let selectionKey = context.coordinator.key(for: selectedComponents)
        if context.coordinator.lastSelectionKey != selectionKey {
            context.coordinator.isSyncingSelection = true
            context.coordinator.selectionBehavior?.setSelected(selectedComponents, animated: calendarView.window != nil)
            context.coordinator.isSyncingSelection = false
            context.coordinator.lastSelectionKey = selectionKey
        }

        let visible = calendarView.visibleDateComponents
        if visible.year != selectedComponents.year || visible.month != selectedComponents.month {
            calendarView.visibleDateComponents = selectedComponents
            context.coordinator.lastVisibleMonthKey = context.coordinator.monthKey(for: selectedComponents)
        }

        if context.coordinator.lastSavedDayKeys != savedDayKeys {
            let changedKeys = context.coordinator.lastSavedDayKeys.symmetricDifference(savedDayKeys)
            let changedDates = context.coordinator.savedDateComponents(for: changedKeys)
            if !changedDates.isEmpty {
                calendarView.reloadDecorations(forDateComponents: changedDates, animated: calendarView.window != nil)
            }
            context.coordinator.lastSavedDayKeys = savedDayKeys
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CalendarContainerView, context: Context) -> CGSize? {
        uiView.fittingSize(for: proposal.width ?? 320)
    }

    final class CalendarContainerView: UIView {
        let calendarView = UICalendarView()

        override init(frame: CGRect) {
            super.init(frame: frame)

            backgroundColor = AppTheme.calendarSurfaceUIColor
            layer.cornerRadius = 22
            layer.cornerCurve = .continuous
            clipsToBounds = true

            calendarView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(calendarView)

            NSLayoutConstraint.activate([
                calendarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                calendarView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                calendarView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                calendarView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func fittingSize(for width: CGFloat) -> CGSize {
            let resolvedWidth = max(width, 1)
            let widthConstraint = widthAnchor.constraint(equalToConstant: resolvedWidth)
            widthConstraint.isActive = true

            defer {
                widthConstraint.isActive = false
            }

            setNeedsLayout()
            layoutIfNeeded()

            let size = systemLayoutSizeFitting(
                CGSize(width: resolvedWidth, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )

            return CGSize(width: resolvedWidth, height: ceil(size.height))
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: SavedDaysCalendarView
        let calendar = Calendar.autoupdatingCurrent

        weak var calendarView: UICalendarView?
        weak var selectionBehavior: UICalendarSelectionSingleDate?
        var isSyncingSelection = false
        var lastSelectionKey: String?
        var lastVisibleMonthKey: String?
        var lastSavedDayKeys: Set<String> = []

        init(parent: SavedDaysCalendarView) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard !isSyncingSelection else { return }
            guard let dateComponents, let date = calendar.date(from: dateComponents) else { return }
            lastSelectionKey = key(for: dateComponents)
            parent.onSelect(date)
        }

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            if parent.savedDayKeys.contains(key(for: dateComponents)) {
                return .default(color: AppTheme.accentUIColor, size: .small)
            }

            return nil
        }

        func dateComponents(for date: Date) -> DateComponents {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.calendar = calendar
            return components
        }

        func savedDateComponents(for keys: Set<String>) -> [DateComponents] {
            keys.compactMap { key in
                let parts = key.split(separator: "-")
                guard parts.count == 3 else { return nil }
                guard
                    let year = Int(parts[0]),
                    let month = Int(parts[1]),
                    let day = Int(parts[2])
                else {
                    return nil
                }

                var components = DateComponents()
                components.calendar = calendar
                components.year = year
                components.month = month
                components.day = day
                return components
            }
        }

        func key(for dateComponents: DateComponents) -> String {
            String(
                format: "%04d-%02d-%02d",
                dateComponents.year ?? 0,
                dateComponents.month ?? 0,
                dateComponents.day ?? 0
            )
        }

        func monthKey(for dateComponents: DateComponents) -> String {
            String(
                format: "%04d-%02d",
                dateComponents.year ?? 0,
                dateComponents.month ?? 0
            )
        }
    }
}
