import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.heavewindow.HeaveWindow", category: "Config")

struct HotkeyConfig: Decodable {
    let modifiers: [String]
    let key: String

    static let `default` = HotkeyConfig(
        modifiers: ["option", "shift"],
        key: "space"
    )
}

struct AppConfig: Decodable {
    let hotkey: HotkeyConfig?
}

class Config {
    static let shared = Config()

    static let didReloadNotification = Notification.Name("ConfigDidReload")
    static let didFailToParseNotification = Notification.Name("ConfigDidFailToParse")
    static let parseErrorUserInfoKey = "error"

    let configPath: String
    private(set) var appConfig: AppConfig?
    private var configDirectoryMonitor: DispatchSourceFileSystemObject?
    private var hadParseError = false

    static let defaultConfigContent = """
        hotkey:
          modifiers:
            - option
            - shift
          key: space
        """

    var hotkeyConfig: HotkeyConfig {
        appConfig?.hotkey ?? HotkeyConfig.default
    }

    static let defaultConfigPath =
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.config/heave-window/config.yml"

    init(configPath: String = Config.defaultConfigPath) {
        self.configPath = configPath
        reload()
        startWatchingConfigDirectory()
    }

    deinit {
        configDirectoryMonitor?.cancel()
    }

    func reload() {
        defer {
            NotificationCenter.default.post(name: Config.didReloadNotification, object: self)
        }

        guard FileManager.default.fileExists(atPath: configPath),
            let yamlString = try? String(contentsOfFile: configPath, encoding: .utf8)
        else {
            appConfig = nil
            hadParseError = false
            return
        }

        do {
            appConfig = try YAMLDecoder().decode(AppConfig.self, from: yamlString)
            hadParseError = false
        } catch {
            logger.error("Failed to parse config: \(error)")
            appConfig = nil
            if !hadParseError {
                hadParseError = true
                NotificationCenter.default.post(
                    name: Config.didFailToParseNotification,
                    object: self,
                    userInfo: [Config.parseErrorUserInfoKey: "\(error)"]
                )
            }
        }
    }

    private func startWatchingConfigDirectory() {
        guard configDirectoryMonitor == nil else { return }

        let configDir = (configPath as NSString).deletingLastPathComponent
        let fileDescriptor = open(configDir, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor, eventMask: .write, queue: .main)
        monitor.setEventHandler { [weak self] in
            self?.reload()
        }
        monitor.setCancelHandler {
            close(fileDescriptor)
        }
        monitor.resume()
        configDirectoryMonitor = monitor
    }

    func ensureConfigFile() -> URL? {
        let configURL = URL(fileURLWithPath: configPath)
        if FileManager.default.fileExists(atPath: configPath) {
            return configURL
        }

        let configDir = (configPath as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(
                atPath: configDir, withIntermediateDirectories: true, attributes: nil)
            try Config.defaultConfigContent.write(
                toFile: configPath, atomically: true, encoding: .utf8)
            reload()
            startWatchingConfigDirectory()
            return configURL
        } catch {
            logger.error("Failed to create default config: \(error)")
            return nil
        }
    }
}
