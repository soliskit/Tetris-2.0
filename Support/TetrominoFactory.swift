import SwiftUI

@MainActor
struct TetrominoFactory {

    private static var bag: [Tetromino] = []

    static func generate() -> Tetromino {
        if bag.isEmpty {
            bag = allPieces().shuffled()
        }
        return bag.removeFirst()
    }

    // MARK: - SRS Wall Kick Data
    // Offsets are Position(row, column) where +row = down, +col = right.
    // Derived from the SRS spec: (x, y) with +x = right, +y = up → Position(row: -y, column: x).

    /// JLSTZ wall kick offsets for clockwise rotation from each state.
    private static let jlstzWallKicks: [[Position]] = [
        // 0→R
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: -1, column: -1), Position(row: 2, column: 0), Position(row: 2, column: -1)],
        // R→2
        [Position(row: 0, column: 0), Position(row: 0, column: 1), Position(row: 1, column: 1), Position(row: -2, column: 0), Position(row: -2, column: 1)],
        // 2→L
        [Position(row: 0, column: 0), Position(row: 0, column: 1), Position(row: -1, column: 1), Position(row: 2, column: 0), Position(row: 2, column: 1)],
        // L→0
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: 1, column: -1), Position(row: -2, column: 0), Position(row: -2, column: -1)]
    ]

    /// I-piece wall kick offsets for clockwise rotation from each state.
    private static let iWallKicks: [[Position]] = [
        // 0→R
        [Position(row: 0, column: 0), Position(row: 0, column: -2), Position(row: 0, column: 1), Position(row: 1, column: -2), Position(row: -2, column: 1)],
        // R→2
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: 0, column: 2), Position(row: -2, column: -1), Position(row: 1, column: 2)],
        // 2→L
        [Position(row: 0, column: 0), Position(row: 0, column: 2), Position(row: 0, column: -1), Position(row: -1, column: 2), Position(row: 2, column: -1)],
        // L→0
        [Position(row: 0, column: 0), Position(row: 0, column: 1), Position(row: 0, column: -2), Position(row: 2, column: 1), Position(row: -1, column: -2)]
    ]

    private static func allPieces() -> [Tetromino] {
        [
            piece(["....", "XXXX", "....", "...."], color: .cyan, kicks: iWallKicks),
            piece(["XX", "XX"], color: .yellow, kicks: [[Position(row: 0, column: 0)]]),
            piece([".X.", "XXX", "..."], color: .purple, kicks: jlstzWallKicks),
            piece([".XX", "XX.", "..."], color: .green, kicks: jlstzWallKicks),
            piece(["XX.", ".XX", "..."], color: .red, kicks: jlstzWallKicks),
            piece(["X..", "XXX", "..."], color: .blue, kicks: jlstzWallKicks),
            piece(["..X", "XXX", "..."], color: .orange, kicks: jlstzWallKicks)
        ]
    }

    /// Builds a piece from its spawn shape, where "X" is a block. Each further
    /// rotation state is the one before turned 90 degrees clockwise, one state
    /// per row of wall kicks, so the O piece (one row of kicks) never turns.
    private static func piece(_ spawn: [String], color: Color, kicks: [[Position]]) -> Tetromino {
        var rotations = [spawn.map { $0.map { $0 == "X" } }]
        while rotations.count < kicks.count {
            let last = rotations[rotations.count - 1]
            rotations.append(last.indices.map { row in last.indices.map { column in last[last.count - 1 - column][row] } })
        }
        return Tetromino(rotations: rotations, color: CustomColor(from: color), wallKickData: kicks)
    }
}
