import SwiftUI

private struct GridEntry: Identifiable {
    let minute: Int
    let block: TimeBlock?
    let span: Int
    var id: Int { minute }
}

struct TimeGridSection: View {
    let settings: PlannerSettings
    let store: DayStore
    let embeddedInPage: Bool
    let exportingBlockIDs: Set<UUID>
    @FocusState.Binding var focusedField: PlannerField?
    let onExport: (TimeBlock) -> Void

    @ScaledMetric(relativeTo: .caption) private var timeLabelWidth: CGFloat = 72

    private let calendar = Calendar.autoupdatingCurrent
    private let timeGridTopID = "time-grid-top"

    private var intervalMinutes: Int { store.effectiveIntervalMinutes }
    private var slotStarts: [Int] {
        settings.slotStarts(intervalMinutes: intervalMinutes)
    }

    private var gridEntries: [GridEntry] {
        let blocksByStart = store.sheet.blocks.reduce(into: [Int: TimeBlock]()) {
            $0[$1.startMinute] = $1
        }
        var entries: [GridEntry] = []
        var index = 0

        while index < slotStarts.count {
            let minute = slotStarts[index]
            if let block = blocksByStart[minute] {
                let span = max(1, Int(ceil(Double(block.durationMinutes) / Double(intervalMinutes))))
                let cappedSpan = min(span, slotStarts.count - index)
                entries.append(GridEntry(minute: minute, block: block, span: cappedSpan))
                index += cappedSpan
            } else {
                entries.append(GridEntry(minute: minute, block: nil, span: 1))
                index += 1
            }
        }
        return entries
    }

    var body: some View {
        SectionCard(padding: EdgeInsets(top: 18, leading: 18, bottom: 12, trailing: 18)) {
            VStack(alignment: .leading, spacing: 16) {
                gridHeader

                if embeddedInPage {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        gridContent(now: context.date)
                    }
                    .gridSurface()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: true) {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                gridContent(now: context.date)
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .gridSurface()
                        .onAppear { syncScroll(using: proxy, animated: false) }
                        .onChange(of: store.selectedDate) { _, _ in syncScroll(using: proxy) }
                        .onChange(of: settings.startMinute) { _, _ in syncScroll(using: proxy) }
                        .onChange(of: intervalMinutes) { _, _ in syncScroll(using: proxy) }
                        .onChange(of: focusedField) { _, newValue in
                            guard case let .block(blockID)? = newValue else { return }
                            keepFocusedBlockVisible(blockID: blockID, using: proxy)
                        }
                    }
                }
            }
        }
    }

    private var gridHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                gridTitle
                Spacer()
                intervalBadge
            }
            VStack(alignment: .leading, spacing: 10) {
                gridTitle
                intervalBadge
            }
        }
    }

    private var gridTitle: some View {
        Text("Time Boxing")
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var intervalBadge: some View {
        Text("\(intervalMinutes) min slots")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(AppTheme.strongSurface))
            .fixedSize(horizontal: true, vertical: false)
    }

    private func gridContent(now: Date) -> some View {
        let highlightedMinute = currentScheduleMinute(at: now)

        return VStack(spacing: 0) {
            Color.clear.frame(height: 0).id(timeGridTopID)

            LazyVStack(spacing: 0) {
                ForEach(gridEntries) { entry in
                    TimeGridRow(
                        minute: entry.minute,
                        block: entry.block,
                        intervalMinutes: intervalMinutes,
                        timeLabelWidth: min(timeLabelWidth, 108),
                        isCurrent: highlightedMinute.map {
                            $0 >= entry.minute
                                && $0 < entry.minute + (entry.span * intervalMinutes)
                        } ?? false,
                        isExporting: entry.block.map { exportingBlockIDs.contains($0.id) } ?? false,
                        focusedField: $focusedField,
                        store: store,
                        onExport: onExport
                    )
                    .id(entry.minute)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func currentScheduleMinute(at date: Date) -> Int? {
        guard calendar.isDateInToday(store.selectedDate) else { return nil }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard minute >= settings.startMinute, minute < settings.endMinute else { return nil }
        return minute
    }

    private func syncScroll(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard calendar.isDateInToday(store.selectedDate) else {
            scroll(to: timeGridTopID, using: proxy, anchor: .top, animated: animated)
            return
        }
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard minute >= settings.startMinute, minute < settings.endMinute else {
            scroll(to: timeGridTopID, using: proxy, anchor: .top, animated: animated)
            return
        }
        let index = (minute - settings.startMinute) / intervalMinutes
        guard slotStarts.indices.contains(index) else { return }
        scroll(to: slotStarts[index], using: proxy, anchor: .center, animated: animated)
    }

    private func scroll(
        to id: some Hashable,
        using proxy: ScrollViewProxy,
        anchor: UnitPoint,
        animated: Bool
    ) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(id, anchor: anchor) }
            } else {
                proxy.scrollTo(id, anchor: anchor)
            }
        }
    }

    private func keepFocusedBlockVisible(blockID: UUID, using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard focusedField == .block(blockID),
                  let block = store.sheet.blocks.first(where: { $0.id == blockID }) else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(block.startMinute, anchor: .center)
            }
        }
    }

}

