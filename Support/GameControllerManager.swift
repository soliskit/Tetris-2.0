@preconcurrency import GameController

@MainActor
class GameControllerManager {
    weak var gameManager: GameManager?
    private var movementDirection: Direction?
    private var movementTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var disconnectionTask: Task<Void, Never>?
    private var keyboardConnectionTask: Task<Void, Never>?
    private var keyboardDisconnectionTask: Task<Void, Never>?
    private var softDropTask: Task<Void, Never>? = nil
    // Button states from the previous input event, so each press fires once.
    private var wasMenuPressed = false
    private var wasBPressed = false
    private var wasXPressed = false
    private var wasAPressed = false
    private var wasYPressed = false

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        setupControllers()
    }

    deinit {
        connectionTask?.cancel()
        disconnectionTask?.cancel()
        keyboardConnectionTask?.cancel()
        keyboardDisconnectionTask?.cancel()
        movementTask?.cancel()
        softDropTask?.cancel()
    }

    private func setupControllers() {
        // Weak, like the disconnect listener, so this loop doesn't keep the
        // manager alive after its GameManager is gone.
        connectionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                guard let self, !Task.isCancelled else { return }
                if let controller = notification.object as? GCController {
                    self.configure(controller: controller)
                }
            }
        }

        // A controller that drops out mid press never reports the release.
        disconnectionTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .GCControllerDidDisconnect) {
                guard let self, !Task.isCancelled else { return }
                self.releaseAllInput()
            }
        }

        for controller in GCController.controllers() {
            configure(controller: controller)
        }

        // The keyboard is read through GameController too. The UIKit responder
        // chain never delivered keys to the game when run in Swift Playgrounds.
        keyboardConnectionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                guard let self, !Task.isCancelled else { return }
                if let keyboard = notification.object as? GCKeyboard {
                    self.configure(keyboard: keyboard)
                }
            }
        }

        keyboardDisconnectionTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidDisconnect) {
                guard let self, !Task.isCancelled else { return }
                self.stopMoving()
                self.gameManager?.isKeyboardConnected = GCKeyboard.coalesced != nil
            }
        }

        if let keyboard = GCKeyboard.coalesced {
            configure(keyboard: keyboard)
        }
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
                guard let self else { return }
                self.processKey(keyCode, pressed: pressed, modifierHeld: modifierHeld, leftHeld: leftHeld, rightHeld: rightHeld)
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
                startMoving(key == .keyA ? .left : .right)
            } else if leftHeld {
                startMoving(.left)
            } else if rightHeld {
                startMoving(.right)
            } else {
                stopMoving()
            }
            return
        }

        guard pressed else { return }
        switch key {
            case .keyW:
                gameManager?.handleAction(.rotate)
            case .keyS:
                gameManager?.handleAction(.drop)
            case .keyH:
                gameManager?.handleAction(.hold)
            case .returnOrEnter:
                gameManager?.handleAction(.newGame)
            case .keyC:
                gameManager?.handleAction(.continueGame)
            case .keyP, .escape:
                gameManager?.togglePause()
            default:
                break
        }
    }

    // MARK: - Controller

    private func configure(controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            let menuPressed = gamepad.buttonMenu.isPressed
            let bPressed = gamepad.buttonB.isPressed
            let xPressed = gamepad.buttonX.isPressed
            let aPressed = gamepad.buttonA.isPressed
            let yPressed = gamepad.buttonY.isPressed
            let xAxis = gamepad.leftThumbstick.xAxis.value
            let yAxis = gamepad.leftThumbstick.yAxis.value
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processInput(menuPressed: menuPressed, bPressed: bPressed, xPressed: xPressed, aPressed: aPressed, yPressed: yPressed, xAxis: xAxis, yAxis: yAxis)
            }
        }
    }

    private func processInput(menuPressed: Bool, bPressed: Bool, xPressed: Bool, aPressed: Bool, yPressed: Bool, xAxis: Float, yAxis: Float) {
        // This runs for every element change, including stick jitter while a
        // button is held, so buttons only act on the press itself.
        defer {
            wasMenuPressed = menuPressed
            wasBPressed = bPressed
            wasXPressed = xPressed
            wasAPressed = aPressed
            wasYPressed = yPressed
        }

        // Menu starts a new game from the game over screen. A is left out on
        // purpose: players often mash it as the game ends.
        if menuPressed && !wasMenuPressed {
            if gameManager?.state == .gameOver {
                gameManager?.handleAction(.newGame)
            } else {
                gameManager?.togglePause()
            }
        }
        if yPressed && !wasYPressed {
            gameManager?.handleAction(.continueGame)
        }
        if bPressed && !wasBPressed {
            gameManager?.handleAction(.rotate)
        }
        if xPressed && !wasXPressed {
            gameManager?.handleAction(.hold)
        }

        if aPressed && !wasAPressed {
            gameManager?.hardDrop()
        }

        if yAxis < -0.5 {
            startSoftDrop()
        } else {
            stopSoftDrop()
        }

        if xAxis < -0.5 {
            startMoving(.left)
        } else if xAxis > 0.5 {
            startMoving(.right)
        } else {
            stopMoving()
        }
    }

    /// DAS (Delayed Auto Shift) — initial delay before auto-repeat starts.
    private let dasDelay: Duration = .milliseconds(167)
    /// ARR (Auto Repeat Rate) — interval between repeated moves.
    private let arrInterval: Duration = .milliseconds(33)

    private func startMoving(_ direction: Direction) {
        guard movementDirection != direction else { return }
        movementDirection = direction
        movementTask?.cancel()
        let action: PlayerAction = direction == .left ? .moveLeft : .moveRight
        gameManager?.handleAction(action)
        movementTask = Task {
            // DAS: initial delay before auto-repeat
            try? await Task.sleep(for: dasDelay)
            guard !Task.isCancelled else { return }
            // ARR: fast repeat
            while !Task.isCancelled {
                // A release while the app is in the background is never
                // reported, so stop repeating once the game isn't playing.
                guard gameManager?.state == .playing else {
                    stopMoving()
                    return
                }
                switch movementDirection {
                    case .left:
                        gameManager?.handleAction(.moveLeft)
                    case .right:
                        gameManager?.handleAction(.moveRight)
                    case .none:
                        break
                }
                try? await Task.sleep(for: arrInterval)
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func stopMoving() {
        movementTask?.cancel()
        movementTask = nil
        movementDirection = nil
    }

    private func startSoftDrop() {
        guard softDropTask == nil else { return }
        softDropTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // Same as movement: stop repeating once the game isn't playing.
                    if self.gameManager?.state == .playing {
                        self.gameManager?.softDrop()
                    } else {
                        self.stopSoftDrop()
                    }
                }
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
        wasMenuPressed = false
        wasBPressed = false
        wasXPressed = false
        wasAPressed = false
        wasYPressed = false
    }
}
