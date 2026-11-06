import CurSimpleCore
import SwiftUI

/// Color tokens copied from the app's shared theme so both platforms read the same.
struct AppColors {

    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color
    let outline: Color
    let outlineVariant: Color
    let gridLine: Color
    let todayContainer: Color
    let todayOnContainer: Color
    let error: Color

    static func resolve(accent: AccentTheme, dark: Bool) -> AppColors {
        let palette = Swatch.of(accent)
        return dark ? palette.dark : palette.light
    }

    private struct Swatch {

        let light: AppColors
        let dark: AppColors

        static func of(_ accent: AccentTheme) -> Swatch {
            switch accent {
            case .green:
                Swatch(
                    light: AppColors(
                        primary: c("#3FA277"), onPrimary: c("#FFFFFF"),
                        primaryContainer: c("#CBEBD9"), onPrimaryContainer: c("#0E3A26"),
                        background: c("#F4F8F4"), onBackground: c("#1A2620"),
                        surface: c("#FFFFFF"), onSurface: c("#1A2620"),
                        surfaceVariant: c("#E6EEE7"), onSurfaceVariant: c("#566B5F"),
                        outline: c("#B6C4BB"), outlineVariant: c("#D4DDD7"),
                        gridLine: c("#E2E7E3"),
                        todayContainer: c("#1F2A24"), todayOnContainer: c("#FFFFFF"),
                        error: c("#B3261E")
                    ),
                    dark: AppColors(
                        primary: c("#8AD7AF"), onPrimary: c("#003824"),
                        primaryContainer: c("#1F5A3E"), onPrimaryContainer: c("#CBEBD9"),
                        background: c("#0F1612"), onBackground: c("#E2EBE5"),
                        surface: c("#161E1A"), onSurface: c("#E2EBE5"),
                        surfaceVariant: c("#1F2A24"), onSurfaceVariant: c("#A9BBB0"),
                        outline: c("#566B5F"), outlineVariant: c("#374239"),
                        gridLine: c("#272F2B"),
                        todayContainer: c("#E5EAE6"), todayOnContainer: c("#1A1A1A"),
                        error: c("#F2B8B5")
                    )
                )
            case .blue:
                Swatch(
                    light: AppColors(
                        primary: c("#3F6FB5"), onPrimary: c("#FFFFFF"),
                        primaryContainer: c("#D3E3FB"), onPrimaryContainer: c("#0C2A52"),
                        background: c("#F3F6FB"), onBackground: c("#192029"),
                        surface: c("#FFFFFF"), onSurface: c("#192029"),
                        surfaceVariant: c("#E3EAF2"), onSurfaceVariant: c("#566372"),
                        outline: c("#B1BCCB"), outlineVariant: c("#D2D9E1"),
                        gridLine: c("#E1E6EC"),
                        todayContainer: c("#192029"), todayOnContainer: c("#FFFFFF"),
                        error: c("#B3261E")
                    ),
                    dark: AppColors(
                        primary: c("#A9C7F5"), onPrimary: c("#0A2647"),
                        primaryContainer: c("#234471"), onPrimaryContainer: c("#D3E3FB"),
                        background: c("#0F141B"), onBackground: c("#E2E8F0"),
                        surface: c("#161D26"), onSurface: c("#E2E8F0"),
                        surfaceVariant: c("#1F2832"), onSurfaceVariant: c("#AAB6C4"),
                        outline: c("#566372"), outlineVariant: c("#374253"),
                        gridLine: c("#26313C"),
                        todayContainer: c("#E2E8F0"), todayOnContainer: c("#192029"),
                        error: c("#F2B8B5")
                    )
                )
            case .purple:
                Swatch(
                    light: AppColors(
                        primary: c("#7259B5"), onPrimary: c("#FFFFFF"),
                        primaryContainer: c("#E3DAF7"), onPrimaryContainer: c("#2B1D4F"),
                        background: c("#F6F4FB"), onBackground: c("#1F1B29"),
                        surface: c("#FFFFFF"), onSurface: c("#1F1B29"),
                        surfaceVariant: c("#EAE5F2"), onSurfaceVariant: c("#625873"),
                        outline: c("#B9B1CB"), outlineVariant: c("#D7D2E1"),
                        gridLine: c("#E6E1EE"),
                        todayContainer: c("#1F1B29"), todayOnContainer: c("#FFFFFF"),
                        error: c("#B3261E")
                    ),
                    dark: AppColors(
                        primary: c("#C0AEF0"), onPrimary: c("#2B1D4F"),
                        primaryContainer: c("#453072"), onPrimaryContainer: c("#E3DAF7"),
                        background: c("#14101D"), onBackground: c("#E6E2F0"),
                        surface: c("#1B1726"), onSurface: c("#E6E2F0"),
                        surfaceVariant: c("#231E32"), onSurfaceVariant: c("#B1A8C4"),
                        outline: c("#625873"), outlineVariant: c("#3E364D"),
                        gridLine: c("#2A2439"),
                        todayContainer: c("#E6E2F0"), todayOnContainer: c("#1F1B29"),
                        error: c("#F2B8B5")
                    )
                )
            case .orange:
                Swatch(
                    light: AppColors(
                        primary: c("#D0763B"), onPrimary: c("#FFFFFF"),
                        primaryContainer: c("#FCDBC2"), onPrimaryContainer: c("#4A1F08"),
                        background: c("#FAF5EE"), onBackground: c("#24201A"),
                        surface: c("#FFFFFF"), onSurface: c("#24201A"),
                        surfaceVariant: c("#EFE5D6"), onSurfaceVariant: c("#6E6555"),
                        outline: c("#C2B59C"), outlineVariant: c("#E0D6C2"),
                        gridLine: c("#EBE3D7"),
                        todayContainer: c("#24201A"), todayOnContainer: c("#FFFFFF"),
                        error: c("#B3261E")
                    ),
                    dark: AppColors(
                        primary: c("#EFB48A"), onPrimary: c("#4A1F08"),
                        primaryContainer: c("#6D391A"), onPrimaryContainer: c("#FCDBC2"),
                        background: c("#1A1611"), onBackground: c("#EEE7DC"),
                        surface: c("#221C15"), onSurface: c("#EEE7DC"),
                        surfaceVariant: c("#2D261C"), onSurfaceVariant: c("#C0B49E"),
                        outline: c("#6E6555"), outlineVariant: c("#463E2F"),
                        gridLine: c("#332C22"),
                        todayContainer: c("#EEE7DC"), todayOnContainer: c("#24201A"),
                        error: c("#F2B8B5")
                    )
                )
            case .pink:
                Swatch(
                    light: AppColors(
                        primary: c("#C25B7D"), onPrimary: c("#FFFFFF"),
                        primaryContainer: c("#FAD7DF"), onPrimaryContainer: c("#4A0F1F"),
                        background: c("#FAF4F6"), onBackground: c("#261A20"),
                        surface: c("#FFFFFF"), onSurface: c("#261A20"),
                        surfaceVariant: c("#F1E4E9"), onSurfaceVariant: c("#735865"),
                        outline: c("#C9B0BA"), outlineVariant: c("#E5D2DA"),
                        gridLine: c("#EEE2E7"),
                        todayContainer: c("#261A20"), todayOnContainer: c("#FFFFFF"),
                        error: c("#B3261E")
                    ),
                    dark: AppColors(
                        primary: c("#EFA9BD"), onPrimary: c("#4A0F1F"),
                        primaryContainer: c("#73314A"), onPrimaryContainer: c("#FAD7DF"),
                        background: c("#1B1216"), onBackground: c("#EFE0E5"),
                        surface: c("#231A1F"), onSurface: c("#EFE0E5"),
                        surfaceVariant: c("#302229"), onSurfaceVariant: c("#C4ADB6"),
                        outline: c("#735865"), outlineVariant: c("#483038"),
                        gridLine: c("#34262D"),
                        todayContainer: c("#EFE0E5"), todayOnContainer: c("#261A20"),
                        error: c("#F2B8B5")
                    )
                )
            }
        }
    }
}

private func c(_ hex: String) -> Color {
    RGBColor(hex: hex)!.color
}

enum AppFont {
    static let appTitle = Font.system(size: 22, weight: .bold)
    static let title = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 14)
    static let bodySmall = Font.system(size: 12)
    static let label = Font.system(size: 11)
    static let cardTitle = Font.system(size: 14, weight: .semibold)
    static let cardCaption = Font.system(size: 10)
}

extension View {
    func appFill(_ color: Color) -> some View {
        background(color)
    }
}
