import SwiftUI

struct CustomColor: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    var value: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(from color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        self.red = Double(resolved.red)
        self.green = Double(resolved.green)
        self.blue = Double(resolved.blue)
        self.opacity = Double(resolved.opacity)
    }
}
