@preconcurrency import GameController

@MainActor
class GameControllerManager {
    weak var gameManager: GameManager?
    private var movementDirection: Direction?
    private var movementTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var disconnectionTask: Task<Void, Never>?
    private var softDropTask: Task<Void, Never>? = nil
    private var softDropKeyTask: Task<Void, Never>? = nil
    // Button states from the previous input event, so each press fires once.
    private var wasMenuPressed = false
    private var wasBPressed = false
    private var wasXPressed = false
    private var wasAPressed = false

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        setupControllers()
    }

    deinit {
        connectionTask?.cancel()
        disconnectionTask?.cancel()
        movementTask?.cancel()
        softDropTask?.cancel()
        softDropKeyTask?.cancel()
    }

    private func setupControllers() {
        connectionTask = Task {
            for await notification in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                guard !Task.isCancelled else { return }
                if let controller = notification.object as? GCController {
                    configure(controller: controller)
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
    }

    private func configure(controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            let menuPressed = gamepad.buttonMenu.isPressed
            let bPressed = gamepad.buttonB.isPressed
            let xPressed = gamepad.buttonX.isPressed
            let aPressed = gamepad.buttonA.isPressed
            let xAxis = gamepad.leftThumbstick.xAxis.value
            let yAxis = gamepad.leftThumbstick.yAxis.value
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processInput(menuPressed: menuPressed, bPressed: bPressed, xPressed: xPressed, aPressed: aPressed, xAxis: xAxis, yAxis: yAxis)
            }
        }
    }

    private func processInput(menuPressed: Bool, bPressed: Bool, xPressed: Bool, aPressed: Bool, xAxis: Float, yAxis: Float) {
        // This runs for every element change, including stick jitter while a
        // button is held, so buttons only act on the press itself.
        defer {
            wasMenuPressed = menuPressed
            wasBPressed = bPressed
            wasXPressed = xPressed
            wasAPressed = aPressed
        }

        if menuPressed && !wasMenuPressed {
            if gameManager?.state == .playing {
                gameManager?.handleAction(.pause)
            } else if gameManager?.state == .paused {
                gameManager?.handleAction(.resume)
            }
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
    }

// MARK: - Keyboard/Touch Bridging
    func handleKeyDownLeft() { gameManager?.handleAction(.moveLeft) }
    func handleKeyDownRight() { gameManager?.handleAction(.moveRight) }
    func handleKeyDownRotate() { gameManager?.handleAction(.rotate) }
    func handleKeyDownHold() { gameManager?.handleAction(.hold) }
    func handleKeyDownHardDrop() { gameManager?.hardDrop() }

    func startSoftDropKey() {
        guard softDropKeyTask == nil else { return }
        softDropKeyTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                await MainActor.run { [weak self] in
                    self?.gameManager?.softDrop()
                }
            }
        }
    }

    func stopSoftDropKey() {
        softDropKeyTask?.cancel()
        softDropKeyTask = nil
    }
}
