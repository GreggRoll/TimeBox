import SwiftUI
import UIKit

@main
struct TimeBoxedApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings: PlannerSettings
    @State private var dayStore: DayStore
    @State private var proStore = ProStore()

    private let exportManager = ExportManager()

    init() {
        let settings = PlannerSettings()
        _settings = State(initialValue: settings)
        _dayStore = State(initialValue: DayStore(settings: settings))
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(settings: settings, store: dayStore, exportManager: exportManager, proStore: proStore)
            }
            .tint(AppTheme.accent)
            .preferredColorScheme(settings.appearance.preferredColorScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                Task {
                    await dayStore.flushAutosave()
                }
            }
        }
    }

    private func configureAppearance() {
        let segmentedControl = UISegmentedControl.appearance()
        segmentedControl.selectedSegmentTintColor = AppTheme.accentUIColor
        segmentedControl.backgroundColor = AppTheme.segmentedControlBackgroundUIColor
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: AppTheme.primaryTextUIColor],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: AppTheme.secondaryTextUIColor.withAlphaComponent(0.65)],
            for: .disabled
        )

        UITextField.appearance().tintColor = AppTheme.accentUIColor
        UITextView.appearance().tintColor = AppTheme.accentUIColor
        UIDatePicker.appearance().tintColor = AppTheme.accentUIColor
        UIStepper.appearance().tintColor = AppTheme.accentUIColor
    }
}

enum AppTheme {
    static let accentUIColor = dynamicColor(
        light: UIColor(red: 0.18, green: 0.46, blue: 0.24, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.54, blue: 0.30, alpha: 1)
    )
    static let primaryTextUIColor = dynamicColor(
        light: UIColor(red: 0.12, green: 0.17, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.96, blue: 0.93, alpha: 1)
    )
    static let secondaryTextUIColor = dynamicColor(
        light: UIColor(red: 0.28, green: 0.34, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.78, blue: 0.73, alpha: 1)
    )
    static let tertiaryTextUIColor = dynamicColor(
        light: UIColor(red: 0.40, green: 0.45, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.62, blue: 0.57, alpha: 1)
    )
    static let backgroundStartUIColor = dynamicColor(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.11, blue: 0.09, alpha: 1)
    )
    static let backgroundEndUIColor = dynamicColor(
        light: UIColor(red: 0.91, green: 0.94, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.15, blue: 0.12, alpha: 1)
    )
    static let ambientGlowUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.38),
        dark: UIColor(red: 0.27, green: 0.32, blue: 0.29, alpha: 0.24)
    )
    static let accentGlowUIColor = dynamicColor(
        light: UIColor(red: 0.72, green: 0.84, blue: 0.66, alpha: 0.24),
        dark: UIColor(red: 0.24, green: 0.42, blue: 0.29, alpha: 0.24)
    )
    static let cardSurfaceUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.78),
        dark: UIColor(red: 0.13, green: 0.17, blue: 0.14, alpha: 0.92)
    )
    static let strongSurfaceUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),
        dark: UIColor(red: 0.16, green: 0.20, blue: 0.17, alpha: 0.97)
    )
    static let gridSurfaceUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.62),
        dark: UIColor(red: 0.18, green: 0.23, blue: 0.19, alpha: 0.86)
    )
    static let mutedSurfaceUIColor = dynamicColor(
        light: UIColor(red: 0.94, green: 0.96, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.22, blue: 0.19, alpha: 1)
    )
    static let calendarSurfaceUIColor = dynamicColor(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.19, blue: 0.16, alpha: 1)
    )
    static let segmentedControlBackgroundUIColor = dynamicColor(
        light: UIColor(red: 0.90, green: 0.93, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.17, green: 0.21, blue: 0.18, alpha: 1)
    )
    static let overlayScrimUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.16),
        dark: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.36)
    )
    static let dividerUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10)
    )
    static let subtleStrokeUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.04),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08)
    )
    static let borderUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.05),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10)
    )
    static let buttonStrokeUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.65),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12)
    )
    static let cardStrokeUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.34),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08)
    )
    static let materialStrokeUIColor = dynamicColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10)
    )
    static let sidebarStrokeUIColor = dynamicColor(
        light: UIColor(red: 0.82, green: 0.87, blue: 0.81, alpha: 0.85),
        dark: UIColor(red: 0.33, green: 0.40, blue: 0.35, alpha: 0.92)
    )
    static let highlightBandUIColor = dynamicColor(
        light: UIColor(red: 0.18, green: 0.46, blue: 0.24, alpha: 0.09),
        dark: UIColor(red: 0.30, green: 0.62, blue: 0.36, alpha: 0.18)
    )
    static let toastBackgroundUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.78),
        dark: UIColor(red: 0.05, green: 0.07, blue: 0.06, alpha: 0.92)
    )
    static let shadowUIColor = dynamicColor(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08),
        dark: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.24)
    )

    static let accent = color(from: accentUIColor)
    static let primaryText = color(from: primaryTextUIColor)
    static let secondaryText = color(from: secondaryTextUIColor)
    static let tertiaryText = color(from: tertiaryTextUIColor)
    static let backgroundStart = color(from: backgroundStartUIColor)
    static let backgroundEnd = color(from: backgroundEndUIColor)
    static let ambientGlow = color(from: ambientGlowUIColor)
    static let accentGlow = color(from: accentGlowUIColor)
    static let cardSurface = color(from: cardSurfaceUIColor)
    static let strongSurface = color(from: strongSurfaceUIColor)
    static let gridSurface = color(from: gridSurfaceUIColor)
    static let mutedSurface = color(from: mutedSurfaceUIColor)
    static let overlayScrim = color(from: overlayScrimUIColor)
    static let divider = color(from: dividerUIColor)
    static let subtleStroke = color(from: subtleStrokeUIColor)
    static let border = color(from: borderUIColor)
    static let buttonStroke = color(from: buttonStrokeUIColor)
    static let cardStroke = color(from: cardStrokeUIColor)
    static let materialStroke = color(from: materialStrokeUIColor)
    static let sidebarStroke = color(from: sidebarStrokeUIColor)
    static let highlightBand = color(from: highlightBandUIColor)
    static let toastBackground = color(from: toastBackgroundUIColor)
    static let shadow = color(from: shadowUIColor)

    private static func color(from uiColor: UIColor) -> Color {
        Color(uiColor: uiColor)
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}

private extension AppAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
