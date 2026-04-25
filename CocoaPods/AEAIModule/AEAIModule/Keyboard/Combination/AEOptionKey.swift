//
//  AEOptionKey.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AppKit

/// Option 键组合处理
public class AEOptionKey {

    /// 处理 Option 键组合
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

        // Option 键可能产生特殊字符，保持原样
        return key.isEmpty ? "" : key
    }

    /// 处理特殊按键
    private static func processSpecialKey(event: NSEvent) -> String {
        switch event.keyCode {
        case 0x7B: return "Left"            // 左箭头
        case 0x7C: return "Right"           // 右箭头
        case 0x7D: return "Down"            // 下箭头
        case 0x7E: return "Up"              // 上箭头
        case 0x33: return "Delete"          // 删除键
        case 0x75: return "ForwardDelete"   // 向前删除
        default: return ""
        }
    }

    /// 判断是否为文本编辑快捷键
    public static func isTextEditingShortcut(_ key: String) -> Bool {
        // Option + 箭头用于按单词移动
        let editKeys = ["Left", "Right", "Delete", "ForwardDelete"]
        return editKeys.contains(key)
    }

    /// 获取快捷键描述
    public static func getShortcutDescription(_ key: String) -> String? {
        switch key {
        case "Left": return "按单词向左移动"
        case "Right": return "按单词向右移动"
        case "Delete": return "删除前一个单词"
        case "ForwardDelete": return "删除后一个单词"
        default: return nil
        }
    }
}
