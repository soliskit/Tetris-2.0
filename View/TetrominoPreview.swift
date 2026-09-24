import SwiftUI

struct TetrominoPreview: View {
    private let columns: Int = 6
    private let rows: Int = 6
    var tetromino: Tetromino?
    var size: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            let blockSize = min(geometry.size.width / CGFloat(columns), geometry.size.height / CGFloat(rows))
            let boardWidth = blockSize * CGFloat(columns)
            let boardHeight = blockSize * CGFloat(rows)

            ZStack {
                if let shape = tetromino?.shape, let color = tetromino?.color.value {
                    let xOffset = (boardWidth - CGFloat(shape[0].count) * blockSize) / 2
                    let yOffset = (boardHeight - CGFloat(shape.count) * blockSize) / 2

                    ForEach(0..<shape.count, id: \.self) { row in
                        ForEach(0..<shape[row].count, id: \.self) { column in
                            if shape[row][column] {
                                RoundedRectangle(cornerRadius: 3)
                                    .foregroundColor(color)
                                    .frame(width: blockSize - 1, height: blockSize - 1)
                                    .offset(x: blockSize * CGFloat(column) + xOffset - boardWidth / 2 + blockSize / 2,
                                            y: blockSize * CGFloat(row) + yOffset - boardHeight / 2 + blockSize / 2)
                            }
                        }
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
