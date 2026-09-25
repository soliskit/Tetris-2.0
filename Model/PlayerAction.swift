/// Represents actions a player can take during the game.
///
/// This enum encapsulates the different types of inputs a player can provide while playing.
/// It includes movements and rotations of the current tetromino, holding a tetromino, and game control actions like pausing and resuming the game.
enum PlayerAction: Sendable {
    /// Starts a new game, resetting the game state and board.
    case newGame
    /// Continues a saved game from where it was left off.
    case continueGame
    /// Freezes the game state, allowing players to take a break or plan their next moves.
    case pause
    /// Ensures the game can be restarted right where the player left off without losing progress.
    case resume
    /// Useful for navigating through tighter spaces or aligning for a better position.
    case moveLeft
    /// Similar to moveLeft, it aids in precise positioning of the Tetromino.
    case moveRight
    /// This action allows players to save a Tetromino for later use, which can be strategic for planning future moves.
    case hold
    /// Rotation is key for maximizing space utilization and completing lines.
    case rotate
    /// This can be used to accelerate the game pace or to quickly lock a Tetromino in place.
    case drop
}
