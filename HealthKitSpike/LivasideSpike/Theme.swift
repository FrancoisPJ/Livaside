import SwiftUI

extension Color {
    init(light: String, dark: String) {
        self.init(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

public enum Theme {
    public static let bg = Color(light: "#F6F3EE", dark: "#141413")
    public static let surface = Color(light: "#FFFFFF", dark: "#1F1E1C")
    public static let ink = Color(light: "#1C1B19", dark: "#F3F0EA")
    public static let inkSoft = Color(light: "#6B675F", dark: "#A8A39A")
    public static let line = Color(light: "#E4DFD6", dark: "#2E2C29")
    
    public static let sauge = Color(light: "#3F6B4E", dark: "#8FBF9C")
    
    public static let sleep = Color(light: "#5A5FC4", dark: "#9A9DF2")
    public static let sport = Color(light: "#C8643C", dark: "#EE9A74")
    public static let nutrition = Color(light: "#4E8F5F", dark: "#86C496")
    public static let weight = Color(light: "#3A74A8", dark: "#82B3DE")

    public static let radius: CGFloat = 20
    
    public static func spacing(_ multiplier: Int) -> CGFloat {
        return CGFloat(multiplier * 8)
    }

    public static func titleFont(size: CGFloat) -> Font {
        return .system(size: size, weight: .semibold, design: .serif)
    }
    
    public static func numberFont(size: CGFloat) -> Font {
        return .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
