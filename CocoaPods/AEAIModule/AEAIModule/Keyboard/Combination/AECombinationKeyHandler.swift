//
//  AECombinationKeyHandler.swift
//  AEAIEngin
//
//  组合键处理协议
//

import Cocoa

/// 组合键处理协议
public protocol AECombinationKeyHandler: AnyObject {

    /// 视图的唯一标识（用于注册和注销）
    var combinationKeyHandlerID: String { get }

    /// 处理组合键事件
    /// - Parameters:
    ///   - event: 键盘事件
    ///   - modifiers: 修饰键（Command, Option, Shift, Control, Fn）
    ///   - key: 按键字符
    /// - Returns: 是否已消费该事件（返回 true 表示已消费，停止传递给其他处理器）
    /// - Note: 管理器会把所有组合键事件发送给所有已注册的处理器，由处理器自己判断是否需要消费（例如检查焦点状态）
    func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool
}

/// 组合键类型
public enum AECombinationKeyType {
    
    case command    // ⌘ Command
    case option     // ⌥ Option
    case shift      // ⇧ Shift
    case control    // ⌃ Control
    case function   // Fn

    /// 对应的修饰键标志
    public var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .option:
            return .option
        case .shift:
            return .shift
        case .control:
            return .control
        case .function:
            return .function
        }
    }

    /// 符号表示
    public var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .shift:
            return "⇧"
        case .control:
            return "⌃"
        case .function:
            return "Fn"
        }
    }
}
