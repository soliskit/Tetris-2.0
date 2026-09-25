import SwiftUI

@MainActor
@Observable
class GameManager {
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
    var isKeyboardConnected: Bool = false
    private var standardDropInterval: TimeInterval {
        max(0.25, 0.7 - (0.02 * Double(level - 1)))
    }

    init() {
        currentTetromino = TetrominoFactory.generate().spawned(columns: columns)
        nextTetrominos = (0..<3).map { _ in TetrominoFactory.generate() }
        gameBoard = Array(repeating: Array(repeating: GameCell(), count: columns), count: rows)
        gameControllerManager = GameControllerManager(gameManager: self)
    }

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

    private func dropTetromino() {
        guard state == .playing else { return }
        if currentTetromino.fits(in: gameBoard, at: currentTetromino.position.below) {
            currentTetromino.position = currentTetromino.position.below
            cancelLockDelay()
            noteLowestRow()
        } else {
            pieceLanded()
        }
        if state == .playing {
            startGameLoop()
        }
    }

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

    private func pieceLanded() {
        guard lockDelayTask == nil else { return }
        if lockDelayResetCount >= maxLockDelayResets {
            lockAndSpawnNext()
        } else {
            startLockDelay()
        }
    }

    private func resetLockDelay() {
        noteLowestRow()
        guard lockDelayTask != nil else { return }
        if !isOnSurface {
            cancelLockDelay()
            lockDelayResetCount += 1
        } else if lockDelayResetCount < maxLockDelayResets {
            lockDelayResetCount += 1
            startLockDelay()
        }
    }

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

    private func cancelLockDelay() {
        lockDelayTask?.cancel()
        lockDelayTask = nil
    }

    private func lockAndSpawnNext() {
        lockTetrominoInPlace()
        let clearedLines = clearFullRows()
        generateNextTetromino()
        if clearedLines, state == .playing {
            saveGameSession()
        }
    }

    private func lockTetrominoInPlace() {
        for cell in currentTetromino.cells where gameBoard[safeRow: cell.row, safeColumn: cell.column] != nil {
            gameBoard[cell.row][cell.column] = GameCell(isFilled: true, color: currentTetromino.color)
        }
    }

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

    var ghostTetromino: Tetromino {
        var ghost = currentTetromino
        while ghost.fits(in: gameBoard, at: ghost.position.below) {
            ghost.position = ghost.position.below
        }
        return ghost
    }

    private func startGameLoop() {
        stopGameLoop()
        let interval = standardDropInterval
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

    func handleAction(_ action: PlayerAction) {
        switch action {
            case .newGame:
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
        dropTetromino()
    }

    func hardDrop() {
        guard state == .playing else { return }
        cancelLockDelay()
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
            resetLockDelay()
        }
    }

    private func holdTetromino() {
        guard state == .playing, canHoldTetromino else { return }
        stopGameLoop()
        cancelLockDelay()
        let pieceToHold = currentTetromino.spawned(columns: columns)
        if let held = heldTetromino {
            let incoming = held.spawned(columns: columns)
            guard incoming.fits(in: gameBoard) else {
                state = .gameOver
                isSessionSaved = false
                return
            }
            currentTetromino = incoming
            resetLockDelayForNewPiece()
        } else {
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
