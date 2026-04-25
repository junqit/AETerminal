//
//  AETextViewDelegate.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Cocoa

/// AETextView 代理协议
public protocol AETextViewDelegate: AnyObject {

    /// 用户按回车提交文本时调用
    /// - Parameters:
    ///   - textView: AETextView 实例
    ///   - text: 提交的文本内容
    func aeTextView(_ textView: AETextView, didInputText text: String)

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
