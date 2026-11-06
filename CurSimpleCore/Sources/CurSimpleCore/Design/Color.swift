import Foundation

public struct RGBColor: Hashable, Sendable {

    /// Components in 0...1.
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(argb: 0xFF00_0000 | number)
    }

    /// 0xAARRGGBB; alpha is ignored.
    public init(argb: UInt32) {
        self.init(
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255
        )
    }

    public var argb: UInt32 {
        0xFF00_0000
            | (UInt32((red * 255).rounded()) << 16)
            | (UInt32((green * 255).rounded()) << 8)
            | UInt32((blue * 255).rounded())
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    public var hsl: HSL {
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let lightness = (maxChannel + minChannel) / 2
        let delta = maxChannel - minChannel
        guard delta > 0 else { return HSL(hue: 0, saturation: 0, lightness: lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        switch maxChannel {
        case red:
            hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        case green:
            hue = 60 * ((blue - red) / delta + 2)
        default:
            hue = 60 * ((red - green) / delta + 4)
        }
        return HSL(hue: (hue + 360).truncatingRemainder(dividingBy: 360), saturation: saturation, lightness: lightness)
    }

    public init(hsl: HSL) {
        let chroma = (1 - abs(2 * hsl.lightness - 1)) * hsl.saturation
        let prime = ((hsl.hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 60
        let x = chroma * (1 - abs(prime.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        switch prime {
        case ..<1: (r, g, b) = (chroma, x, 0)
        case ..<2: (r, g, b) = (x, chroma, 0)
        case ..<3: (r, g, b) = (0, chroma, x)
        case ..<4: (r, g, b) = (0, x, chroma)
        case ..<5: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        let m = hsl.lightness - chroma / 2
        self.init(red: r + m, green: g + m, blue: b + m)
    }

    public func withLightness(_ lightness: Double) -> RGBColor {
        let values = hsl
        return RGBColor(hsl: HSL(hue: values.hue, saturation: values.saturation, lightness: lightness))
    }

    public func withSaturation(_ saturation: Double) -> RGBColor {
        let values = hsl
        return RGBColor(hsl: HSL(hue: values.hue, saturation: saturation, lightness: values.lightness))
    }

    public func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let t = min(max(amount, 0), 1)
        return RGBColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }
}

public struct HSL: Hashable, Sendable {
    public var hue: Double        // 0..<360
    public var saturation: Double // 0...1
    public var lightness: Double  // 0...1

    public init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = min(max(saturation, 0), 1)
        self.lightness = min(max(lightness, 0), 1)
    }
}
