//
//  AEChatView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit
import AEAIEngin

/// 聊天视图 - 显示对话内容
class AEChatView: NSView {

    // MARK: - Properties

    /// 是否是焦点视图
    private var isFocused: Bool = false

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        registerCombinationKeyHandler()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        registerCombinationKeyHandler()
    }

    deinit {
        AECombinationKeyManager.shared.unregister(self)
    }

    /// 注册组合键处理器
    private func registerCombinationKeyHandler() {
        AECombinationKeyManager.shared.register(self)
    }

    // MARK: - Setup

    private func setupUI() {
        // TODO: 设置聊天视图 UI
    }
}

// MARK: - AECombinationKeyHandler

extension AEChatView: AECombinationKeyHandler {

    public var combinationKeyHandlerID: String {
        return "AEChatView"
    }

    public func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        // 由业务层自己判断是否需要处理（检查焦点状态）
        guard window?.firstResponder == self || isFocused else {
            return false // 没有焦点，不处理
        }

        // 处理 Command 键组合
        if modifiers.contains(.command) {
            switch key.uppercased() {
            case "C":
                print("⌘C: 复制聊天内容")
                // TODO: 复制选中的聊天内容
                return true
            case "K":
                print("⌘K: 清空聊天记录")
                // TODO: 清空聊天记录
                return true
            default:
                break
            }
        }

        return false
    }

    // MARK: - Focus Handling

    public override func becomeFirstResponder() -> Bool {
        isFocused = true
        return super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        isFocused = false
        return super.resignFirstResponder()
    }
}
