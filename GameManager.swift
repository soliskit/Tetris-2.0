import SwiftUI

@MainActor
@Observable
class GameManager {
    // MARK: - Properties
    @ObservationIgnored
    @AppStorage("highScore") private var highScore: Int = 0
    @ObservationIgnored
    @AppStorage("isSessionSaved") private var isSessionSaved: Bool = false
    private var gameControllerManager: GameControllerManager?
    private let rows: Int = 20
    private let columns: Int = 10
    private var gameLoopTask: Task<Void, Never>?
    private var lockDelayTask: Task<Void, Never>?
    private var lockDelayResetCount: Int = 0
    private let maxLockDelayResets: Int = 15
    private let lockDelayInterval: TimeInterval = 0.5
    var currentTetromino: Tetromino
    var nextTetrominos: [Tetromino]
    var heldTetromino: Tetromino?
    var canHoldTetromino: Bool = true
    var gameBoard: [[GameCell]]
    var state: GameState = .gameOver
    var score: Int = 0
    var level: Int = 1
    private var standardDropInterval: TimeInterval {
        // Base interval decreases slightly with level, clamped to a sensible minimum
        max(0.25, 0.7 - (0.02 * Double(level - 1)))
    }
    private var quickDropInterval: TimeInterval {
        // Soft drop should be faster than standard but not instant
        max(0.03, standardDropInterval * 0.25)
    }

    // MARK: - Initialization
    init() {
        currentTetromino = TetrominoFactory.generate()
        nextTetrominos = (0..<3).map { _ in TetrominoFactory.generate() }
        gameBoard = Array(repeating: Array(repeating: GameCell(), count: columns), count: rows)
        gameControllerManager = GameControllerManager(gameManager: self)
    }
    
    // MARK: - Spawn Position
    private func spawnPositionFor(_ tetromino: Tetromino) -> Position {
        let width = tetromino.shape.first?.count ?? 4
        let spawnColumn = max(0, (columns - width) / 2)
        let spawnRow = 0
        return Position(row: spawnRow, column: spawnColumn)
    }

    // MARK: - Game State Management
    private func resetGameSession() {
        state = .paused
        gameBoard = Array(repeating: Array(repeating: GameCell(), count: columns), count: rows)
        score = 0
        level = 1
        currentTetromino = TetrominoFactory.generate()
        nextTetrominos = (0..<3).map { _ in TetrominoFactory.generate() }
        heldTetromino = nil
        canHoldTetromino = true
        cancelLockDelay()
        isSessionSaved = false
    }

    private func loadGameSession() {
        guard isSessionSaved, let savedData = UserDefaults.standard.data(forKey: "savedGameSession"),
              let session = try? JSONDecoder().decode(GameSession.self, from: savedData) else {
            // No valid saved session
            isSessionSaved = false
            return
        }
        state = .paused
        gameBoard = session.gameBoard
        score = session.score
        level = session.level
        currentTetromino = session.currentTetromino
        nextTetrominos = session.nextTetrominos
        heldTetromino = session.heldTetromino
        canHoldTetromino = session.canHoldTetromino
    }

    private func saveGameSession() {
        let gameSession = GameSession(gameBoard: gameBoard, score: score, level: level, currentTetromino: currentTetromino, nextTetrominos: nextTetrominos, heldTetromino: heldTetromino, canHoldTetromino: canHoldTetromino)
        if let encodedData = try? JSONEncoder().encode(gameSession) {
            UserDefaults.standard.set(encodedData, forKey: "savedGameSession")
            isSessionSaved = true
        } else {
            isSessionSaved = false
        }
    }

    // MARK: - Tetromino Management
    private func generateNextTetromino() {
        currentTetromino = nextTetrominos.removeFirst()
        nextTetrominos.append(TetrominoFactory.generate())
        canHoldTetromino = true
        cancelLockDelay()

        currentTetromino.shape = currentTetromino.rotations[0]
        currentTetromino.rotationState = 0
        currentTetromino.position = spawnPositionFor(currentTetromino)

        if !isValidTetrominoPosition(tetromino: currentTetromino, at: currentTetromino.position) {
            state = .gameOver
            isSessionSaved = false
            stopGameLoop()
        }
    }

