import Charts
import SwiftUI
import UIKit

/// Applique `Theme` aux éléments que SwiftUI ne laisse pas styler directement.
extension Theme {
    /// Chiffres clés en SF Rounded, qui suivent la taille de texte choisie dans Réglages.
    static func number(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded, weight: .semibold).monospacedDigit()
    }

    /// Titres d'écran en New York : la barre de navigation n'a pas d'équivalent SwiftUI.
    static func applyNavigationBarFonts() {
        let ink = UIColor(Theme.ink)
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: serifFont(.largeTitle), .foregroundColor: ink,
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: serifFont(.headline), .foregroundColor: ink,
        ]
    }

    private static func serifFont(_ style: UIFont.TextStyle) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: serif, size: size)
    }
}

/// Place d'une ligne dans sa carte : seules les extrémités sont arrondies.
enum CardRowPosition {
    case single, top, middle, bottom

    static func at(_ index: Int, of count: Int) -> CardRowPosition {
        if count == 1 { return .single }
        if index == 0 { return .top }
        return index == count - 1 ? .bottom : .middle
    }
}

extension View {
    /// Carte `surface` sur fond `bg`, sans ombre, rayon `Theme.radius`. Une section de liste = une carte.
    func cardRow(_ position: CardRowPosition = .single) -> some View {
        let top = position == .single || position == .top ? Theme.radius : 0
        let bottom = position == .single || position == .bottom ? Theme.radius : 0
        return listRowBackground(
            UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                                   bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous)
                .fill(Theme.surface)
        )
        .listRowSeparatorTint(Theme.line)
    }

    /// Fond `bg` derrière une `List` ou un `Form`.
    func themedList() -> some View {
        scrollContentBackground(.hidden)
            // Le fond passe sous le clavier et la barre d'onglets : sans ça, une bande noire apparaît en sombre.
            .background(Theme.bg.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
    }

    /// Grille en `line`, axes en `ink-soft`.
    func themedChartAxes() -> some View {
        chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(Theme.inkSoft)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel().foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

/// En-tête de section discret, en `ink-soft`.
struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).foregroundStyle(Theme.inkSoft)
    }
}
