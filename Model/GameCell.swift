struct GameCell: Codable, Equatable, Sendable {
    var isFilled: Bool = false
    var color: CustomColor? = nil
}
