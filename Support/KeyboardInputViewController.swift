import UIKit

class KeyboardInputViewController: UIViewController {
    var moveLeftAction: (() -> Void)?
    var moveRightAction: (() -> Void)?
    var rotateAction: (() -> Void)?
    var dropAction: (() -> Void)?
    var holdAction: (() -> Void)?
    var newGameAction: (() -> Void)?
    var continueAction: (() -> Void)?
    var pauseAction: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Key commands are only delivered along the responder chain.
        becomeFirstResponder()
    }

    // Key commands repeat while the key is held. That suits moving, so A and D
    // use them; everything else is handled once per press in pressesBegan.
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(action: #selector(moveLeft), input: "a", modifierFlags: [], discoverabilityTitle: "Move Piece Left"),
            UIKeyCommand(action: #selector(moveRight), input: "d", modifierFlags: [], discoverabilityTitle: "Move Piece Right")
        ]
    }

    // Called once when a key goes down, however long it's held, so a held S
    // drops one piece instead of repeating.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if let key = press.key, let handler = gameAction(for: key) {
                handler()
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    private func gameAction(for key: UIKey) -> (() -> Void)? {
        // Leave shortcuts like Command H to the system.
        guard key.modifierFlags.isDisjoint(with: [.command, .control, .alternate]) else { return nil }
        switch key.keyCode {
            case .keyboardReturnOrEnter:
                return newGameAction
            case .keyboardEscape:
                return pauseAction
            default:
                break
        }
        switch key.charactersIgnoringModifiers.lowercased() {
            case "w":
                return rotateAction
            case "s":
                return dropAction
            case "h":
                return holdAction
            case "c":
                return continueAction
            case "p":
                return pauseAction
            default:
                return nil
        }
    }

    @objc func moveLeft() {
        moveLeftAction?()
    }

    @objc func moveRight() {
        moveRightAction?()
    }
}
