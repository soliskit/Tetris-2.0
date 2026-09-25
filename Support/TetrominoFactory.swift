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

    private static let jlstzWallKicks: [[Position]] = [
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: -1, column: -1), Position(row: 2, column: 0), Position(row: 2, column: -1)],
        [Position(row: 0, column: 0), Position(row: 0, column: 1), Position(row: 1, column: 1), Position(row: -2, column: 0), Position(row: -2, column: 1)],
        [Position(row: 0, column: 0), Position(row: 0, column: 1), Position(row: -1, column: 1), Position(row: 2, column: 0), Position(row: 2, column: 1)],
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: 1, column: -1), Position(row: -2, column: 0), Position(row: -2, column: -1)]
    ]

    private static let iWallKicks: [[Position]] = [
        [Position(row: 0, column: 0), Position(row: 0, column: -2), Position(row: 0, column: 1), Position(row: 1, column: -2), Position(row: -2, column: 1)],
        [Position(row: 0, column: 0), Position(row: 0, column: -1), Position(row: 0, column: 2), Position(row: -2, column: -1), Position(row: 1, column: 2)],
        [Position(row: 0, column: 0), Position(row: 0, column: 2), Position(row: 0, column: -1), Position(row: -1, column: 2), Position(row: 2, column: -1)],
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

    private static func piece(_ spawn: [String], color: Color, kicks: [[Position]]) -> Tetromino {
        var rotations = [spawn.map { $0.map { $0 == "X" } }]
        while rotations.count < kicks.count {
            let last = rotations[rotations.count - 1]
            rotations.append(last.indices.map { row in last.indices.map { column in last[last.count - 1 - column][row] } })
        }
        return Tetromino(rotations: rotations, color: CustomColor(from: color), wallKickData: kicks)
    }
}
