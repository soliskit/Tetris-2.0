import Foundation

extension Array where Element: Collection, Element.Index == Int {
    subscript(safeRow row: Int, safeColumn column: Int) -> Element.Element? {
        guard row >= 0, row < count, column >= 0, column < self[row].count else {
            return nil
        }
        return self[row][column]
    }
}
