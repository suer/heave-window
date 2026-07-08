import Cocoa
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowOperation: WindowOperation?
    var accessibilityCheckTimer: Timer?
    private let updaterController: SPUStandardUpdaterController
    private var configParseErrorObserver: NSObjectProtocol?

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupConfigParseErrorObserver()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuIcon")
            button.action = #selector(statusBarButtonClicked)
        }
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: NSLocalizedString("menu.about", comment: "About menu item"), action: #selector(showAboutPanel), keyEquivalent: ""))
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("menu.checkForUpdates", comment: "Check for updates menu item"), action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        if #available(macOS 13.0, *) {
            let launchAtLoginItem = NSMenuItem(
                title: NSLocalizedString("menu.launchAtLogin", comment: "Launch at login menu item"),
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
            menu.addItem(launchAtLoginItem)
        }
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("menu.settings", comment: "Settings menu item"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Quit menu item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu

        setupWithAccessibilityCheck()
    }

    @objc func statusBarButtonClicked() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc func showAboutPanel() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @available(macOS 13.0, *)
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc func openSettings() {
        if let configURL = Config.shared.ensureConfigFile() {
            NSWorkspace.shared.open(configURL)
        }
    }

    private func setupConfigParseErrorObserver() {
        configParseErrorObserver = NotificationCenter.default.addObserver(
            forName: Config.didFailToParseNotification,
            object: nil,
            queue: .main
        ) { notification in
            let detail = notification.userInfo?[Config.parseErrorUserInfoKey] as? String ?? ""
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString(
                "alert.configParseFailed.title", comment: "Config parse failure alert title")
            alert.informativeText = String(
                format: NSLocalizedString(
                    "alert.configParseFailed.message", comment: "Config parse failure alert message"),
                detail)
            alert.runModal()
        }
    }

    func setupWithAccessibilityCheck() {
        if AXIsProcessTrusted() {
            enableWindowOperation()
        } else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            startAccessibilityPolling()
        }
    }

    func startAccessibilityPolling() {
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.enableWindowOperation()
                self?.stopAccessibilityPolling()
            }
        }
    }

    func stopAccessibilityPolling() {
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
    }

    func enableWindowOperation() {
        guard windowOperation == nil else { return }
        windowOperation = WindowOperation()
    }
}
