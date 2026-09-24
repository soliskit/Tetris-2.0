import SwiftUI

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
    var position: Position
    /// An array of shapes representing all rotation states of the Tetromino.
    var rotations: [[[Bool]]]
    /// The index of the current rotation in the `rotations` array.
    var rotationState: Int = 0
    /// Data used for wall kicks when rotating near walls or other blocks.
    var wallKickData: [[Position]]
    
    /// Checks if the Tetromino fits within the given game board without overlapping filled cells.
    ///
    /// - Parameter gameBoard: A 2D array representing the game board, where each cell contains a `GameCell`.
    /// - Returns: A Boolean value indicating whether the Tetromino fits within the game board.
    func fitsWithin(gameBoard: [[GameCell]]) -> Bool {
        return !shape.enumerated().contains { rowIndex, row in
            row.enumerated().contains { columnIndex, block in
                guard block else { return false }
                let boardX = position.column + columnIndex
                let boardY = position.row + rowIndex
                guard let cell = gameBoard[safeRow: boardY, safeColumn: boardX] else { return true }
                return cell.isFilled
            }
        }
    }
    
    /// Rotates the Tetromino, attempting clockwise rotation first, then counter-clockwise if necessary.
    ///
    /// The method first tries to rotate the Tetromino clockwise. If the clockwise rotation doesn't fit,
    /// it attempts a counter-clockwise rotation. Wall kick data is used to test possible positions for each rotation.
    ///
    /// - Parameter gameBoard: A 2D array representing the game board to check for fit during rotation.
    mutating func rotate(gameBoard: [[GameCell]]) {
        let clockwiseRotationState = (rotationState + 1) % rotations.count
        let clockwiseShape = rotations[clockwiseRotationState]
        let clockwiseTestPositions = wallKickData[rotationState].map {
            Position(row: position.row + $0.row, column: position.column + $0.column)
        }
        if let validClockwisePosition = clockwiseTestPositions.first(where: {
            Tetromino(shape: clockwiseShape, color: color, position: $0, rotations: rotations, wallKickData: wallKickData)
                .fitsWithin(gameBoard: gameBoard)
        }) {
            shape = clockwiseShape
            rotationState = clockwiseRotationState
            position = validClockwisePosition
            return
        }
        
        let counterClockwiseRotationState = (rotationState - 1 + rotations.count) % rotations.count
        let counterClockwiseShape = rotations[counterClockwiseRotationState]
        let counterClockwiseTestPositions = wallKickData[counterClockwiseRotationState].map {
            Position(row: position.row - $0.row, column: position.column - $0.column)
        }
        
        for testPosition in counterClockwiseTestPositions {
            if Tetromino(shape: counterClockwiseShape, color: color, position: testPosition, rotations: rotations, wallKickData: wallKickData)
                .fitsWithin(gameBoard: gameBoard) {
                shape = counterClockwiseShape
                rotationState = counterClockwiseRotationState
                position = testPosition
                break
            }
        }
    }
}