    private func dropTetromino(isSoftDropping: Bool = false) {
        guard state == .playing else { return }
        let newPosition = Position(row: currentTetromino.position.row + 1, column: currentTetromino.position.column)
        if isValidTetrominoPosition(tetromino: currentTetromino, at: newPosition) {
            currentTetromino.position = newPosition
            cancelLockDelay()
        } else if lockDelayTask == nil {
            // Piece hit the surface for the first time — start lock delay
            startLockDelay()
        }
        // Keep gravity running so piece falls if surface disappears
        if state == .playing {
            startGameLoop(withSoftDrop: isSoftDropping)
        }
    }

    // MARK: - Lock Delay

    private var isOnSurface: Bool {
        let below = Position(row: currentTetromino.position.row + 1, column: currentTetromino.position.column)
        return !isValidTetrominoPosition(tetromino: currentTetromino, at: below)
    }

    private func startLockDelay() {
        lockDelayTask?.cancel()
        lockDelayTask = Task {
            try? await Task.sleep(for: .seconds(lockDelayInterval))
            guard !Task.isCancelled, state == .playing else { return }
            lockTetrominoInPlace()
            clearFullRows()
            generateNextTetromino()
            if state == .playing { startGameLoop() }
        }
    }

    private func resetLockDelay() {
        guard lockDelayTask != nil else { return }
        if isOnSurface {
            if lockDelayResetCount < maxLockDelayResets {
                lockDelayResetCount += 1
                startLockDelay()
            }
        } else {
            cancelLockDelay()
        }
    }

    private func cancelLockDelay() {
        lockDelayTask?.cancel()
        lockDelayTask = nil
        lockDelayResetCount = 0
    }

    private func lockTetrominoInPlace() {
        currentTetromino.shape.enumerated().forEach { y, row in
            row.enumerated().forEach { x, block in
                guard block else { return }
                let boardX = currentTetromino.position.column + x
                let boardY = currentTetromino.position.row + y

                if gameBoard[safeRow: boardY, safeColumn: boardX] != nil {
                    gameBoard[boardY][boardX] = GameCell(isFilled: true, color: currentTetromino.color)
                }
            }
        }
    }

    // MARK: - Board Management
    private func clearFullRows() {
        let scores = [1: 100, 2: 300, 3: 500, 4: 800]
        let completedLineIndices = gameBoard.indices.filter { row in
            gameBoard[row].allSatisfy { $0.isFilled }
        }
        guard !completedLineIndices.isEmpty else { return }
        completedLineIndices.reversed().forEach { index in
            gameBoard.remove(at: index)
        }
        let newLines = Array(repeating: Array(repeating: GameCell(), count: columns), count: completedLineIndices.count)
        gameBoard.insert(contentsOf: newLines, at: 0)
        score += scores[completedLineIndices.count]!
        level = score / 1000 + 1
        if score > highScore {
            highScore = score
        }
        saveGameSession()
    }

    private func isValidTetrominoPosition(tetromino: Tetromino, at position: Position) -> Bool {
        let newTetromino = Tetromino(shape: tetromino.shape, color: tetromino.color, position: position, rotations: tetromino.rotations, wallKickData: tetromino.wallKickData)
        return newTetromino.fitsWithin(gameBoard: gameBoard)
    }
    
    // MARK: - Ghost Piece
    /// A projection of the current tetromino at its landing position.
    var ghostTetromino: Tetromino {
        var ghost = Tetromino(
            shape: currentTetromino.shape,
            color: currentTetromino.color,
            position: currentTetromino.position,
            rotations: currentTetromino.rotations,
            wallKickData: currentTetromino.wallKickData
        )
        // Match current rotation state exactly
        ghost.rotationState = currentTetromino.rotationState
        ghost.shape = ghost.rotations[min(max(ghost.rotationState, 0), ghost.rotations.count - 1)]

        // Drop the ghost straight down until it no longer fits
        while true {
            let nextPos = Position(row: ghost.position.row + 1, column: ghost.position.column)
            if isValidTetrominoPosition(tetromino: ghost, at: nextPos) {
                ghost.position = nextPos
            } else {
                break
            }
        }
        return ghost
    }

    /// Returns the board coordinates occupied by the ghost tetromino for rendering.
    func ghostCells() -> [(row: Int, col: Int)] {
        let g = ghostTetromino
        var coords: [(Int, Int)] = []
        for (y, row) in g.shape.enumerated() {
            for (x, block) in row.enumerated() where block {
                let r = g.position.row + y
                let c = g.position.column + x
                if gameBoard[safeRow: r, safeColumn: c] != nil {
                    coords.append((r, c))
                }
            }
        }
        return coords
    }

