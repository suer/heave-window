import Carbon
import Cocoa
import os

private let logger = Logger(subsystem: "com.heavewindow.HeaveWindow", category: "HotkeyParser")

struct ParsedHotkey {
    let keyCode: Int64
    let modifierFlags: CGEventFlags

    static let `default` = ParsedHotkey(
        keyCode: Int64(kVK_Space),
        modifierFlags: [.maskAlternate, .maskShift]
    )

    static func from(config: HotkeyConfig) -> ParsedHotkey {
        guard let keyCode = keyCodeMap[config.key.lowercased()] else {
            logger.warning(
                "Unknown key \"\(config.key, privacy: .public)\" in hotkey config, using default hotkey")
            return .default
        }

        var flags: CGEventFlags = []
        for modifier in config.modifiers {
            guard let flag = modifierMap[modifier.lowercased()] else {
                logger.warning(
                    "Unknown modifier \"\(modifier, privacy: .public)\" in hotkey config, using default hotkey")
                return .default
            }
            flags.insert(flag)
        }

        if flags.isEmpty {
            logger.warning("No modifiers in hotkey config, using default hotkey")
            return .default
        }

        return ParsedHotkey(keyCode: Int64(keyCode), modifierFlags: flags)
    }
}

private let keyCodeMap: [String: Int] = [
    "space": kVK_Space,
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
    "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
    "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
    "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
    "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
    "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
    "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
    "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
    "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
    "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    "escape": kVK_Escape, "return": kVK_Return, "tab": kVK_Tab, "delete": kVK_Delete,
    "up": kVK_UpArrow, "down": kVK_DownArrow, "left": kVK_LeftArrow, "right": kVK_RightArrow,
]

private let modifierMap: [String: CGEventFlags] = [
    "option": .maskAlternate,
    "alt": .maskAlternate,
    "command": .maskCommand,
    "cmd": .maskCommand,
    "control": .maskControl,
    "ctrl": .maskControl,
    "shift": .maskShift,
]
