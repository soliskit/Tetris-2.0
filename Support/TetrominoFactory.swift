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
        return [
            // I Shape — 4 rotation states
            Tetromino(
                shape: [[false, false, false, false], [true, true, true, true], [false, false, false, false], [false, false, false, false]],
                color: CustomColor(from: .cyan),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[false, false, false, false], [true, true, true, true], [false, false, false, false], [false, false, false, false]],
                    [[false, false, true, false], [false, false, true, false], [false, false, true, false], [false, false, true, false]],
                    [[false, false, false, false], [false, false, false, false], [true, true, true, true], [false, false, false, false]],
                    [[false, true, false, false], [false, true, false, false], [false, true, false, false], [false, true, false, false]]
                ],
                wallKickData: iWallKicks
            ),
            // O Shape
            Tetromino(
                shape: [[true, true], [true, true]],
                color: CustomColor(from: .yellow),
                position: Position(row: 0, column: 4),
                rotations: [
                    [[true, true], [true, true]]
                ],
                wallKickData: [
                    [Position(row: 0, column: 0)]
                ]
            ),
            // T Shape
            Tetromino(
                shape: [[false, true, false], [true, true, true], [false, false, false]],
                color: CustomColor(from: .purple),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[false, true, false], [true, true, true], [false, false, false]],
                    [[false, true, false], [false, true, true], [false, true, false]],
                    [[false, false, false], [true, true, true], [false, true, false]],
                    [[false, true, false], [true, true, false], [false, true, false]]
                ],
                wallKickData: jlstzWallKicks
            ),
            // S Shape
            Tetromino(
                shape: [[false, true, true], [true, true, false], [false, false, false]],
                color: CustomColor(from: .green),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[false, true, true], [true, true, false], [false, false, false]],
                    [[false, true, false], [false, true, true], [false, false, true]],
                    [[false, false, false], [false, true, true], [true, true, false]],
                    [[true, false, false], [true, true, false], [false, true, false]]
                ],
                wallKickData: jlstzWallKicks
            ),
            // Z Shape
            Tetromino(
                shape: [[true, true, false], [false, true, true], [false, false, false]],
                color: CustomColor(from: .red),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[true, true, false], [false, true, true], [false, false, false]],
                    [[false, false, true], [false, true, true], [false, true, false]],
                    [[false, false, false], [true, true, false], [false, true, true]],
                    [[false, true, false], [true, true, false], [true, false, false]]
                ],
                wallKickData: jlstzWallKicks
            ),
            // J Shape
            Tetromino(
                shape: [[true, false, false], [true, true, true], [false, false, false]],
                color: CustomColor(from: .blue),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[true, false, false], [true, true, true], [false, false, false]],
                    [[false, true, true], [false, true, false], [false, true, false]],
                    [[false, false, false], [true, true, true], [false, false, true]],
                    [[false, true, false], [false, true, false], [true, true, false]]
                ],
                wallKickData: jlstzWallKicks
            ),
            // L Shape
            Tetromino(
                shape: [[false, false, true], [true, true, true], [false, false, false]],
                color: CustomColor(from: .orange),
                position: Position(row: 0, column: 3),
                rotations: [
                    [[false, false, true], [true, true, true], [false, false, false]],
                    [[false, true, false], [false, true, false], [false, true, true]],
                    [[false, false, false], [true, true, true], [true, false, false]],
                    [[true, true, false], [false, true, false], [false, true, false]]
                ],
                wallKickData: jlstzWallKicks
            )
        ]
    }
}
