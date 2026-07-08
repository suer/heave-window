import Carbon
import Cocoa
import os

private let logger = Logger(subsystem: "com.heavewindow.HeaveWindow", category: "WindowOperation")

class WindowOperation {
    private static let moveStep: CGFloat = 20
    private static let fastMoveStep: CGFloat = 100
    private static let minWindowDimension: CGFloat = 100

    private var isInMoveMode = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentWindow: AXUIElement?
    private let highlightWindow = HighlightWindow()
    private var workspaceObserver: NSObjectProtocol?
    private var windowObserver: AXObserver?
    private var configObserver: NSObjectProtocol?
    private var hotkey: ParsedHotkey
    private let config: Config

    init(config: Config = .shared) {
        self.config = config
        hotkey = ParsedHotkey.from(config: config.hotkeyConfig)
        setupEventTap()
        setupWorkspaceObserver()
        setupConfigObserver()
    }

    private func setupConfigObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: Config.didReloadNotification,
            object: config,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.hotkey = ParsedHotkey.from(config: self.config.hotkeyConfig)
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard
            let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                    let mover = Unmanaged<WindowOperation>.fromOpaque(refcon).takeUnretainedValue()
                    return mover.handleEvent(proxy: proxy, type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            logger.error("Failed to create event tap")
            showEventTapFailureAlert()
            return
        }

        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func showEventTapFailureAlert() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString(
            "alert.eventTapFailed.title", comment: "Event tap failure alert title")
        alert.informativeText = NSLocalizedString(
            "alert.eventTapFailed.message", comment: "Event tap failure alert message")
        alert.runModal()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
        CGEvent
    >? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if keyCode == hotkey.keyCode && flags.contains(hotkey.modifierFlags) {
            toggleMoveMode()
            return nil
        }

        if isInMoveMode {
            return handleMoveMode(keyCode: keyCode, event: event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func toggleMoveMode() {
        if isInMoveMode {
            exitMoveMode()
        } else {
            enterMoveMode()
        }
    }

    private func enterMoveMode() {
        guard let (window, pid) = getActiveWindow() else { return }

        isInMoveMode = true
        currentWindow = window
        highlightWindow.highlight(window: window)
        startObservingWindow(window, pid: pid)
    }

    private func exitMoveMode() {
        isInMoveMode = false
        highlightWindow.hide()
        stopObservingWindow()
        currentWindow = nil
    }

    private func handleMoveMode(keyCode: Int64, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let isShift = flags.contains(.maskShift)
        let isCtrl = flags.contains(.maskControl)

        switch Int(keyCode) {
        case kVK_Escape, kVK_Return:
            toggleMoveMode()
            return nil
        case kVK_UpArrow, kVK_ANSI_K:
            applyAction(deltaX: 0, deltaY: -1, isCtrl: isCtrl, isShift: isShift)
            return nil
        case kVK_DownArrow, kVK_ANSI_J:
            applyAction(deltaX: 0, deltaY: 1, isCtrl: isCtrl, isShift: isShift)
            return nil
        case kVK_LeftArrow, kVK_ANSI_H:
            applyAction(deltaX: -1, deltaY: 0, isCtrl: isCtrl, isShift: isShift)
            return nil
        case kVK_RightArrow, kVK_ANSI_L:
            applyAction(deltaX: 1, deltaY: 0, isCtrl: isCtrl, isShift: isShift)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func applyAction(deltaX: CGFloat, deltaY: CGFloat, isCtrl: Bool, isShift: Bool) {
        let step = isCtrl ? Self.fastMoveStep : Self.moveStep
        if isShift {
            resizeWindow(deltaWidth: deltaX * step, deltaHeight: deltaY * step)
        } else {
            moveWindow(deltaX: deltaX * step, deltaY: deltaY * step)
        }
    }

    private func getActiveWindow() -> (window: AXUIElement, pid: pid_t)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appRef, kAXFocusedWindowAttribute as CFString, &value)

        if result == .success, let value = value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            // swiftlint:disable:next force_cast
            return (value as! AXUIElement, pid)
        }

        return nil
    }

    private func moveWindow(deltaX: CGFloat, deltaY: CGFloat) {
        guard let window = currentWindow, var point = window.position else { return }

        point.x += deltaX
        point.y += deltaY

        window.setPosition(point)
    }

    private func resizeWindow(deltaWidth: CGFloat, deltaHeight: CGFloat) {
        guard let window = currentWindow, var size = window.size else { return }

        size.width = max(Self.minWindowDimension, size.width + deltaWidth)
        size.height = max(Self.minWindowDimension, size.height + deltaHeight)

        window.setSize(size)
    }

    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppSwitch()
        }
    }

    private func handleAppSwitch() {
        if isInMoveMode {
            exitMoveMode()
        }
    }

    private func startObservingWindow(_ window: AXUIElement, pid: pid_t) {
        var observer: AXObserver?
        let result = AXObserverCreate(
            pid,
            { (_, element, _, refcon) in
                guard let refcon = refcon else { return }
                let operation = Unmanaged<WindowOperation>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async {
                    operation.highlightWindow.highlight(window: element)
                }
            }, &observer)

        guard result == .success, let observer = observer else { return }

        self.windowObserver = observer

        AXObserverAddNotification(
            observer, window, kAXMovedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(
            observer, window, kAXResizedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func stopObservingWindow() {
        guard let observer = windowObserver, let window = currentWindow else { return }

        AXObserverRemoveNotification(observer, window, kAXMovedNotification as CFString)
        AXObserverRemoveNotification(observer, window, kAXResizedNotification as CFString)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        windowObserver = nil
    }

    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        stopObservingWindow()
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
