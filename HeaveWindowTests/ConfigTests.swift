import XCTest

final class ConfigTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    private var configPath: String {
        tempDir.appendingPathComponent("config.yml").path
    }

    func testFallsBackToDefaultHotkeyWhenFileIsMissing() {
        let config = Config(configPath: configPath)

        XCTAssertNil(config.appConfig)
        XCTAssertEqual(config.hotkeyConfig.key, HotkeyConfig.default.key)
        XCTAssertEqual(config.hotkeyConfig.modifiers, HotkeyConfig.default.modifiers)
    }

    func testParsesHotkeyFromYAML() throws {
        try """
        hotkey:
          modifiers:
            - command
            - control
          key: m
        """.write(toFile: configPath, atomically: true, encoding: .utf8)

        let config = Config(configPath: configPath)

        XCTAssertEqual(config.hotkeyConfig.key, "m")
        XCTAssertEqual(config.hotkeyConfig.modifiers, ["command", "control"])
    }

    func testFallsBackToDefaultAndNotifiesOnInvalidYAML() throws {
        try "hotkey: [broken".write(toFile: configPath, atomically: true, encoding: .utf8)

        let notified = expectation(
            forNotification: Config.didFailToParseNotification, object: nil)
        let config = Config(configPath: configPath)

        wait(for: [notified], timeout: 1)
        XCTAssertNil(config.appConfig)
        XCTAssertEqual(config.hotkeyConfig.key, HotkeyConfig.default.key)
    }

    func testReloadPicksUpChanges() throws {
        try """
        hotkey:
          modifiers:
            - option
          key: a
        """.write(toFile: configPath, atomically: true, encoding: .utf8)
        let config = Config(configPath: configPath)
        XCTAssertEqual(config.hotkeyConfig.key, "a")

        try """
        hotkey:
          modifiers:
            - option
          key: b
        """.write(toFile: configPath, atomically: true, encoding: .utf8)
        config.reload()

        XCTAssertEqual(config.hotkeyConfig.key, "b")
    }

    func testEnsureConfigFileCreatesDefaultConfig() {
        let config = Config(configPath: configPath)

        let url = config.ensureConfigFile()

        XCTAssertEqual(url?.path, configPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
        XCTAssertEqual(config.hotkeyConfig.key, HotkeyConfig.default.key)
        XCTAssertEqual(config.hotkeyConfig.modifiers, HotkeyConfig.default.modifiers)
    }

    func testEnsureConfigFileKeepsExistingConfig() throws {
        try """
        hotkey:
          modifiers:
            - command
          key: x
        """.write(toFile: configPath, atomically: true, encoding: .utf8)
        let config = Config(configPath: configPath)

        let url = config.ensureConfigFile()

        XCTAssertEqual(url?.path, configPath)
        XCTAssertEqual(config.hotkeyConfig.key, "x")
    }
}
