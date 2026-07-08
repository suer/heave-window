import Carbon
import XCTest

final class HotkeyParserTests: XCTestCase {
    func testParsesConfiguredKeyAndModifiers() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: ["option", "shift"], key: "space"))

        XCTAssertEqual(parsed.keyCode, Int64(kVK_Space))
        XCTAssertEqual(parsed.modifierFlags, [.maskAlternate, .maskShift])
    }

    func testAcceptsModifierAliases() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: ["cmd", "ctrl"], key: "k"))

        XCTAssertEqual(parsed.keyCode, Int64(kVK_ANSI_K))
        XCTAssertEqual(parsed.modifierFlags, [.maskCommand, .maskControl])
    }

    func testIgnoresCase() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: ["Option", "SHIFT"], key: "Space"))

        XCTAssertEqual(parsed.keyCode, Int64(kVK_Space))
        XCTAssertEqual(parsed.modifierFlags, [.maskAlternate, .maskShift])
    }

    func testFallsBackToDefaultForUnknownKey() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: ["option"], key: "unknown"))

        XCTAssertEqual(parsed.keyCode, ParsedHotkey.default.keyCode)
        XCTAssertEqual(parsed.modifierFlags, ParsedHotkey.default.modifierFlags)
    }

    func testFallsBackToDefaultForUnknownModifier() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: ["option", "hyper"], key: "a"))

        XCTAssertEqual(parsed.keyCode, ParsedHotkey.default.keyCode)
        XCTAssertEqual(parsed.modifierFlags, ParsedHotkey.default.modifierFlags)
    }

    func testFallsBackToDefaultForEmptyModifiers() {
        let parsed = ParsedHotkey.from(
            config: HotkeyConfig(modifiers: [], key: "a"))

        XCTAssertEqual(parsed.keyCode, ParsedHotkey.default.keyCode)
        XCTAssertEqual(parsed.modifierFlags, ParsedHotkey.default.modifierFlags)
    }
}
