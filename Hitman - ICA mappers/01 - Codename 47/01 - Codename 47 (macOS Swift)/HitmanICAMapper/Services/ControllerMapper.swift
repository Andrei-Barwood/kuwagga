import Foundation
import GameController
import CoreGraphics

// MARK: - Controller Mapper (Swift port of the Python HitmanMapper)

@Observable
final class ControllerMapper {

    // MARK: Public State
    var isRunning = false
    var connectedControllerName: String?
    var statusMessage: String = "Mapper detenido • Conecta un mando"
    var lastError: String?

    // Current settings (bound from UI)
    var settings = MapperSettings()

    // Dynamic remapping: ControllerInput -> GameAction id
    var activeMappings: [ControllerInput: String] = defaultMappings {
        didSet {
            // When mappings change while running we just use the new ones on next poll
        }
    }

    init() {
        // Ensure we start with good defaults
        if activeMappings.isEmpty {
            activeMappings = defaultMappings
        }
    }

    // MARK: Private
    private var currentController: GCController?
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.ica.mapper.input", qos: .userInteractive)

    // Input state tracking (to avoid spamming press/release)
    private var keyStates: [CGKeyCode: Bool] = [:]
    private var leftMouseDown = false
    private var rightMouseDown = false

    // Right stick calibration (ported from Python)
    private let restDriftThreshold: Double = 0.06
    private let restCalibrationFrames = 90
    private let restCalibrationAlpha: Double = 0.04
    private var rightStickCenter: (x: Double, y: Double) = (0.0, 0.0)
    private var restFrames: Int = 0
    private let maxMouseDelta = 45

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }

        // Try to find a controller (prefer one with extendedGamepad)
        let controller = currentController ?? GCController.current ?? GCController.controllers().first { $0.extendedGamepad != nil }

        guard let controller else {
            lastError = "No se detectó ningún mando. Conecta un control Xbox / EasySMX / compatible."
            statusMessage = "Sin mando conectado"
            return
        }

        setupController(controller)

        // Initial right stick calibration (like the Python version)
        if let gamepad = controller.extendedGamepad {
            sampleRightStickCenter(gamepad: gamepad)
        }

        // Start high-frequency input loop (~125 Hz)
        startInputLoop()

        isRunning = true
        statusMessage = "Mapper ACTIVO • \(controller.vendorName ?? "Mando conectado")"
        lastError = nil
    }

    func stop() {
        guard isRunning else { return }

        timer?.cancel()
        timer = nil

        releaseAllInputs()

        isRunning = false
        statusMessage = "Mapper detenido"
    }

    func updateSettings(_ newSettings: MapperSettings) {
        settings = newSettings
    }

    // Called from UI when user wants to force resample center
    func recalibrateRightStick() {
        guard let gamepad = currentController?.extendedGamepad else { return }
        sampleRightStickCenter(gamepad: gamepad)
    }

    // MARK: - Controller Setup

    private func setupController(_ controller: GCController) {
        currentController = controller
        connectedControllerName = controller.vendorName ?? controller.productCategory

        // Disconnection is handled via NotificationCenter in the view
    }

    private func handleControllerDisconnected() {
        stop()
        currentController = nil
        connectedControllerName = nil
        statusMessage = "Mando desconectado"
    }

    // MARK: - Input Loop

    private func startInputLoop() {
        timer?.cancel()

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(8)) // ~125 Hz, same as Python
        t.setEventHandler { [weak self] in
            self?.processControllerInput()
        }
        timer = t
        t.resume()
    }

    private func processControllerInput() {
        guard isRunning,
              let gamepad = currentController?.extendedGamepad else { return }

        // Dynamic remappable processing (new system)
        handleRemappableButton(gamepad.buttonA, for: .buttonA, gamepad: gamepad)
        handleRemappableButton(gamepad.buttonB, for: .buttonB, gamepad: gamepad)
        handleRemappableButton(gamepad.buttonX, for: .buttonX, gamepad: gamepad)
        handleRemappableButton(gamepad.buttonY, for: .buttonY, gamepad: gamepad)

        handleRemappableButton(gamepad.leftShoulder,  for: .leftShoulder, gamepad: gamepad)
        handleRemappableButton(gamepad.rightShoulder, for: .rightShoulder, gamepad: gamepad)

        handleRemappableButton(gamepad.buttonOptions, for: .buttonOptions, gamepad: gamepad)
        handleRemappableButton(gamepad.buttonMenu, for: .buttonMenu, gamepad: gamepad)

        let dpad = gamepad.dpad
        handleDigitalInput(pressed: dpad.up.isPressed,     input: .dpadUp)
        handleDigitalInput(pressed: dpad.down.isPressed,   input: .dpadDown)
        handleDigitalInput(pressed: dpad.left.isPressed,   input: .dpadLeft)
        handleDigitalInput(pressed: dpad.right.isPressed,  input: .dpadRight)

        // Dynamic analog + trigger handling (remappable)
        handleAnalogInputs(gamepad: gamepad)
        handleTrigger(gamepad.leftTrigger.value,  input: .leftTrigger)
        handleTrigger(gamepad.rightTrigger.value, input: .rightTrigger)
        // Left stick handled dynamically below

        // --- Right Stick (Mouse Look) with calibration ---
        let rawRX = Double(gamepad.rightThumbstick.xAxis.value)
        let rawRY = Double(gamepad.rightThumbstick.yAxis.value)

        calibrateRightStick(rawX: rawRX, rawY: rawRY)

        var axisRX = rawRX - rightStickCenter.x
        var axisRY = rawRY - rightStickCenter.y

        // Radial deadzone
        (axisRX, axisRY) = applyRadialDeadzone(x: axisRX, y: axisRY, deadzone: settings.lookDeadzone)

        let sens = settings.sensitivity
        var dx = Int(axisRX * sens)
        var dy = Int(axisRY * sens)

        dx = max(-maxMouseDelta, min(maxMouseDelta, dx))
        dy = max(-maxMouseDelta, min(maxMouseDelta, dy))

        if dx != 0 || dy != 0 {
            postMouseMove(dx: dx, dy: dy)
        }

        // --- Right Trigger (Shoot) ---
        let rt = gamepad.rightTrigger.value
        let triggerPressed = rt > 0.6

        if triggerPressed && !leftMouseDown {
            postMouseButton(.left, down: true)
            leftMouseDown = true
        } else if !triggerPressed && leftMouseDown {
            postMouseButton(.left, down: false)
            leftMouseDown = false
        }
    }

    // MARK: - Dynamic remapping helpers (new system)

    private func handleRemappableButton(_ button: GCControllerButtonInput?, for input: ControllerInput, gamepad: GCExtendedGamepad) {
        if let b = button {
            handleDigitalInput(pressed: b.isPressed, input: input)
        }
    }

    private func handleDigitalInput(pressed: Bool, input: ControllerInput) {
        guard let action = resolveAction(for: input) else { return }

        switch action.simulation {
        case .key(let keyVal):
            setKey(keyVal.keyCode, pressed: pressed)
        case .mouseLeft:
            if pressed && !leftMouseDown { postMouseButton(.left, down: true); leftMouseDown = true }
            else if !pressed && leftMouseDown { postMouseButton(.left, down: false); leftMouseDown = false }
        case .mouseRight:
            if pressed && !rightMouseDown { postMouseButton(.right, down: true); rightMouseDown = true }
            else if !pressed && rightMouseDown { postMouseButton(.right, down: false); rightMouseDown = false }
        default:
            break
        }
    }

    private func handleTrigger(_ value: Float, input: ControllerInput) {
        handleDigitalInput(pressed: value > 0.6, input: input)
    }

    private func handleAnalogInputs(gamepad: GCExtendedGamepad) {
        // Left Stick → movement
        if let action = resolveAction(for: .leftStick), action.simulation == .movement {
            let lx = Double(gamepad.leftThumbstick.xAxis.value)
            let ly = Double(gamepad.leftThumbstick.yAxis.value)
            let dead = settings.deadzone

            setKey(CGKeyCode.kVK_ANSI_W, pressed: ly < -dead)
            setKey(CGKeyCode.kVK_ANSI_S, pressed: ly >  dead)
            setKey(CGKeyCode.kVK_ANSI_A, pressed: lx < -dead)
            setKey(CGKeyCode.kVK_ANSI_D, pressed: lx >  dead)
            setKey(CGKeyCode.kVK_Shift, pressed: ly < -settings.runThreshold)
        }

        // Right Stick
        let rx = Double(gamepad.rightThumbstick.xAxis.value)
        let ry = Double(gamepad.rightThumbstick.yAxis.value)

        if let action = resolveAction(for: .rightStick) {
            switch action.simulation {
            case .mouseLook:
                calibrateRightStick(rawX: rx, rawY: ry)
                var ax = rx - rightStickCenter.x
                var ay = ry - rightStickCenter.y
                (ax, ay) = applyRadialDeadzone(x: ax, y: ay, deadzone: settings.lookDeadzone)

                let s = settings.sensitivity
                let dx = max(-maxMouseDelta, min(maxMouseDelta, Int(ax * s)))
                let dy = max(-maxMouseDelta, min(maxMouseDelta, Int(ay * s)))
                if dx != 0 || dy != 0 { postMouseMove(dx: dx, dy: dy) }

            case .key(let keyVal):
                // Support mapping right stick to arrows (user request example)
                let dead = settings.lookDeadzone
                setKey(CGKeyCode.kVK_RightArrow, pressed: rx > dead)
                setKey(CGKeyCode.kVK_LeftArrow,  pressed: rx < -dead)
                setKey(CGKeyCode.kVK_UpArrow,    pressed: ry < -dead)
                setKey(CGKeyCode.kVK_DownArrow,  pressed: ry >  dead)
            default: break
            }
        }
    }

    private func resolveAction(for input: ControllerInput) -> GameAction? {
        guard let id = activeMappings[input] else { return nil }
        return GameAction.action(for: id)
    }

    // MARK: - Right Stick Calibration (ported logic)

    private func calibrateRightStick(rawX: Double, rawY: Double) {
        let offsetX = rawX - rightStickCenter.x
        let offsetY = rawY - rightStickCenter.y

        if abs(offsetX) < restDriftThreshold && abs(offsetY) < restDriftThreshold {
            restFrames += 1
            if restFrames >= restCalibrationFrames {
                let alpha = restCalibrationAlpha
                rightStickCenter.x = rightStickCenter.x * (1 - alpha) + rawX * alpha
                rightStickCenter.y = rightStickCenter.y * (1 - alpha) + rawY * alpha
            }
        } else {
            restFrames = 0
        }
    }

    private func sampleRightStickCenter(gamepad: GCExtendedGamepad) {
        var sumX = 0.0
        var sumY = 0.0
        let samples = 40

        for _ in 0..<samples {
            sumX += Double(gamepad.rightThumbstick.xAxis.value)
            sumY += Double(gamepad.rightThumbstick.yAxis.value)
            Thread.sleep(forTimeInterval: 0.005)
        }

        rightStickCenter.x = sumX / Double(samples)
        rightStickCenter.y = sumY / Double(samples)
        restFrames = 0

        print("[ICA Mapper] Centro stick derecho calibrado: (\(String(format: "%.3f", rightStickCenter.x)), \(String(format: "%.3f", rightStickCenter.y)))")
    }

    private func applyRadialDeadzone(x: Double, y: Double, deadzone: Double) -> (Double, Double) {
        let magnitude = sqrt(x*x + y*y)
        if magnitude <= deadzone {
            return (0.0, 0.0)
        }
        let scale = (magnitude - deadzone) / ((1.0 - deadzone) * magnitude)
        return (x * scale, y * scale)
    }

    // MARK: - Keyboard Simulation (CGEvent)

    private func setKey(_ keyCode: CGKeyCode, pressed: Bool) {
        if keyStates[keyCode] == pressed { return }
        keyStates[keyCode] = pressed

        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: pressed) {
            event.post(tap: .cghidEventTap)
        }
    }

    private func releaseAllInputs() {
        // Release all tracked keys
        for (key, pressed) in keyStates where pressed {
            if let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) {
                event.post(tap: .cghidEventTap)
            }
        }
        keyStates.removeAll()

        if leftMouseDown {
            postMouseButton(.left, down: false)
            leftMouseDown = false
        }
        if rightMouseDown {
            postMouseButton(.right, down: false)
            rightMouseDown = false
        }
    }

    // MARK: - Mouse Simulation

    private enum MouseButton {
        case left, right
    }

    private func postMouseMove(dx: Int, dy: Int) {
        // Use relative mouse movement (best for games)
        guard let move = CGEvent(mouseEventSource: nil,
                                 mouseType: .mouseMoved,
                                 mouseCursorPosition: .zero,
                                 mouseButton: .left) else { return }

        move.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        move.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        move.post(tap: .cghidEventTap)
    }

    private func postMouseButton(_ button: MouseButton, down: Bool) {
        let mouseType: CGEventType = {
            switch (button, down) {
            case (.left, true):  return .leftMouseDown
            case (.left, false): return .leftMouseUp
            case (.right, true):  return .rightMouseDown
            case (.right, false): return .rightMouseUp
            }
        }()

        guard let event = CGEvent(mouseEventSource: nil,
                                  mouseType: mouseType,
                                  mouseCursorPosition: .zero,
                                  mouseButton: button == .left ? .left : .right) else { return }

        event.post(tap: .cghidEventTap)
    }

    // MARK: - Lifecycle

    func stopAndCleanup() {
        stop()
        // disconnection handled via notifications
        currentController = nil
    }
}

// MARK: - CGKeyCode convenience (common keys we need)
extension CGKeyCode {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_S: CGKeyCode = 0x01
    static let kVK_ANSI_D: CGKeyCode = 0x02
    static let kVK_ANSI_W: CGKeyCode = 0x0D
    static let kVK_ANSI_R: CGKeyCode = 0x0F
    static let kVK_ANSI_G: CGKeyCode = 0x05
    static let kVK_ANSI_Q: CGKeyCode = 0x0C
    static let kVK_ANSI_E: CGKeyCode = 0x0E

    static let kVK_Shift:     CGKeyCode = 0x38
    static let kVK_Return:    CGKeyCode = 0x24
    static let kVK_Escape:    CGKeyCode = 0x35

    static let kVK_UpArrow:    CGKeyCode = 0x7E
    static let kVK_DownArrow:  CGKeyCode = 0x7D
    static let kVK_LeftArrow:  CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
}
