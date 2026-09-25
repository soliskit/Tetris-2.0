import Foundation

struct Tetromino: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var shape: [[Bool]]
    var color: CustomColor
    var position = Position(row: 0, column: 0)
    var rotations: [[[Bool]]]
    var rotationState: Int = 0
    var wallKickData: [[Position]]

    init(rotations: [[[Bool]]], color: CustomColor, wallKickData: [[Position]]) {
        self.shape = rotations[0]
        self.color = color
        self.rotations = rotations
        self.wallKickData = wallKickData
    }

    func spawned(columns: Int) -> Tetromino {
        var piece = self
        piece.shape = rotations[0]
        piece.rotationState = 0
        piece.position = Position(row: 0, column: max(0, (columns - (rotations[0].first?.count ?? 4)) / 2))
        return piece
    }

    static func cells(of shape: [[Bool]], at position: Position) -> [Position] {
        shape.enumerated().flatMap { row, blocks in
            blocks.enumerated().compactMap { column, filled in
                filled ? Position(row: position.row + row, column: position.column + column) : nil
            }
        }
    }

    var cells: [Position] { Self.cells(of: shape, at: position) }

    static func fits(_ shape: [[Bool]], at position: Position, in gameBoard: [[GameCell]]) -> Bool {
        cells(of: shape, at: position).allSatisfy { gameBoard[safeRow: $0.row, safeColumn: $0.column]?.isFilled == false }
    }

    func fits(in gameBoard: [[GameCell]], at position: Position? = nil) -> Bool {
        Self.fits(shape, at: position ?? self.position, in: gameBoard)
    }

    mutating func rotate(gameBoard: [[GameCell]]) {
        let count = rotations.count
        let clockwise = (rotationState + 1) % count
        let counterClockwise = (rotationState + count - 1) % count
        let attempts = [
            (clockwise, wallKickData[rotationState]),
            (counterClockwise, wallKickData[counterClockwise].map { Position(row: -$0.row, column: -$0.column) })
        ]
        for (state, kicks) in attempts {
            for kick in kicks {
                let candidate = Position(row: position.row + kick.row, column: position.column + kick.column)
                if Self.fits(rotations[state], at: candidate, in: gameBoard) {
                    shape = rotations[state]
                    rotationState = state
                    position = candidate
                    return
                }
            }
        }
    }
}
