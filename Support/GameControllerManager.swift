@preconcurrency import GameController

@MainActor
class GameControllerManager {
    weak var gameManager: GameManager?
    private var movement: PlayerAction?
    private var movementTask: Task<Void, Never>?
    private var softDropTask: Task<Void, Never>? = nil
    private var notificationTasks: [Task<Void, Never>] = []
    private enum PadButton { case menu, a, b, x, y }
    // Controller buttons down at the previous input event, so each press fires once.
    private var heldButtons: Set<PadButton> = []
    /// Keys that act once per press. A and D move and P or Escape pause, in processKey.
    private static let keyActions: [GCKeyCode: PlayerAction] = [
        .keyW: .rotate, .keyS: .drop, .keyH: .hold, .returnOrEnter: .newGame, .keyC: .continueGame
    ]

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        setupControllers()
    }

    deinit {
        notificationTasks.forEach { $0.cancel() }
        movementTask?.cancel()
        softDropTask?.cancel()
    }

    private func setupControllers() {
        observe(.GCControllerDidConnect) { manager, notification in
            if let controller = notification.object as? GCController {
                manager.configure(controller: controller)
            }
        }
        // A controller that drops out mid press never reports the release.
        observe(.GCControllerDidDisconnect) { manager, _ in
            manager.releaseAllInput()
        }
        GCController.controllers().forEach(configure(controller:))

        // The keyboard is read through GameController too. The UIKit responder
        // chain never delivered keys to the game when run in Swift Playgrounds.
        observe(.GCKeyboardDidConnect) { manager, notification in
            if let keyboard = notification.object as? GCKeyboard {
                manager.configure(keyboard: keyboard)
            }
        }
        observe(.GCKeyboardDidDisconnect) { manager, _ in
            manager.stopMoving()
            manager.gameManager?.isKeyboardConnected = GCKeyboard.coalesced != nil
        }
        if let keyboard = GCKeyboard.coalesced {
            configure(keyboard: keyboard)
        }
    }

    /// Calls `handle` for every `name` notification. The loop holds the manager
    /// weakly, so it doesn't keep it alive after its GameManager is gone.
    private func observe(_ name: Notification.Name, _ handle: @escaping @MainActor (GameControllerManager, Notification) -> Void) {
        notificationTasks.append(Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: name) {
                guard let self, !Task.isCancelled else { return }
                handle(self, notification)
            }
        })
    }

    // MARK: - Keyboard

    private func configure(keyboard: GCKeyboard) {
        gameManager?.isKeyboardConnected = true
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] keyboardInput, _, keyCode, pressed in
            func isDown(_ key: GCKeyCode) -> Bool {
                keyboardInput.button(forKeyCode: key)?.isPressed ?? false
            }
            let modifierHeld = [GCKeyCode.leftGUI, .rightGUI, .leftControl, .rightControl, .leftAlt, .rightAlt].contains(where: isDown)
            let leftHeld = isDown(.keyA)
            let rightHeld = isDown(.keyD)
            Task { @MainActor [weak self] in
                self?.processKey(keyCode, pressed: pressed, modifierHeld: modifierHeld, leftHeld: leftHeld, rightHeld: rightHeld)
            }
        }
    }

    /// Called once when a key goes down and once when it comes back up, so a
    /// held key never repeats its action. A and D use the same auto repeat as
    /// the stick.
    private func processKey(_ key: GCKeyCode, pressed: Bool, modifierHeld: Bool, leftHeld: Bool, rightHeld: Bool) {
        // Leave shortcuts like Command H to the system.
        if pressed && modifierHeld { return }

        if key == .keyA || key == .keyD {
            // The newest press wins. Letting go falls back to the other key if
            // it's still down.
            if pressed {
                startMoving(key == .keyA ? .moveLeft : .moveRight)
            } else if leftHeld {
                startMoving(.moveLeft)
            } else if rightHeld {
                startMoving(.moveRight)
            } else {
                stopMoving()
            }
        } else if pressed, key == .keyP || key == .escape {
            gameManager?.togglePause()
        } else if pressed, let action = Self.keyActions[key] {
            gameManager?.handleAction(action)
        }
    }

    // MARK: - Controller

    private func configure(controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            let buttons: [PadButton: GCControllerButtonInput] = [
                .menu: gamepad.buttonMenu, .a: gamepad.buttonA, .b: gamepad.buttonB, .x: gamepad.buttonX, .y: gamepad.buttonY
            ]
            let pressed = Set(buttons.filter { $0.value.isPressed }.keys)
            let xAxis = gamepad.leftThumbstick.xAxis.value
            let yAxis = gamepad.leftThumbstick.yAxis.value
            Task { @MainActor [weak self] in
                self?.processInput(pressed: pressed, xAxis: xAxis, yAxis: yAxis)
            }
        }
    }

    private func processInput(pressed: Set<PadButton>, xAxis: Float, yAxis: Float) {
        // This runs for every element change, including stick jitter while a
        // button is held, so buttons only act on the press itself.
        let newPresses = pressed.subtracting(heldButtons)
        heldButtons = pressed

        // Menu starts a new game from the game over screen. A is left out on
        // purpose: players often mash it as the game ends.
        if newPresses.contains(.menu) {
            if gameManager?.state == .gameOver {
                gameManager?.handleAction(.newGame)
            } else {
                gameManager?.togglePause()
            }
        }
        let buttonActions: [(PadButton, PlayerAction)] = [(.y, .continueGame), (.b, .rotate), (.x, .hold), (.a, .drop)]
        for (button, action) in buttonActions where newPresses.contains(button) {
            gameManager?.handleAction(action)
        }

        if yAxis < -0.5 {
            startSoftDrop()
        } else {
            stopSoftDrop()
        }

        if xAxis < -0.5 {
            startMoving(.moveLeft)
        } else if xAxis > 0.5 {
            startMoving(.moveRight)
        } else {
            stopMoving()
        }
    }

    /// DAS (Delayed Auto Shift) — initial delay before auto-repeat starts.
    private let dasDelay: Duration = .milliseconds(167)
    /// ARR (Auto Repeat Rate) — interval between repeated moves.
    private let arrInterval: Duration = .milliseconds(33)

    /// Moves once now, then repeats after the DAS delay at the ARR rate.
    private func startMoving(_ action: PlayerAction) {
        guard movement != action else { return }
        movement = action
        movementTask?.cancel()
        gameManager?.handleAction(action)
        movementTask = Task {
            try? await Task.sleep(for: dasDelay)
            while !Task.isCancelled {
                // A release while the app is in the background is never
                // reported, so stop repeating once the game isn't playing.
                guard gameManager?.state == .playing else {
                    stopMoving()
                    return
                }
                gameManager?.handleAction(action)
                try? await Task.sleep(for: arrInterval)
            }
        }
    }

    private func stopMoving() {
        movementTask?.cancel()
        movementTask = nil
        movement = nil
    }

    private func startSoftDrop() {
        guard softDropTask == nil else { return }
        softDropTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                // Same as movement: stop repeating once the game isn't playing.
                guard gameManager?.state == .playing else {
                    stopSoftDrop()
                    return
                }
                gameManager?.softDrop()
            }
        }
    }

    private func stopSoftDrop() {
        softDropTask?.cancel()
        softDropTask = nil
    }

    /// Clears held input so nothing keeps repeating, and so the next press on a
    /// reconnected controller isn't mistaken for a button that was never released.
    private func releaseAllInput() {
        stopMoving()
        stopSoftDrop()
        heldButtons = []
    }
}
