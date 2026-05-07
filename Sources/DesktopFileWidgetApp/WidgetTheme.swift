import SwiftUI

enum WidgetTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct ThemeTokens {
    let panel: Color
    let panelStroke: Color
    let panelInnerStroke: Color
    let header: Color
    let headerGlow: Color
    let headerStart: Color
    let headerEnd: Color
    let headerSpark: Color
    let rowA: Color
    let rowB: Color
    let rowHover: Color
    let rowSelected: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let danger: Color

    static func resolve(_ scheme: ColorScheme) -> ThemeTokens {
        if scheme == .dark {
            return ThemeTokens(
                panel: Color(red: 0.035, green: 0.055, blue: 0.070).opacity(0.74),
                panelStroke: Color(red: 0.62, green: 0.86, blue: 0.91).opacity(0.42),
                panelInnerStroke: Color.white.opacity(0.08),
                header: Color(red: 0.08, green: 0.18, blue: 0.20).opacity(0.72),
                headerGlow: Color(red: 0.09, green: 0.75, blue: 0.72).opacity(0.28),
                headerStart: Color(red: 0.04, green: 0.32, blue: 0.36).opacity(0.88),
                headerEnd: Color(red: 0.24, green: 0.12, blue: 0.42).opacity(0.82),
                headerSpark: Color(red: 1.00, green: 0.74, blue: 0.30),
                rowA: Color(red: 0.045, green: 0.075, blue: 0.085).opacity(0.62),
                rowB: Color(red: 0.105, green: 0.175, blue: 0.185).opacity(0.76),
                rowHover: Color(red: 0.12, green: 0.58, blue: 0.58).opacity(0.34),
                rowSelected: Color(red: 0.10, green: 0.70, blue: 0.64).opacity(0.42),
                text: Color(red: 0.95, green: 0.98, blue: 0.97),
                secondaryText: Color(red: 0.72, green: 0.82, blue: 0.82),
                accent: Color(red: 0.26, green: 0.91, blue: 0.82),
                danger: Color(red: 1.00, green: 0.45, blue: 0.38)
            )
        }
        return ThemeTokens(
            panel: Color(red: 0.95, green: 0.985, blue: 0.97).opacity(0.78),
            panelStroke: Color(red: 0.10, green: 0.45, blue: 0.52).opacity(0.30),
            panelInnerStroke: Color.white.opacity(0.65),
            header: Color(red: 0.86, green: 0.97, blue: 0.94).opacity(0.74),
            headerGlow: Color(red: 0.14, green: 0.73, blue: 0.67).opacity(0.20),
            headerStart: Color(red: 0.72, green: 0.94, blue: 0.86).opacity(0.94),
            headerEnd: Color(red: 0.44, green: 0.74, blue: 0.94).opacity(0.88),
            headerSpark: Color(red: 1.00, green: 0.46, blue: 0.25),
            rowA: Color(red: 0.995, green: 0.998, blue: 0.970).opacity(0.88),
            rowB: Color(red: 0.790, green: 0.915, blue: 0.885).opacity(0.90),
            rowHover: Color(red: 0.52, green: 0.88, blue: 0.82).opacity(0.62),
            rowSelected: Color(red: 0.27, green: 0.72, blue: 0.68).opacity(0.48),
            text: Color(red: 0.075, green: 0.12, blue: 0.13),
            secondaryText: Color(red: 0.31, green: 0.43, blue: 0.44),
            accent: Color(red: 0.02, green: 0.58, blue: 0.54),
            danger: Color(red: 0.76, green: 0.10, blue: 0.10)
        )
    }
}
