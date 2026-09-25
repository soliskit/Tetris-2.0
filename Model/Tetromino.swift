import Foundation

/// Represents a Tetromino, the game pieces used in Tetris.
///
/// A Tetromino has a specific shape, color, position on the game board, and can be rotated.
struct Tetromino: Identifiable, Equatable, Codable, Sendable {
    /// A unique identifier for each Tetromino instance.
    var id = UUID()
    /// The 2D array representing the Tetromino's shape, where `true` indicates a block is present.
    var shape: [[Bool]]
    /// The color of the Tetromino.
    var color: CustomColor
    /// The current position of the Tetromino on the game board.
    var position = Position(row: 0, column: 0)
    /// An array of shapes representing all rotation states of the Tetromino.
    var rotations: [[[Bool]]]
    /// The index of the current rotation in the `rotations` array.
    var rotationState: Int = 0
    /// Data used for wall kicks when rotating near walls or other blocks.
    var wallKickData: [[Position]]

    init(rotations: [[[Bool]]], color: CustomColor, wallKickData: [[Position]]) {
        self.shape = rotations[0]
        self.color = color
        self.rotations = rotations
        self.wallKickData = wallKickData
    }

    /// This piece in its first rotation, centered at the top of a board `columns` wide.
    func spawned(columns: Int) -> Tetromino {
        var piece = self
        piece.shape = rotations[0]
        piece.rotationState = 0
        piece.position = Position(row: 0, column: max(0, (columns - (rotations[0].first?.count ?? 4)) / 2))
        return piece
    }

    /// Board positions of the blocks in `shape` when it sits at `position`.
    static func cells(of shape: [[Bool]], at position: Position) -> [Position] {
        shape.enumerated().flatMap { row, blocks in
            blocks.enumerated().compactMap { column, filled in
                filled ? Position(row: position.row + row, column: position.column + column) : nil
            }
        }
    }

    /// Board positions of this piece's blocks.
    var cells: [Position] { Self.cells(of: shape, at: position) }

    /// Whether `shape` at `position` stays on the board without overlapping filled cells.
    static func fits(_ shape: [[Bool]], at position: Position, in gameBoard: [[GameCell]]) -> Bool {
        cells(of: shape, at: position).allSatisfy { gameBoard[safeRow: $0.row, safeColumn: $0.column]?.isFilled == false }
    }

    /// Whether this piece fits on the board at `position`, or where it is now.
    func fits(in gameBoard: [[GameCell]], at position: Position? = nil) -> Bool {
        Self.fits(shape, at: position ?? self.position, in: gameBoard)
    }

    /// Rotates the Tetromino clockwise, trying each wall kick in turn. If no
    /// kick fits, it tries counterclockwise, whose kicks are the reverse of the
    /// clockwise kicks into the state it's leaving.
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
