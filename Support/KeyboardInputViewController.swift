import UIKit

class KeyboardInputViewController: UIViewController {
    var moveLeftAction: (() -> Void)?
    var moveRightAction: (() -> Void)?
    var rotateAction: (() -> Void)?
    var dropAction: (() -> Void)?
    var holdAction: (() -> Void)?
    
    override var canBecomeFirstResponder: Bool { true }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(action: #selector(moveLeft), input: "a", modifierFlags: [], discoverabilityTitle: "Move Piece Left"),
            UIKeyCommand(action: #selector(moveRight), input: "d", modifierFlags: [], discoverabilityTitle: "Move Piece Right"),
            UIKeyCommand(action: #selector(rotate), input: "w", modifierFlags: [], discoverabilityTitle: "Rotate"),
            UIKeyCommand(action: #selector(drop), input: "s", modifierFlags: [], discoverabilityTitle: "Drop Piece"),
            UIKeyCommand(action: #selector(hold), input: "h", modifierFlags: [], discoverabilityTitle: "Hold or Switch Piece")
        ]
    }
    
    @objc func moveLeft() {
        moveLeftAction?()
    }
    
    @objc func moveRight() {
        moveRightAction?()
    }
    
    @objc func rotate() {
        rotateAction?()
    }
    
    @objc func drop() {
        dropAction?()
    }
    
    @objc func hold() {
        holdAction?()
    }
}
