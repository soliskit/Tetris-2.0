import SwiftUI

@main
struct MyApp: App {
    // Created once here. SwiftUI can build ContentView more than once, and a
    // default value there made an extra GameManager each time, and each one
    // took over the game controller.
    @State private var gameManager = GameManager()

    var body: some Scene {
        WindowGroup {
            ContentView(gameManager: gameManager)
        }
    }
}
