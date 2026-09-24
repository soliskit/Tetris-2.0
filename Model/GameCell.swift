import SwiftUI

/// Represents a single cell within the game board of a Tetris-like game.
///
/// Each `GameCell` can be in one of two states: filled or unfilled.
/// Filled cells are part of a tetromino that has landed and become part of the game board.
/// Each filled cell also has an associated color, representing the tetromino it was part of.
struct GameCell: Codable, Equatable, Sendable {
    /// Indicates whether the cell is filled (`true`) or empty (`false`).
    /// Filled cells are part of the static shapes on the game board.
    var isFilled: Bool = false
    /// The color of the cell, applicable if `isFilled` is `true`.
    /// This is `nil` for empty cells or until the cell becomes part of a settled tetromino.
    var color: CustomColor? = nil
}
