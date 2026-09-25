struct Position: Equatable, Codable, Sendable {
    var row: Int
    var column: Int

    var below: Position { Position(row: row + 1, column: column) }
}
