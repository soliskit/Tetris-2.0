import SwiftUI

struct ContentView: View {
    var gameManager: GameManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("highScore") private var highScore: Int = 0
    @State private var dragStartLocation: CGPoint?
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
                                    if gesture.startLocation != dragStartLocation {
                                        resetDragState()
                                        dragStartLocation = gesture.startLocation
                                    }
                                    let newColOffset = Int(gesture.translation.width / cellWidth)
                                    let colDelta = newColOffset - dragCellOffset
                                    if colDelta != 0 {
                                        let action: PlayerAction = colDelta > 0 ? .moveRight : .moveLeft
                                        for _ in 0..<abs(colDelta) {
                                            gameManager.handleAction(action)
                                        }
                                        dragCellOffset = newColOffset
                                    }

                                    let fractional = gesture.translation.width - CGFloat(dragCellOffset) * cellWidth
                                    let clamped = max(-cellWidth * 0.5, min(cellWidth * 0.5, fractional))

                                    let pieceColumns = gameManager.currentTetromino.cells.map(\.column)
                                    let leftPixelMargin = CGFloat(pieceColumns.min() ?? 0) * cellWidth
                                    let rightPixelMargin = CGFloat(10 - 1 - (pieceColumns.max() ?? 9)) * cellWidth
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
                                    withAnimation(.interpolatingSpring(duration: 0.08, bounce: 0)) {
                                        resetDragState()
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            resetDragState()
            if gameManager.state == .playing {
                gameManager.handleAction(.pause)
            }
        }
    }

    private func resetDragState() {
        dragStartLocation = nil
        dragCellOffset = 0
        dragRowOffset = 0
        horizontalDragOffset = 0
    }
}

#Preview("Content View") {
    ContentView(gameManager: GameManager())
}
