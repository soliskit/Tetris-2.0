import Foundation

struct GameSession: Codable, Sendable {
    var gameBoard: [[GameCell]]
    var score: Int
    var level: Int
    var currentTetromino: Tetromino
    var nextTetrominos: [Tetromino]
    var heldTetromino: Tetromino?
    var canHoldTetromino: Bool
}
