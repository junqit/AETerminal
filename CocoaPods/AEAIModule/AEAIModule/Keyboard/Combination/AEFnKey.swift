//
//  AEFnKey.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AppKit

/// Fn 键组合处理
public class AEFnKey {

    /// 处理 Fn 键组合
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

        return key.isEmpty ? "" : key
    }

    /// 处理特殊按键
    private static func processSpecialKey(event: NSEvent) -> String {
        // Fn 键通常与功能键配合使用
        switch event.keyCode {
        case 0x7A: return "F1"          // F1
        case 0x78: return "F2"          // F2
        case 0x63: return "F3"          // F3
        case 0x76: return "F4"          // F4
        case 0x60: return "F5"          // F5
        case 0x61: return "F6"          // F6
        case 0x62: return "F7"          // F7
        case 0x64: return "F8"          // F8
        case 0x65: return "F9"          // F9
        case 0x6D: return "F10"         // F10
        case 0x67: return "F11"         // F11
        case 0x6F: return "F12"         // F12
        case 0x7B: return "Home"        // 左箭头 → Home
        case 0x7C: return "End"         // 右箭头 → End
        case 0x7D: return "PageDown"    // 下箭头 → Page Down
        case 0x7E: return "PageUp"      // 上箭头 → Page Up
        case 0x33: return "ForwardDelete" // Delete → Forward Delete
        default: return ""
        }
    }

    /// 判断是否为功能键
    public static func isFunctionKey(_ key: String) -> Bool {
        let functionKeys = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
        return functionKeys.contains(key)
    }

    /// 获取功能键的常见用途
    public static func getFunctionKeyUsage(_ key: String) -> String? {
        switch key {
        case "F1": return "帮助"
        case "F2": return "重命名"
        case "F3": return "显示桌面"
        case "F4": return "启动台"
        case "F5": return "键盘灯光减弱"
        case "F6": return "键盘灯光增强"
        case "F7": return "上一曲目"
        case "F8": return "播放/暂停"
        case "F9": return "下一曲目"
        case "F10": return "静音"
        case "F11": return "音量减小"
        case "F12": return "音量增大"
        default: return nil
        }
    }

    /// 获取快捷键描述
    public static func getShortcutDescription(_ key: String) -> String? {
        // 先检查是否为功能键
        if let usage = getFunctionKeyUsage(key) {
            return usage
        }

        // 其他快捷键
        switch key {
        case "Home": return "移动到文档开头"
        case "End": return "移动到文档结尾"
        case "PageUp": return "向上翻页"
        case "PageDown": return "向下翻页"
        case "ForwardDelete": return "向前删除"
        default: return nil
        }
    }
}
