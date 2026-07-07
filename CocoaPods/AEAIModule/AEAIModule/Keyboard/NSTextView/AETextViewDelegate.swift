//
//  AETextViewDelegate.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Cocoa

/// 文本包类型
public enum AETextPackageType {
    case text           // 普通文本
    case directory      // 目录指令 (:/开头)
    case permission     // 权限指令 (:p开头)
    case file           // 文件查找 (:?开头)
}

/// 文本包装类，用于包装 TextView 的输入信息
public class AETextPackage {

    /// 包类型
    public let type: AETextPackageType

    /// 原始文本内容
    public let rawText: String

    /// 处理后的文本内容（去除指���前缀）
    public let content: String

    /// 初始化方法
    /// - Parameter text: 输入的文本
    public init(text: String) {
        self.rawText = text

        // 判断类型并提取内容
        if text.hasPrefix(":/") {
            self.type = .directory
            self.content = String(text.dropFirst(2)) // 去除 ":/" 前缀
        } else if text.hasPrefix(":p") {
            self.type = .permission
            self.content = String(text.dropFirst(2)) // 去除 ":p" 前缀
        } else if text.hasPrefix(":?") {
            self.type = .file
            self.content = String(text.dropFirst(2)) // 去除 ":?" 前缀
        } else {
            self.type = .text
            self.content = text
        }
    }

    /// 便利方法：判断是否为指令类型
    public var isCommand: Bool {
        return type != .text
    }
}

/// AETextView 代理协议
public protocol AETextViewDelegate: AnyObject {

    /// 用户实时输入文本时调用
    /// - Parameters:
    ///   - textView: AETextView 实例
    ///   - package: 当前输入对应的文本包
    func aeTextView(_ textView: AETextView, didChangeInput package: AETextPackage)

    /// 用户按回车提交文本时调用
    /// - Parameters:
    ///   - textView: AETextView 实例
    ///   - package: 提交的文本包
    func aeTextView(_ textView: AETextView, didInputText package: AETextPackage)

    /// 文本高度变化时调用
    /// - Parameters:
    ///   - textView: AETextView 实例
    ///   - height: 计算好的高度
    func aeTextView(_ textView: AETextView, didChangeHeight height: CGFloat)

    /// 请求上一条历史记录（当前 Context 的）
    /// - Parameter textView: AETextView 实例
    /// - Returns: 上一条消息内容，如果没有则返回 nil
    func aeTextViewRequestPreviousHistory(_ textView: AETextView) -> String?

    /// 请求下一条历史记录（当前 Context 的）
    /// - Parameter textView: AETextView 实例
    /// - Returns: 下一条消息内容，如果没有则返回 nil
    func aeTextViewRequestNextHistory(_ textView: AETextView) -> String?
}
