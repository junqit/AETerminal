//
//  AEKeyCode.swift
//  AEAIEngin
//
//  键盘按键码定义
//

import Foundation

/// 键盘按键码常量
public enum AEKeyCode {

    // MARK: - Arrow Keys

    /// 上箭头
    public static let upArrow: UInt16 = 126

    /// 下箭头
    public static let downArrow: UInt16 = 125

    /// 左箭头
    public static let leftArrow: UInt16 = 123

    /// 右箭头
    public static let rightArrow: UInt16 = 124

    // MARK: - Return Keys

    /// Return 键
    public static let `return`: UInt16 = 36

    /// Enter 键（数字键盘）
    public static let enter: UInt16 = 76

    // MARK: - Function Keys

    /// Escape 键
    public static let escape: UInt16 = 53

    /// Delete 键（向后删除）
    public static let delete: UInt16 = 51

    /// Forward Delete 键（向前删除）
    public static let forwardDelete: UInt16 = 117

    /// Tab 键
    public static let tab: UInt16 = 48

    /// Space 键
    public static let space: UInt16 = 49

    // MARK: - Navigation Keys

    /// Home 键
    public static let home: UInt16 = 115

    /// End 键
    public static let end: UInt16 = 119

    /// Page Up 键
    public static let pageUp: UInt16 = 116

    /// Page Down 键
    public static let pageDown: UInt16 = 121
}
