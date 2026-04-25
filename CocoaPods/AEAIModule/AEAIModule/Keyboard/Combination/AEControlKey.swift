//
//  AEControlKey.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AppKit

/// Control 键组合处理
public class AEControlKey {

    /// 处理 Control 键组合
    /// - Parameters:
    ///   - key: 按下的键字符
    ///   - event: 键盘事件
    /// - Returns: 处理后的键字符
    public static func process(key: String, event: NSEvent) -> String {
        // 处理特殊按键码
        let processedKey = processSpecialKey(event: event)
        if !processedKey.isEmpty {
            return processedKey
        }

        // Control 键通常产生控制字符，返回大写
        return key.isEmpty ? "" : key.uppercased()
    }

    /// 处理特殊按键
    private static func processSpecialKey(event: NSEvent) -> String {
        switch event.keyCode {
        case 0x7B: return "Left"        // 左箭头
        case 0x7C: return "Right"       // 右箭头
        case 0x7D: return "Down"        // 下箭头
        case 0x7E: return "Up"          // 上箭头
        case 0x31: return "Space"       // 空格
        default: return ""
        }
    }

    /// 判断是否为 Emacs 风格快捷键
    public static func isEmacsShortcut(_ key: String) -> Bool {
        // 常见的 Emacs 风格快捷键
        let emacsKeys = ["A", "E", "D", "K", "N", "P", "F", "B", "H", "W", "U"]
        return emacsKeys.contains(key.uppercased())
    }

    /// 获取 Emacs 快捷键描述
    public static func getEmacsDescription(_ key: String) -> String? {
        switch key.uppercased() {
        case "A": return "移动到行首"
        case "E": return "移动到行尾"
        case "D": return "删除光标后字符"
        case "K": return "删除到行尾"
        case "N": return "下一行"
        case "P": return "上一行"
        case "F": return "向前移动"
        case "B": return "向后移动"
        case "H": return "删除前一个字符"
        case "W": return "删除前一个单词"
        case "U": return "删除整行"
        default: return nil
        }
    }

    /// 获取快捷键描述
    public static func getShortcutDescription(_ key: String) -> String? {
        return getEmacsDescription(key)
    }
}
