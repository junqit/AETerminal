//
//  AECommandKey.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AppKit

/// Command 键组合处理
public class AECommandKey {

    /// 处理 Command 键组合
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

        // 返回大写字母
        return key.uppercased()
    }

    /// 处理特殊按键
    private static func processSpecialKey(event: NSEvent) -> String {
        switch event.keyCode {
        case 0x33: return "Delete"          // 删除键
        case 0x75: return "ForwardDelete"   // 向前删除
        case 0x24: return "Return"          // 回车
        case 0x30: return "Tab"             // Tab
        case 0x31: return "Space"           // 空格
        case 0x35: return "Escape"          // Esc
        case 0x7B: return "Left"            // 左箭头
        case 0x7C: return "Right"           // 右箭头
        case 0x7D: return "Down"            // 下箭头
        case 0x7E: return "Up"              // 上箭头
        case 0x73: return "Home"            // Home
        case 0x77: return "End"             // End
        case 0x74: return "PageUp"          // Page Up
        case 0x79: return "PageDown"        // Page Down
        default: return ""
        }
    }

    /// 判断是否为系统快捷键
    public static func isSystemShortcut(_ key: String) -> Bool {
        let systemKeys = ["C", "V", "X", "Z", "A", "S", "Q", "W", "N", "O", "P", "T", "F"]
        return systemKeys.contains(key.uppercased())
    }

    /// 获取快捷键描述
    public static func getShortcutDescription(_ key: String) -> String? {
        switch key.uppercased() {
        case "C": return "复制"
        case "V": return "粘贴"
        case "X": return "剪切"
        case "Z": return "撤销"
        case "A": return "全选"
        case "S": return "保存"
        case "Q": return "退出"
        case "W": return "关闭窗口"
        case "N": return "新建"
        case "O": return "打开"
        case "P": return "打印"
        case "T": return "新标签"
        case "F": return "查找"
        default: return nil
        }
    }
}
