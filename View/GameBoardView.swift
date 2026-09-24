import SwiftUI

struct GameBoardView: View {
    private let rows: Int = 20
    private let columns: Int = 10
    var gameManager: GameManager
    /// Fractional horizontal drag offset in points, applied visually to the active piece.
    var horizontalDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let blockSize = calculateBlockSize(from: geometry.size)
            let boardDimensions = calculateBoardDimensions(blockSize: blockSize)
            ZStack {
                GridLinesView(columns: columns, rows: rows, blockSize: blockSize, boardWidth: boardDimensions.width, boardHeight: boardDimensions.height)

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        if let cell = gameManager.gameBoard[safeRow: row, safeColumn: column], cell.isFilled == true {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cell.color?.value ?? .clear)
                                .frame(width: blockSize - 1, height: blockSize - 1)
                                .position(x: blockSize * CGFloat(column) + blockSize / 2, y: blockSize * CGFloat(row) + blockSize / 2)
                        }
                    }
                }

                // Ghost piece
                let ghostCells = gameManager.ghostCells()
                let ghostColor = gameManager.currentTetromino.color.value
                ForEach(0..<ghostCells.count, id: \.self) { index in
                    let cell = ghostCells[index]
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(ghostColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: blockSize - 1, height: blockSize - 1)
                        .position(x: blockSize * CGFloat(cell.col) + blockSize / 2,
                                  y: blockSize * CGFloat(cell.row) + blockSize / 2)
                }                                                     

                let tetromino = gameManager.currentTetromino
                ForEach(0..<tetromino.shape.count, id: \.self) { row in
                    ForEach(0..<tetromino.shape[row].count, id: \.self) { column in
                        if tetromino.shape[row][column] {
                            let tetrominoColumn = CGFloat(tetromino.position.column + column)
                            let tetrominoRow = CGFloat(tetromino.position.row + row)

                            if tetrominoColumn >= 0, tetrominoColumn < CGFloat(columns), tetrominoRow >= 0, tetrominoRow < CGFloat(rows) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(tetromino.color.value)
                                    .frame(width: blockSize - 1, height: blockSize - 1)
                                    .position(x: blockSize * tetrominoColumn + blockSize / 2 + horizontalDragOffset,
                                              y: blockSize * tetrominoRow + blockSize / 2)
                                    .animation(.interpolatingSpring(duration: 0.12, bounce: 0), value: tetromino.position.row)
                            }
                        }
                    }
                }
                .frame(width: boardDimensions.width, height: boardDimensions.height)
            }
        }
    }

    private func calculateBlockSize(from size: CGSize) -> CGFloat {
        min(size.width / CGFloat(columns), size.height / CGFloat(rows))
    }

    private func calculateBoardDimensions(blockSize: CGFloat) -> CGSize {
        CGSize(width: blockSize * CGFloat(columns), height: blockSize * CGFloat(rows))
    }
}

struct GridLinesView: View {
    let columns: Int
    let rows: Int
    let blockSize: CGFloat
    let boardWidth: CGFloat
    let boardHeight: CGFloat

    var body: some View {
        Path { path in
            for column in 1..<columns {
                let x = blockSize * CGFloat(column)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: boardHeight))
            }
            for row in 1..<rows {
                let y = blockSize * CGFloat(row)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: boardWidth, y: y))
            }
        }
        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
    }
}
