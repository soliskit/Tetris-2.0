import Foundation

/// Represents the current state of the game.
///
/// This enum defines the various states the game can be in at any given time,
/// such as when it's actively being played, paused by the user, or when the game has ended.
enum GameState: Codable, Sendable {
    /// The game is currently in progress.
    /// This state indicates that the game is actively being played.
    case playing
    /// The game is paused.
    /// This state is used when the game has been temporarily stopped, often by user action,
    /// allowing them to resume gameplay at a later time.
    case paused
    /// The game is over.
    /// This state signifies that the game has ended, typically because the player has lost,
    /// and no further actions can affect the game state until it is restarted or reset.
    case gameOver
}
