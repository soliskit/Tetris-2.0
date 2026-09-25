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
    /// Lowest row the current piece has reached. Only a new lowest row refills its moves.
    private var lowestRowReached: Int = 0
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
    /// Whether GameController currently sees a hardware keyboard.
    var isKeyboardConnected: Bool = false
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
        currentTetromino = TetrominoFactory.generate().spawned(columns: columns)
        nextTetrominos = (0..<3).map { _ in TetrominoFactory.generate() }
        gameBoard = Array(repeating: Array(repeating: GameCell(), count: columns), count: rows)
        gameControllerManager = GameControllerManager(gameManager: self)
    }

    // MARK: - Game State Management
    private func resetGameSession() {
        state = .paused
        gameBoard = Array(repeating: Array(repeating: GameCell(), count: columns), count: rows)
        score = 0
        level = 1
        currentTetromino = TetrominoFactory.generate().spawned(columns: columns)
        nextTetrominos = (0..<3).map { _ in TetrominoFactory.generate() }
        heldTetromino = nil
        canHoldTetromino = true
        resetLockDelayForNewPiece()
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
        resetLockDelayForNewPiece()
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
        currentTetromino = nextTetrominos.removeFirst().spawned(columns: columns)
        nextTetrominos.append(TetrominoFactory.generate())
        canHoldTetromino = true
        resetLockDelayForNewPiece()

        if !currentTetromino.fits(in: gameBoard) {
            state = .gameOver
            isSessionSaved = false
            stopGameLoop()
        }
    }

    /// Moves the piece down a row, or starts locking it once it can't move.
    /// Gravity calls this on a timer and soft drop calls it directly.
    private func dropTetromino(softDrop: Bool = false) {
        guard state == .playing else { return }
        if currentTetromino.fits(in: gameBoard, at: currentTetromino.position.below) {
            currentTetromino.position = currentTetromino.position.below
            cancelLockDelay()
            noteLowestRow()
        } else {
            pieceLanded()
        }
        // Keep gravity running so piece falls if surface disappears
        if state == .playing {
            startGameLoop(withSoftDrop: softDrop)
        }
    }

    // MARK: - Lock Delay

    private var isOnSurface: Bool {
        !currentTetromino.fits(in: gameBoard, at: currentTetromino.position.below)
    }

    private func startLockDelay() {
        lockDelayTask?.cancel()
        lockDelayTask = Task {
            try? await Task.sleep(for: .seconds(lockDelayInterval))
            guard !Task.isCancelled, state == .playing else { return }
            lockAndSpawnNext()
            if state == .playing { startGameLoop() }
        }
    }

    /// Starts the lock delay when the piece comes to rest. A piece that has
    /// used all its moves locks straight away instead.
    private func pieceLanded() {
        guard lockDelayTask == nil else { return }
        if lockDelayResetCount >= maxLockDelayResets {
            lockAndSpawnNext()
        } else {
            startLockDelay()
        }
    }

    /// Called after a successful move or rotation.
    private func resetLockDelay() {
        noteLowestRow()
        guard lockDelayTask != nil else { return }
        if !isOnSurface {
            // Lifted off the surface, so let it fall. The lift still costs a
            // move, or rotating in place could earn endless fresh lock delays.
            cancelLockDelay()
            lockDelayResetCount += 1
        } else if lockDelayResetCount < maxLockDelayResets {
            lockDelayResetCount += 1
            startLockDelay()
        }
    }

    /// Reaching a new lowest row refills the piece's moves. Nothing else does,
    /// so moves and rotations can't hold a piece up forever.
    private func noteLowestRow() {
        guard currentTetromino.position.row > lowestRowReached else { return }
        lowestRowReached = currentTetromino.position.row
        lockDelayResetCount = 0
    }

    private func resetLockDelayForNewPiece() {
        cancelLockDelay()
        lockDelayResetCount = 0
        lowestRowReached = currentTetromino.position.row
    }

    /// Stops the lock timer. The piece's remaining moves are kept.
    private func cancelLockDelay() {
        lockDelayTask?.cancel()
        lockDelayTask = nil
    }

    private func lockAndSpawnNext() {
        lockTetrominoInPlace()
        let clearedLines = clearFullRows()
        generateNextTetromino()
        // Checkpoint only once the next piece is in play. Saving before the
        // spawn stored the locked piece as if it were still falling.
        if clearedLines, state == .playing {
            saveGameSession()
        }
    }

    private func lockTetrominoInPlace() {
        for cell in currentTetromino.cells where gameBoard[safeRow: cell.row, safeColumn: cell.column] != nil {
            gameBoard[cell.row][cell.column] = GameCell(isFilled: true, color: currentTetromino.color)
        }
    }

    // MARK: - Board Management
    /// Removes completed rows and updates the score. Returns whether any rows were cleared.
    private func clearFullRows() -> Bool {
        let scores = [1: 100, 2: 300, 3: 500, 4: 800]
        let completedLineIndices = gameBoard.indices.filter { row in
            gameBoard[row].allSatisfy { $0.isFilled }
        }
        guard !completedLineIndices.isEmpty else { return false }
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
        return true
    }

    // MARK: - Ghost Piece
    /// A projection of the current tetromino at its landing position.
    var ghostTetromino: Tetromino {
        var ghost = currentTetromino
        // Drop the ghost straight down until it no longer fits
        while ghost.fits(in: gameBoard, at: ghost.position.below) {
            ghost.position = ghost.position.below
        }
        return ghost
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
                // Keys and buttons can send this at any time; only the game
                // over screen offers it, so a stray press can't wipe a game.
                guard state == .gameOver else { return }
                resetGameSession()
                state = .playing
                startGameLoop()
            case .continueGame:
                guard state == .gameOver else { return }
                loadGameSession()
            case .pause:
                state = .paused
                stopGameLoop()
                // Resuming starts a fresh lock delay, so pausing on the stack
                // costs a move, or pause and resume could hold a piece forever.
                if lockDelayTask != nil {
                    lockDelayResetCount += 1
                }
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

    /// Pauses a running game or resumes a paused one.
    func togglePause() {
        switch state {
            case .playing:
                handleAction(.pause)
            case .paused:
                handleAction(.resume)
            case .gameOver:
                break
        }
    }

    func softDrop() {
        dropTetromino(softDrop: true)
    }

    func hardDrop() {
        guard state == .playing else { return }
        cancelLockDelay()
        // Move current piece to the ghost landing position instantly
        currentTetromino.position = ghostTetromino.position
        lockAndSpawnNext()
        if state == .playing {
            startGameLoop()
        }
    }

    private func moveTetromino(horizontalBy deltaX: Int) {
        guard state == .playing else { return }
        let newPosition = Position(row: currentTetromino.position.row, column: currentTetromino.position.column + deltaX)
        if currentTetromino.fits(in: gameBoard, at: newPosition) {
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
        let pieceToHold = currentTetromino.spawned(columns: columns)
        if let held = heldTetromino {
            // Ensure swapped-in piece can spawn; otherwise, game over
            let incoming = held.spawned(columns: columns)
            guard incoming.fits(in: gameBoard) else {
                state = .gameOver
                isSessionSaved = false
                return
            }
            currentTetromino = incoming
            resetLockDelayForNewPiece()
        } else {
            // Bring in next piece freshly spawned
            generateNextTetromino()
        }
        heldTetromino = pieceToHold
        canHoldTetromino = false
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
