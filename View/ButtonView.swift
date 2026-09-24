import SwiftUI

struct ButtonView: View {
    @AppStorage("isSessionSaved") private var isSessionSaved: Bool = false
    var gameManager: GameManager

    var body: some View {
        HStack {
            if gameManager.state == .gameOver {
                VStack(spacing: 8) {
                    HStack {
                        Button("New Game") {
                            gameManager.handleAction(.newGame)
                        }
                        .buttonStyle(GameControlButtonStyle())
                        if isSessionSaved {
                            Button("Continue") {
                                gameManager.handleAction(.continueGame)
                            }
                            .buttonStyle(GameControlButtonStyle())
                        }
                    }
                    // Only shown once GameController reports a keyboard, so it
                    // also tells you the game can see yours.
                    if gameManager.isKeyboardConnected {
                        Text(isSessionSaved ? "Return: New Game    C: Continue" : "Return: New Game")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            } else {
                Spacer()
                if gameManager.state == .paused {
                    Button(action: {
                        gameManager.handleAction(.resume)
                    }, label: {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.white)
                    })
                    .glassEffect(.regular, in: .circle)
                } else if gameManager.state == .playing {
                    Button(action: {
                        gameManager.handleAction(.pause)
                    }, label: {
                        Image(systemName: "pause.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.white)
                    })
                    .glassEffect(.regular, in: .circle)
                }
            }
        }
    }
}

#Preview("Button View") {
    ButtonView(gameManager: GameManager())
}
