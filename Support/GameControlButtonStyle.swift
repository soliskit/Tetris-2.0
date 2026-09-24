import SwiftUI

struct GameControlButtonStyle: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .font(.headline)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .glassEffect(.regular, in: .capsule)
    }
}
