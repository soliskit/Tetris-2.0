import SwiftUI

struct GameBoardView: View {
    private let rows: Int = 20
    private let columns: Int = 10
    var gameManager: GameManager
    var horizontalDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let blockSize = min(geometry.size.width / CGFloat(columns), geometry.size.height / CGFloat(rows))
            let boardWidth = blockSize * CGFloat(columns)
            let boardHeight = blockSize * CGFloat(rows)
            ZStack {
                GridLinesView(columns: columns, rows: rows, blockSize: blockSize, boardWidth: boardWidth, boardHeight: boardHeight)

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        if let cell = gameManager.gameBoard[safeRow: row, safeColumn: column], cell.isFilled {
                            place(RoundedRectangle(cornerRadius: 3).fill(cell.color?.value ?? .clear), at: Position(row: row, column: column), size: blockSize)
                        }
                    }
                }

                let ghostCells = gameManager.ghostTetromino.cells
                let ghostColor = gameManager.currentTetromino.color.value
                ForEach(0..<ghostCells.count, id: \.self) { index in
                    place(RoundedRectangle(cornerRadius: 3).stroke(ghostColor.opacity(0.5), lineWidth: 1.5), at: ghostCells[index], size: blockSize)
                }

                let tetromino = gameManager.currentTetromino
                ZStack {
                    ForEach(Array(tetromino.cells.enumerated()), id: \.offset) { _, cell in
                        place(RoundedRectangle(cornerRadius: 3).fill(tetromino.color.value), at: cell, size: blockSize, xOffset: horizontalDragOffset)
                            .animation(.interpolatingSpring(duration: 0.12, bounce: 0), value: tetromino.position.row)
                    }
                    .frame(width: boardWidth, height: boardHeight)
                }
                .id(tetromino.id)
            }
        }
    }

    private func place(_ block: some View, at cell: Position, size: CGFloat, xOffset: CGFloat = 0) -> some View {
        block
            .frame(width: size - 1, height: size - 1)
            .position(x: size * CGFloat(cell.column) + size / 2 + xOffset, y: size * CGFloat(cell.row) + size / 2)
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
