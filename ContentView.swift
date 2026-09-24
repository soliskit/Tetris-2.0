import SwiftUI

struct ContentView: View {
    @State var gameManager = GameManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("highScore") private var highScore: Int = 0
    @State private var dragCellOffset: Int = 0
    @State private var dragRowOffset: Int = 0
    @State private var cellWidth: CGFloat = 32
    @State private var horizontalDragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    .indigo, .purple, .blue,
                    .blue, .cyan, .indigo,
                    .purple, .blue, .teal
                ]
            )
            .ignoresSafeArea()

            GlassEffectContainer {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Score: \(gameManager.score)")
                            .font(.title2.bold().monospacedDigit())
                        Text("High Score: \(highScore)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)

                    HStack(alignment: .top) {
                        TetrominoPreview(tetromino: gameManager.heldTetromino, size: 60)
                            .onTapGesture {
                                gameManager.handleAction(.hold)
                            }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(Array(gameManager.nextTetrominos.prefix(3).enumerated()), id: \.element.id) { index, tetromino in
                                TetrominoPreview(tetromino: tetromino, size: index == 0 ? 60 : 44)
                                    .opacity(index == 0 ? 1.0 : 0.6)
                            }
                        }
                    }

                    GameBoardView(gameManager: gameManager, horizontalDragOffset: horizontalDragOffset)
                        .aspectRatio(0.5, contentMode: .fit)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.width / 10
                        } action: { newValue in
                            cellWidth = newValue
                        }
                        .padding(8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { gesture in
                                    let newColOffset = Int(gesture.translation.width / cellWidth)
                                    let colDelta = newColOffset - dragCellOffset
                                    if colDelta != 0 {
                                        let action: PlayerAction = colDelta > 0 ? .moveRight : .moveLeft
                                        for _ in 0..<abs(colDelta) {
                                            gameManager.handleAction(action)
                                        }
                                        dragCellOffset = newColOffset
                                    }

                                    // Fractional offset within the current cell for smooth visual tracking
                                    let fractional = gesture.translation.width - CGFloat(dragCellOffset) * cellWidth
                                    let clamped = max(-cellWidth * 0.5, min(cellWidth * 0.5, fractional))

                                    // Clamp further so the piece doesn't visually leave the board
                                    let tetromino = gameManager.currentTetromino
                                    let leftmostCol = tetromino.shape.enumerated().reduce(Int.max) { result, row in
                                        let minInRow = row.element.enumerated().filter(\.element).map(\.offset).min() ?? Int.max
                                        return min(result, minInRow)
                                    }
                                    let rightmostCol = tetromino.shape.enumerated().reduce(Int.min) { result, row in
                                        let maxInRow = row.element.enumerated().filter(\.element).map(\.offset).max() ?? Int.min
                                        return max(result, maxInRow)
                                    }
                                    let leftPixelMargin = CGFloat(tetromino.position.column + leftmostCol) * cellWidth
                                    let rightPixelMargin = (CGFloat(10 - 1 - (tetromino.position.column + rightmostCol))) * cellWidth
                                    horizontalDragOffset = max(-leftPixelMargin, min(rightPixelMargin, clamped))

                                    let newRowOffset = max(0, Int(gesture.translation.height / cellWidth))
                                    let rowDelta = newRowOffset - dragRowOffset
                                    if rowDelta > 0 {
                                        for _ in 0..<rowDelta {
                                            gameManager.softDrop()
                                        }
                                        dragRowOffset = newRowOffset
                                    }
                                }
                                .onEnded { _ in
                                    dragCellOffset = 0
                                    dragRowOffset = 0
                                    withAnimation(.interpolatingSpring(duration: 0.08, bounce: 0)) {
                                        horizontalDragOffset = 0
                                    }
                                }
                        )
                        .onTapGesture {
                            gameManager.handleAction(.rotate)
                        }

                    ButtonView(gameManager: gameManager)
                }
                .padding()
            }
        }
        .background {
            KeyboardInputView(
                moveLeft: { gameManager.handleAction(.moveLeft) },
                moveRight: { gameManager.handleAction(.moveRight) },
                rotate: { gameManager.handleAction(.rotate) },
                drop: { gameManager.handleAction(.drop) },
                hold: { gameManager.handleAction(.hold) }
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Pausing also saves, so leaving the app keeps the run for Continue.
            if newPhase != .active, gameManager.state == .playing {
                gameManager.handleAction(.pause)
            }
        }
    }
}

#Preview("Content View") {
    ContentView(gameManager: GameManager())
}
