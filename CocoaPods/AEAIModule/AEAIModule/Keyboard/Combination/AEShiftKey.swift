//
//  AEShiftKey.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AppKit

/// Shift 键组合处理
public class AEShiftKey {

    /// 处理 Shift 键组合
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

        // Shift 通常用于大写字母或特殊符号，保持原样
        return key
    }

    /// 处理特殊按键
    private static func processSpecialKey(event: NSEvent) -> String {
        switch event.keyCode {
        case 0x7B: return "Left"        // 左箭头
        case 0x7C: return "Right"       // 右箭头
        case 0x7D: return "Down"        // 下箭头
        case 0x7E: return "Up"          // 上箭头
        case 0x73: return "Home"        // Home
        case 0x77: return "End"         // End
        case 0x74: return "PageUp"      // Page Up
        case 0x79: return "PageDown"    // Page Down
        case 0x24: return "Return"      // 回车
        case 0x30: return "Tab"         // Tab
        default: return ""
        }
    }

    /// 判断是否为文本选择快捷键
    public static func isTextSelectionShortcut(_ key: String) -> Bool {
        // Shift + 箭头用于选择文本
        let selectionKeys = ["Left", "Right", "Up", "Down", "Home", "End", "PageUp", "PageDown"]
        return selectionKeys.contains(key)
    }

    /// 获取快捷键描述
    public static func getShortcutDescription(_ key: String) -> String? {
        switch key {
        case "Left": return "向左选择"
        case "Right": return "向右选择"
        case "Up": return "向上选择"
        case "Down": return "向下选择"
        case "Home": return "选择到行首"
        case "End": return "选择到行尾"
        case "PageUp": return "向上选择一页"
        case "PageDown": return "向下选择一页"
        default: return nil
        }
    }
}
