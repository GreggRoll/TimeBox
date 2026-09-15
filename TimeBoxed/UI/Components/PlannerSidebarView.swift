import SwiftUI

struct PlannerSidebarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let settings: PlannerSettings
    let store: DayStore
    let proStore: ProStore
    let onShowPro: () -> Void
    let width: CGFloat
    let availableHeight: CGFloat
    let safeAreaTop: CGFloat
    let onSelectDate: (Date) -> Void
    let onDismiss: () -> Void

    private var compactControls: Bool {
        width < 360 || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                SidebarSectionCard(
                    padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                ) {
                    SavedDaysCalendarView(
                        selection: store.selectedDate,
                        savedDayKeys: store.savedDayKeys,
                        onSelect: onSelectDate
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Saved days calendar")
                    .blur(radius: proStore.hasPro ? 0 : 7)
                    .disabled(!proStore.hasPro)
                    .accessibilityHidden(!proStore.hasPro)
                    .overlay {
                        if !proStore.hasPro {
                            VStack(spacing: 10) {
                                Image(systemName: "lock.fill").font(.title2)
                                    .accessibilityHidden(true)
                                Button("Unlock History", action: onShowPro)
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("unlockHistoryButton")
                                Text("Revisit every saved day with Pro")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }

                Button(action: onShowPro) {
                    Label(proStore.hasPro ? "Time Boxed Pro · Unlocked" : "Explore Time Boxed Pro", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                Button("Go to Today") { onSelectDate(Date()) }
                    .buttonStyle(.bordered)

                settingsCard
            }
            .padding(.horizontal, compactControls ? 16 : 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: availableHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AppTheme.materialStroke, lineWidth: 1)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 22, x: 8, y: 0)
        .padding(.leading, 10)
        .padding(.top, safeAreaTop + 10)
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack {
            Text("Days")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.strongSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close days and settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsCard: some View {
        SidebarSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Stepper(value: priorityCountBinding, in: 1...6) {
                    SettingLabel(title: "Priority Count", value: "\(settings.priorityCount)")
                }

                appearanceControl
                timeControl(title: "Start Time", minute: settings.startMinute, binding: startTimeBinding)
                timeControl(title: "End Time", minute: settings.endMinute, binding: endTimeBinding)
                intervalControl
                if proStore.hasPro {
                    exportControl
                } else {
                    Button(action: onShowPro) {
                        Label("Unlock Calendar & Reminders Export", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var appearanceControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingLabel(title: "Appearance", value: settings.appearance.title)
            if compactControls {
                Menu {
                    ForEach(AppAppearance.allCases) { appearance in
                        Button(appearance.title) { settings.appearance = appearance }
                    }
                } label: {
                    SidebarMenuLabel(text: settings.appearance.title)
                }
                .buttonStyle(.plain)
            } else {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func timeControl(title: String, minute: Int, binding: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingLabel(title: title, value: PlannerTimeFormatter.label(for: minute))
            DatePicker(title, selection: binding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(title)
        }
    }

    @ViewBuilder
    private var intervalControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingLabel(title: "Default Time Interval", value: "\(settings.intervalMinutes) min")
            if compactControls {
                Menu {
                    Button("30 min") { settings.setIntervalMinutes(30) }
                    Button("60 min") { settings.setIntervalMinutes(60) }
                } label: {
                    SidebarMenuLabel(text: "\(settings.intervalMinutes) min")
                }
                .buttonStyle(.plain)
            } else {
                Picker("Default Time Interval", selection: intervalBinding) {
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }
                .pickerStyle(.segmented)
            }
            Text("Applies to new and empty days. Filled days keep their original grid.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var exportControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingLabel(title: "Export Default", value: settings.exportDefault.title)
            if compactControls {
                Menu {
                    Button("Calendar") { settings.exportDefault = .calendar }
                    Button("Reminders") { settings.exportDefault = .reminders }
                } label: {
                    SidebarMenuLabel(text: settings.exportDefault.title)
                }
                .buttonStyle(.plain)
            } else {
                Picker("Export Default", selection: exportBinding) {
                    Text("Calendar").tag(ExportDestination.calendar)
                    Text("Reminders").tag(ExportDestination.reminders)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var priorityCountBinding: Binding<Int> {
        Binding(get: { settings.priorityCount }, set: { settings.priorityCount = $0 })
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(get: { settings.appearance }, set: { settings.appearance = $0 })
    }

    private var exportBinding: Binding<ExportDestination> {
        Binding(get: { settings.exportDefault }, set: { settings.exportDefault = $0 })
    }

    private var intervalBinding: Binding<Int> {
        Binding(get: { settings.intervalMinutes }, set: { settings.setIntervalMinutes($0) })
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { PlannerTimeFormatter.settingsDate(from: settings.startMinute) },
            set: {
                settings.setStartMinute(
                    PlannerTimeFormatter.snappedMinute(
                        from: $0,
                        interval: settings.intervalMinutes,
                        roundingUp: false
                    )
                )
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { PlannerTimeFormatter.settingsDate(from: settings.endMinute) },
            set: {
                settings.setEndMinute(
                    PlannerTimeFormatter.snappedMinute(
                        from: $0,
                        interval: settings.intervalMinutes,
                        roundingUp: true
                    )
                )
            }
        )
    }
}

private struct SettingLabel: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleText
                Spacer(minLength: 8)
                valueText.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                titleText
                valueText
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
    }

    private var valueText: some View {
        Text(value)
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