private struct TimeGridRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .body) private var minimumBlockHeight: CGFloat = 44

    let minute: Int
    let block: TimeBlock?
    let intervalMinutes: Int
    let timeLabelWidth: CGFloat
    let isCurrent: Bool
    let isExporting: Bool
    @FocusState.Binding var focusedField: PlannerField?
    let store: DayStore
    let onExport: (TimeBlock) -> Void

    private var timeLabel: String { PlannerTimeFormatter.label(for: minute) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeLabel)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
                .frame(width: timeLabelWidth, alignment: .leading)
                .padding(.top, 12)
                .accessibilityHidden(true)

            if let block {
                filledBlock(block)
            } else {
                emptyBlock
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .trailing) {
            if isCurrent {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.highlightBand)
                    .padding(.leading, timeLabelWidth + 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func filledBlock(_ block: TimeBlock) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    blockTextField(block)
                    if block.isMeaningful {
                        exportButton(block)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                blockTextField(block)
                    .padding(.trailing, block.isMeaningful ? 44 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: minimumBlockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.strongSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.subtleStroke, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if !dynamicTypeSize.isAccessibilitySize, block.isMeaningful {
                exportButton(block)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            if block.isMeaningful {
                Button("Export", systemImage: "square.and.arrow.up") { onExport(block) }
                    .disabled(isExporting)
            }
            if store.canMergeWithPrevious(blockID: block.id, intervalMinutes: intervalMinutes) {
                Button("Merge with previous") {
                    store.mergeWithPrevious(blockID: block.id, intervalMinutes: intervalMinutes)
                }
            }
            if store.canUnmerge(blockID: block.id, intervalMinutes: intervalMinutes) {
                Button("Unmerge") { store.unmerge(blockID: block.id, intervalMinutes: intervalMinutes) }
            }
            Button("Clear", role: .destructive) { store.clearBlock(id: block.id) }
        }
        .accessibilityAction(named: "Export") {
            if block.isMeaningful, !isExporting { onExport(block) }
        }
        .accessibilityAction(named: "Clear") { store.clearBlock(id: block.id) }
    }

    private func blockTextField(_ block: TimeBlock) -> some View {
        TextField("Plan this block", text: store.blockBinding(id: block.id), axis: .vertical)
            .focused($focusedField, equals: .block(block.id))
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(AppTheme.primaryText)
            .lineLimit(1...)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            .accessibilityLabel("Block at \(timeLabel)")
            .accessibilityIdentifier("timeBlockField-\(minute)")
    }

    private func exportButton(_ block: TimeBlock) -> some View {
        Button {
            onExport(block)
        } label: {
            Group {
                if isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityLabel("Export block at \(timeLabel)")
        .accessibilityHint("Exports to the default destination")
    }

    private var emptyBlock: some View {
        Button {
            let blockID = store.createBlock(at: minute, intervalMinutes: intervalMinutes)
            focusedField = .block(blockID)
        } label: {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.gridSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity, minHeight: minimumBlockHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Empty block at \(timeLabel)")
        .accessibilityHint("Double tap to add a plan")
    }
}

private extension View {
    func gridSurface() -> some View {
        background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.gridSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
