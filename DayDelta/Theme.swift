import SwiftUI
import UIKit

/// App-wide UI constants. One corner radius so every rounded container matches.
enum UI { static let radius: CGFloat = 20 }

/// Palette offered for category and account colors (drives the Stats donut).
let categoryColors = [
    "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#84CC16", "#22C55E",
    "#10B981", "#14B8A6", "#06B6D4", "#0EA5E9", "#4F9DFF", "#3B82F6",
    "#6366F1", "#8B5CF6", "#A855F7", "#D946EF", "#EC4899", "#F43F5E",
    "#78716C", "#9CA3AF",
]

/// Shared animation feel so every transition and number roll moves uniformly
/// (runs at the display's native refresh — 120Hz on ProMotion, enabled in project.yml).
enum Motion {
    static let quick = Animation.snappy(duration: 0.35)
    static let smooth = Animation.snappy(duration: 0.45)
}

/// A transparent page header: a large title with optional trailing controls.
/// Replaces NavigationStack chrome on the paged tabs so they stay see-through and
/// the single root background shows behind every page.
struct PageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded)).fontWeight(.bold)
                .foregroundStyle(Color.appInk)
            Spacer()
            // One size/color for every page's header controls.
            trailing
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appInk)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

extension Color {
    /// "#RRGGBB" for persisting a chosen color. Pairs with `Color(hex:)`.
    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    /// "#RRGGBBAA" preserving alpha — for colors that can be transparent.
    func toHexA() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)), Int(round(a * 255)))
    }

    /// A lighter, slightly less saturated variant — used to build accent gradients.
    func lighter(_ amount: Double = 0.3) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: max(0, Double(s) - amount * 0.6),
                     brightness: min(1, Double(b) + amount))
    }
}

/// A two-stop gradient from a lighter tint to the accent color.
func accentGradient(_ hex: String) -> LinearGradient {
    let c = Color(hex: hex)
    return LinearGradient(colors: [c.lighter(0.3), c], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// Fill a component frame with the user-chosen panel color + a hairline edge.
    /// Used app-wide (cards, tab bar, keypad) so one color drives them all.
    func panel(_ radius: CGFloat = UI.radius) -> some View {
        background(RoundedRectangle(cornerRadius: radius).fill(Color.appPanel))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.appInk.opacity(0.15)))
    }
}

extension View {
    /// iOS 26 "Liquid Glass" background clipped to `shape`; frosted-material
    /// fallback on older systems. Used for every panel so the app matches the
    /// native glass look.
    @ViewBuilder
    func liquidGlass(_ shape: some Shape, clear: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else if clear {
            // Maximum see-through: just the thin blur + a hairline edge.
            self.background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.5))
        } else {
            // Thin, light frost: a faint white behind the blur lifts it off the
            // dark background, with an Apple-style hairline edge.
            self.background(shape.fill(.white.opacity(0.12)))
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
    }

    /// Rounded-rect liquid glass (default corner radius).
    func liquidGlass(_ radius: CGFloat = UI.radius, clear: Bool = false) -> some View {
        liquidGlass(RoundedRectangle(cornerRadius: radius), clear: clear)
    }
}

/// Relative luminance (WCAG) of a "#RRGGBB" color, 0 (black) … 1 (white).
func relativeLuminance(_ hex: String) -> Double {
    let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard s.count == 6, let v = UInt64(s, radix: 16) else { return 0 }
    func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    let r = lin(Double((v >> 16) & 0xFF) / 255)
    let g = lin(Double((v >> 8) & 0xFF) / 255)
    let b = lin(Double(v & 0xFF) / 255)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

extension Color {
    /// Maximum-contrast ink (white or black) for the chosen background color, so
    /// text and graphics are never swallowed by it. Reads the stored background.
    static var appInk: Color {
        let hex = UserDefaults.standard.string(forKey: "accountsBgHex") ?? "#5227FF"
        return relativeLuminance(hex) > 0.45 ? .black : .white
    }

    /// The user-chosen component panel color (cards, tab bar, keypad, …). "#RRGGBBAA".
    static var appPanel: Color {
        Color(hex: UserDefaults.standard.string(forKey: "panelHex") ?? "#FFFFFF26")
    }

    /// "#RRGGBB" or "#RRGGBBAA" -> Color. Falls back to gray on a malformed string.
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let v = UInt64(s, radix: 16) else { self = .gray; return }
        if s.count == 8 {
            self = Color(.sRGB,
                red: Double((v >> 24) & 0xFF) / 255,
                green: Double((v >> 16) & 0xFF) / 255,
                blue: Double((v >> 8) & 0xFF) / 255,
                opacity: Double(v & 0xFF) / 255)
        } else if s.count == 6 {
            self = Color(
                red: Double((v >> 16) & 0xFF) / 255,
                green: Double((v >> 8) & 0xFF) / 255,
                blue: Double(v & 0xFF) / 255)
        } else {
            self = .gray
        }
    }
}
