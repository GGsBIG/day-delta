import SwiftUI
import UIKit

/// A custom color picker: swatch header, a saturation/brightness area, a hue
/// slider, a hex field, a text-contrast readout, and saved swatches. Writes the
/// chosen color back as a "#RRGGBB" hex. Modeled on the reference layout.
struct ColorPickerPanel: View {
    @Binding var hex: String
    @Environment(\.dismiss) private var dismiss

    @State private var h = 0.0   // hue 0…1
    @State private var s = 1.0   // saturation 0…1
    @State private var b = 1.0   // brightness 0…1
    @AppStorage("bgSwatches") private var swatchesCSV = "#5227FF,#2563EB,#EF4444,#22C55E,#F59E0B,#A855F7"

    private var current: Color { Color(hue: h, saturation: s, brightness: b) }
    private var currentHex: String { hexString(h: h, s: s, b: b) }
    private var swatches: [String] { swatchesCSV.split(separator: ",").map(String.init) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            saturationArea.frame(height: 200)
            hueSlider.frame(height: 28)
            hexField
            contrastRow
            swatchRow
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.07).ignoresSafeArea())
        .foregroundStyle(.white)
        .tint(.white)
        .onAppear(perform: load)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(current).frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
            VStack(alignment: .leading, spacing: 1) {
                Text("Background").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                Text(currentHex).font(.system(.headline, design: .rounded)).bold()
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "checkmark").font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Saturation / brightness area

    private var saturationArea: some View {
        GeometryReader { geo in
            let w = geo.size.width, ht = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(hue: h, saturation: 1, brightness: 1)
                LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: UI.radius))
            .overlay(alignment: .topLeading) {
                thumb(current).position(x: s * w, y: (1 - b) * ht)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                s = min(max(v.location.x / w, 0), 1)
                b = 1 - min(max(v.location.y / ht, 0), 1)
                commit()
            })
        }
    }

    // MARK: Hue slider

    private var hueSlider: some View {
        GeometryReader { geo in
            let w = geo.size.width
            RoundedRectangle(cornerRadius: UI.radius)
                .fill(LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 6)
                    .map { Color(hue: $0, saturation: 1, brightness: 1) },
                    startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .leading) {
                    thumb(Color(hue: h, saturation: 1, brightness: 1)).position(x: h * w, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    h = min(max(v.location.x / w, 0), 1); commit()
                })
        }
    }

    private func thumb(_ fill: Color) -> some View {
        Circle().fill(fill).frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.3), radius: 2)
    }

    // MARK: Hex field

    private var hexField: some View {
        HStack(spacing: 10) {
            Text("Hex").font(.system(.subheadline, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: UI.radius).fill(.white.opacity(0.08)))
            TextField("#RRGGBB", text: Binding(get: { currentHex }, set: { apply($0) }))
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: UI.radius).strokeBorder(.white.opacity(0.12)))
        }
    }

    // MARK: Contrast readout (how readable text is on this background)

    private var contrastRow: some View {
        let lum = relativeLuminance(currentHex)
        let ratio = max((1.05) / (lum + 0.05), (lum + 0.05) / 0.05)
        let grade = ratio >= 7 ? "AAA" : ratio >= 4.5 ? "AA" : ratio >= 3 ? "AA large" : "Fail"
        return HStack(spacing: 12) {
            Text("Aa").font(.system(.headline, design: .rounded)).bold()
                .foregroundStyle(lum > 0.45 ? .black : .white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: UI.radius).fill(current))
            Text(String(format: "%.2f:1", ratio)).font(.system(.body, design: .rounded)).bold()
            Text("text contrast").font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(grade).font(.system(.subheadline, design: .rounded)).bold()
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: UI.radius)
                    .fill((grade == "Fail" ? Color.red : Color.green).opacity(0.25)))
                .foregroundStyle(grade == "Fail" ? .red : .green)
        }
    }

    // MARK: Saved swatches

    private var swatchRow: some View {
        HStack(spacing: 12) {
            Button(action: saveSwatch) {
                Image(systemName: "plus").font(.headline).foregroundStyle(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background(Circle().strokeBorder(.white.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [3])))
            }
            .buttonStyle(.plain)
            ForEach(swatches, id: \.self) { hx in
                let on = hx.uppercased() == currentHex
                Circle().fill(Color(hex: hx)).frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(.white, lineWidth: on ? 2.5 : 0))
                    .onTapGesture { apply(hx) }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Logic

    private func load() {
        var hh: CGFloat = 0, ss: CGFloat = 0, bb: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: hex)).getHue(&hh, saturation: &ss, brightness: &bb, alpha: &a)
        h = Double(hh); s = Double(ss); b = Double(bb)
    }

    /// Push the current HSB to the bound hex.
    private func commit() { hex = currentHex }

    /// Accept a typed or tapped hex, update sliders + binding.
    private func apply(_ text: String) {
        let t = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard t.count == 6, UInt64(t, radix: 16) != nil else { return }
        var hh: CGFloat = 0, ss: CGFloat = 0, bb: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: "#" + t)).getHue(&hh, saturation: &ss, brightness: &bb, alpha: &a)
        h = Double(hh); s = Double(ss); b = Double(bb)
        commit()
    }

    private func saveSwatch() {
        let hx = currentHex
        var list = swatches.filter { $0.uppercased() != hx }
        list.insert(hx, at: 0)
        swatchesCSV = list.prefix(8).joined(separator: ",")
    }

    private func hexString(h: Double, s: Double, b: Double) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        UIColor(hue: h, saturation: s, brightness: b, alpha: 1).getRed(&r, green: &g, blue: &bl, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(bl * 255)))
    }
}
