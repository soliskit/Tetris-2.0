import SwiftUI

struct KeyboardInputView: UIViewControllerRepresentable {
    var moveLeft: () -> Void
    var moveRight: () -> Void
    var rotate: () -> Void
    var drop: () -> Void
    var hold: () -> Void
    var newGame: () -> Void
    var continueGame: () -> Void
    var togglePause: () -> Void

    func makeUIViewController(context: Context) -> KeyboardInputViewController {
        let viewController = KeyboardInputViewController()
        viewController.moveLeftAction = moveLeft
        viewController.moveRightAction = moveRight
        viewController.rotateAction = rotate
        viewController.dropAction = drop
        viewController.holdAction = hold
        viewController.newGameAction = newGame
        viewController.continueAction = continueGame
        viewController.pauseAction = togglePause
        return viewController
    }

    func updateUIViewController(_ uiViewController: KeyboardInputViewController, context: Context) {

    }
}