    // MARK: - Game Loop (Swift Concurrency)
    private func startGameLoop(withSoftDrop: Bool = false) {
        stopGameLoop()
        let interval = withSoftDrop ? quickDropInterval : standardDropInterval
        gameLoopTask = Task {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, state == .playing else { return }
            dropTetromino()
        }
    }

    private func stopGameLoop() {
        gameLoopTask?.cancel()
        gameLoopTask = nil
    }

    // MARK: - Gameplay Controls
    func handleAction(_ action: PlayerAction) {
        switch action {
            case .newGame:
                resetGameSession()
                state = .playing
                startGameLoop()
            case .continueGame:
                loadGameSession()
            case .pause:
                state = .paused
                stopGameLoop()
                cancelLockDelay()
                saveGameSession()
            case .resume:
                state = .playing
                startGameLoop()
            case .moveLeft:
                moveTetromino(horizontalBy: -1)
            case .moveRight:
                moveTetromino(horizontalBy: 1)
            case .hold:
                holdTetromino()
            case .rotate:
                rotateTetromino()
            case .drop:
                hardDrop()
        }
    }

    func softDrop() {
        guard state == .playing else { return }
        stopGameLoop()
        let newPosition = Position(row: currentTetromino.position.row + 1, column: currentTetromino.position.column)
        if isValidTetrominoPosition(tetromino: currentTetromino, at: newPosition) {
            currentTetromino.position = newPosition
            cancelLockDelay()
        } else if lockDelayTask == nil {
            startLockDelay()
        }
        if state == .playing {
            startGameLoop(withSoftDrop: true)
        }
    }

    func hardDrop() {
        guard state == .playing else { return }
        cancelLockDelay()
        // Move current piece to the ghost landing position instantly
        let g = ghostTetromino
        currentTetromino.position = g.position
        lockTetrominoInPlace()
        clearFullRows()
        generateNextTetromino()
        if state == .playing {
            startGameLoop()
        }
    }

    private func moveTetromino(horizontalBy deltaX: Int) {
        guard state == .playing else { return }
        let newPosition = Position(row: currentTetromino.position.row, column: currentTetromino.position.column + deltaX)
        if isValidTetrominoPosition(tetromino: currentTetromino, at: newPosition) {
            currentTetromino.position = newPosition
            // Gravity keeps ticking on its own; restarting it here would let
            // repeated sideways moves keep the piece floating forever.
            resetLockDelay()
        }
    }

    private func holdTetromino() {
        guard state == .playing, canHoldTetromino else { return }
        stopGameLoop()
        // The outgoing piece may be resting on the stack with a lock pending;
        // without this, the swapped in piece gets locked at the spawn point.
        cancelLockDelay()
        if var tetrominoToSwap = heldTetromino {
            // Reset held piece to spawn state
            tetrominoToSwap.shape = tetrominoToSwap.rotations[0]
            tetrominoToSwap.rotationState = 0
            let spawnPos = spawnPositionFor(tetrominoToSwap)
            // Ensure swapped-in piece can spawn; otherwise, game over
            if !isValidTetrominoPosition(tetromino: tetrominoToSwap, at: spawnPos) {
                state = .gameOver
                isSessionSaved = false
                return
            }
            // Store current piece (reset to spawn state)
            var pieceToHold = currentTetromino
            pieceToHold.shape = pieceToHold.rotations[0]
            pieceToHold.rotationState = 0
            pieceToHold.position = spawnPositionFor(pieceToHold)
            heldTetromino = pieceToHold
            currentTetromino = tetrominoToSwap
            currentTetromino.position = spawnPos
            canHoldTetromino = false
        } else {
            var pieceToHold = currentTetromino
            pieceToHold.shape = pieceToHold.rotations[0]
            pieceToHold.rotationState = 0
            pieceToHold.position = spawnPositionFor(pieceToHold)
            heldTetromino = pieceToHold
            // Bring in next piece freshly spawned
            generateNextTetromino()
            canHoldTetromino = false
        }
        if state == .playing { startGameLoop() }
    }

    private func rotateTetromino() {
        guard state == .playing else { return }
        let previousState = currentTetromino.rotationState
        currentTetromino.rotate(gameBoard: gameBoard)
        if currentTetromino.rotationState != previousState {
            resetLockDelay()
        }
    }
}
