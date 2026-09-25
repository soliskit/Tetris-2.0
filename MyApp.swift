import SwiftUI

@main
struct MyApp: App {
    @State private var gameManager = GameManager()

    var body: some Scene {
        WindowGroup {
            ContentView(gameManager: gameManager)
        }
    }
}
