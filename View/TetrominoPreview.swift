import SwiftUI

struct TetrominoPreview: View {
    private let columns: Int = 6
    private let rows: Int = 6
    private let size: CGFloat = 60
    var tetromino: Tetromino?

    var body: some View {
        GeometryReader { geometry in
            let blockSize = min(geometry.size.width / CGFloat(columns), geometry.size.height / CGFloat(rows))
            let boardWidth = blockSize * CGFloat(columns)
            let boardHeight = blockSize * CGFloat(rows)

            ZStack {
                if let tetromino {
                    let cells = Tetromino.cells(of: tetromino.shape, at: Position(row: 0, column: 0))
                    let filledRows = cells.map(\.row)
                    let filledColumns = cells.map(\.column)
                    let centerRow = CGFloat((filledRows.min() ?? 0) + (filledRows.max() ?? 0)) / 2
                    let centerColumn = CGFloat((filledColumns.min() ?? 0) + (filledColumns.max() ?? 0)) / 2

                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tetromino.color.value)
                            .frame(width: blockSize - 1, height: blockSize - 1)
                            .offset(x: blockSize * (CGFloat(cell.column) - centerColumn),
                                    y: blockSize * (CGFloat(cell.row) - centerRow))
                    }
                }
            }
            .frame(width: boardWidth, height: boardHeight)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .clipped()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

#Preview("Tetronimo Preview") {
    TetrominoPreview(tetromino: TetrominoFactory.generate())
}
