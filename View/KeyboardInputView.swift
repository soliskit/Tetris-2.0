import SwiftUI

struct KeyboardInputView: UIViewControllerRepresentable {
    var moveLeft: () -> Void
    var moveRight: () -> Void
    var rotate: () -> Void
    var drop: () -> Void
    var hold: () -> Void
    
    func makeUIViewController(context: Context) -> KeyboardInputViewController {
        let viewController = KeyboardInputViewController()
        viewController.moveLeftAction = moveLeft
        viewController.moveRightAction = moveRight
        viewController.rotateAction = rotate
        viewController.dropAction = drop
        viewController.holdAction = hold
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: KeyboardInputViewController, context: Context) {
        
    }
}
