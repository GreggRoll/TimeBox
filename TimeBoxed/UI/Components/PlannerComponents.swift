import SwiftUI

enum PlannerField: Hashable {
    case priority(Int)
    case brainDump
    case block(UUID)
}

enum PlannerTimeFormatter {
    private static let calendar = Calendar.autoupdatingCurrent

    static func label(for minute: Int) -> String {
        let safeMinute = minute.clamped(to: 0...(24 * 60))
        let dayStart = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .minute, value: safeMinute, to: dayStart) ?? dayStart
        if safeMinute % 60 == 0 {
            return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        }
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    }

    static func settingsDate(from minute: Int) -> Date {
        let dayStart = calendar.startOfDay(for: Date())
        return calendar.date(
            byAdding: .minute,
            value: minute.clamped(to: 0...(24 * 60)),
            to: dayStart
        ) ?? dayStart
    }

    static func snappedMinute(from date: Date, interval: Int, roundingUp: Bool) -> Int {
        let dayStart = calendar.startOfDay(for: Date())
        let rawValue = Int(date.timeIntervalSince(dayStart) / 60).clamped(to: 0...(24 * 60))
        let remainder = rawValue % interval
        guard remainder != 0 else { return rawValue }
        return roundingUp
            ? min(24 * 60, rawValue + (interval - remainder))
            : max(0, rawValue - remainder)
    }
}

struct PlannerBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundStart, AppTheme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.ambientGlow)
                .frame(width: 300, height: 300)
                .blur(radius: 24)
                .offset(x: 150, y: -240)

            Circle()
                .fill(AppTheme.accentGlow)
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .offset(x: -140, y: 300)
        }
        .accessibilityHidden(true)
    }
}

struct PlannerHeader: View {
    let title: String
    let subtitle: String
    let onSidebar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: onSidebar) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.strongSurface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.buttonStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("Open days and settings")

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
    }
}

struct PlannerSupportView: View {
    let settings: PlannerSettings
    let store: DayStore
    @FocusState.Binding var focusedField: PlannerField?
    let expandsBrainDump: Bool

    @ScaledMetric(relativeTo: .body) private var compactBrainDumpHeight: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var wideBrainDumpHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            priorities
            brainDump
                .frame(height: expandsBrainDump ? wideBrainDumpHeight : compactBrainDumpHeight)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var priorities: some View {
        SectionCard {
            Text("Priorities")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 0) {
                ForEach(0..<settings.priorityCount, id: \.self) { index in
                    TextField(
                        "",
                        text: store.priorityBinding(at: index),
                        prompt: Text("Priority \(index + 1)").foregroundColor(AppTheme.tertiaryText)
                    )
                    .focused($focusedField, equals: .priority(index))
                    .id(PlannerField.priority(index))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.vertical, 14)
                    .submitLabel(index == settings.priorityCount - 1 ? .done : .next)
                    .onSubmit {
                        focusedField = index < settings.priorityCount - 1 ? .priority(index + 1) : nil
                    }
                    .accessibilityLabel("Priority \(index + 1)")
                    .accessibilityIdentifier("priorityField\(index)")
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppTheme.divider)
                            .frame(height: index == settings.priorityCount - 1 ? 0 : 1)
                    }
                }
            }
        }
    }

    private var brainDump: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Brain Dump")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.strongSurface)

                    TextEditor(text: store.brainDumpBinding())
                        .focused($focusedField, equals: .brainDump)
                        .id(PlannerField.brainDump)
                        .scrollContentBackground(.hidden)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityLabel("Brain dump")
                        .accessibilityHint("Enter loose thoughts, notes, and ideas")
                        .accessibilityIdentifier("brainDumpEditor")

                    if store.sheet.brainDump.isEmpty {
                        Text("Loose thoughts, notes, and ideas to place later.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.top, 20)
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.subtleStroke, lineWidth: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let padding: EdgeInsets
    @ViewBuilder var content: Content

    init(
        padding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.cardSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 6)
    }
}

struct SidebarSectionCard<Content: View>: View {
    let padding: EdgeInsets
    @ViewBuilder var content: Content

    init(
        padding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppTheme.strongSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppTheme.sidebarStroke, lineWidth: 1)
            }
    }
}

struct SidebarMenuLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.mutedSurface)
        )
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(AppTheme.toastBackground))
            .accessibilityAddTraits(.isStaticText)
    }
}
