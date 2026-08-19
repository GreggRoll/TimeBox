import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let settings: PlannerSettings
    let store: DayStore
    let exportManager: ExportManager

    @State private var isSidebarPresented = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var exportingBlockIDs: Set<UUID> = []
    @FocusState private var focusedField: PlannerField?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                PlannerBackground()

                plannerContent(in: geometry)
                    .disabled(store.isLoading)
                    .overlay {
                        if store.isLoading {
                            ProgressView("Loading day…")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .padding(18)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityAddTraits(.isModal)
                        }
                    }

                if isSidebarPresented {
                    AppTheme.overlayScrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture(perform: dismissSidebar)
                        .accessibilityHidden(true)

                    PlannerSidebarView(
                        settings: settings,
                        store: store,
                        width: sidebarWidth(for: geometry.size.width),
                        availableHeight: max(
                            0,
                            geometry.size.height
                                - geometry.safeAreaInsets.top
                                - geometry.safeAreaInsets.bottom
                                - 20
                        ),
                        safeAreaTop: geometry.safeAreaInsets.top,
                        onSelectDate: { date in
                            focusedField = nil
                            store.select(date: date)
                            dismissSidebar()
                        },
                        onDismiss: dismissSidebar
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    ToastView(message: toastMessage)
                        .padding(.top, geometry.safeAreaInsets.top + 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: dismissKeyboard) {
                    Label("Done", systemImage: "keyboard.chevron.compact.down")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                    .accessibilityLabel("Dismiss keyboard")
                    .accessibilityIdentifier("dismissKeyboardButton")
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isSidebarPresented)
        .onChange(of: focusedField) { oldValue, newValue in
            if case let .block(blockID)? = oldValue, newValue != .block(blockID) {
                store.finalizeBlockEditing(id: blockID)
            }
        }
        .onChange(of: settings.priorityCount) { _, newCount in
            store.ensurePriorityCapacity(newCount)
        }
        .onChange(of: settings.intervalMinutes) { _, newInterval in
            if !store.adoptDefaultIntervalIfEmpty(newInterval) {
                showToast(
                    "This saved day kept its \(store.effectiveIntervalMinutes)-minute grid. "
                    + "New days will use \(newInterval)-minute slots."
                )
            }
        }
        .alert(
            "Saved Days Error",
            isPresented: Binding(
                get: { store.persistenceError != nil },
                set: { if !$0 { store.clearPersistenceError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                store.clearPersistenceError()
            }
        } message: {
            Text(store.persistenceError ?? "An unknown storage error occurred.")
        }
        .onDisappear {
            toastTask?.cancel()
        }
    }

    @ViewBuilder
    private func plannerContent(in geometry: GeometryProxy) -> some View {
        let splitLayout = usesSplitLayout(for: geometry.size)
        let horizontalPadding = geometry.size.width < 430 ? 16.0 : 20.0
        let bottomPadding = focusedField == nil ? max(geometry.safeAreaInsets.bottom, 20) : 12

        Group {
            if splitLayout {
                let widths = columnWidths(
                    for: geometry.size.width,
                    horizontalPadding: horizontalPadding,
                    spacing: 18
                )

                VStack(alignment: .leading, spacing: 20) {
                    plannerHeader

                    HStack(alignment: .top, spacing: 18) {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                PlannerSupportView(
                                    settings: settings,
                                    store: store,
                                    focusedField: $focusedField,
                                    expandsBrainDump: true
                                )
                                .padding(.bottom, 12)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .onChange(of: focusedField) { _, newValue in
                                guard let newValue, newValue.isSupportField else { return }
                                keepVisible(newValue, using: proxy)
                            }
                        }
                        .frame(width: widths.left, alignment: .top)
                        .frame(maxHeight: .infinity, alignment: .top)

                        timeGrid(embeddedInPage: false)
                            .frame(width: widths.right, alignment: .top)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            plannerHeader

                            VStack(alignment: .leading, spacing: 18) {
                                PlannerSupportView(
                                    settings: settings,
                                    store: store,
                                    focusedField: $focusedField,
                                    expandsBrainDump: false
                                )
                                timeGrid(embeddedInPage: true)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) { _, newValue in
                        guard let newValue else { return }
                        keepVisible(newValue, using: proxy)
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, geometry.safeAreaInsets.top + 12)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var plannerHeader: some View {
        PlannerHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
            onSidebar: {
                dismissKeyboard()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isSidebarPresented.toggle()
                }
            }
        )
    }

    private func timeGrid(embeddedInPage: Bool) -> some View {
        TimeGridSection(
            settings: settings,
            store: store,
            embeddedInPage: embeddedInPage,
            exportingBlockIDs: exportingBlockIDs,
            focusedField: $focusedField,
            onExport: export
        )
    }

    private var headerTitle: String {
        calendar.isDateInToday(store.selectedDate)
            ? "Today"
            : store.selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var headerSubtitle: String {
        store.selectedDate.formatted(.dateTime.month(.wide).day().year())
    }

    private func export(_ block: TimeBlock) {
        guard block.isMeaningful, !exportingBlockIDs.contains(block.id) else { return }
        exportingBlockIDs.insert(block.id)
        let selectedDate = store.selectedDate
        let destination = settings.exportDefault

        Task {
            defer { exportingBlockIDs.remove(block.id) }
            do {
                let message = try await exportManager.export(
                    block: block,
                    on: selectedDate,
                    destination: destination
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast(message)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showToast(error.localizedDescription)
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            toastMessage = message
        }
        UIAccessibility.post(notification: .announcement, argument: message)

        toastTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }

    private func usesSplitLayout(for size: CGSize) -> Bool {
        size.height >= 600
            && (size.width >= 820 || (horizontalSizeClass == .regular && size.width >= 700))
    }

    private func keepVisible(_ field: PlannerField, using proxy: ScrollViewProxy) {
        let delay = field.isSupportField ? 0.25 : 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard focusedField == field else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                if case let .block(blockID) = field,
                   let block = store.sheet.blocks.first(where: { $0.id == blockID }) {
                    proxy.scrollTo(block.startMinute, anchor: .center)
                } else {
                    proxy.scrollTo(field, anchor: .center)
                }
            }
        }
    }

    private func columnWidths(
        for totalWidth: CGFloat,
        horizontalPadding: CGFloat,
        spacing: CGFloat
    ) -> (left: CGFloat, right: CGFloat) {
        let contentWidth = max(0, totalWidth - (horizontalPadding * 2) - spacing)
        return (contentWidth * 0.30, contentWidth * 0.70)
    }

    private func sidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        let horizontalInset: CGFloat = totalWidth < 430 ? 20 : 28
        let maximumWidth = min(420, totalWidth - horizontalInset)
        return totalWidth < 520
            ? maximumWidth
            : min(maximumWidth, max(340, totalWidth * 0.72))
    }

    private func dismissSidebar() {
        dismissKeyboard()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            isSidebarPresented = false
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

private extension PlannerField {
    var isSupportField: Bool {
        switch self {
        case .priority, .brainDump:
            return true
        case .block:
            return false
        }
    }
}
