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

    /// 当前选中的 context 索引（用于键盘导航）
    private var selectedContextIndex: Int? = nil

    /// 可供选择的 contexts（示例，实际可能从外部传入）
    private var contexts: [String] = []

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
            // 方向键通过 keyCode 判断
            switch event.keyCode {
            case AEKeyCode.upArrow:
                selectPreviousContext()
                return true
            case AEKeyCode.downArrow:
                selectNextContext()
                return true
            default:
                break
            }

            // 其他字母键
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

        // 处理回车键（确认选择）
        if event.keyCode == AEKeyCode.return || event.keyCode == AEKeyCode.enter {
            confirmSelectedContext()
            return true
        }

        return false
    }

    // MARK: - Keyboard Navigation

    /// 向上选择 context
    private func selectPreviousContext() {
        guard !contexts.isEmpty else { return }

        if let currentIndex = selectedContextIndex, currentIndex > 0 {
            selectedContextIndex = currentIndex - 1
        } else {
            selectedContextIndex = 0
        }

        updateContextSelection()
        print("选中 context: \(selectedContextIndex ?? -1)")
    }

    /// 向下选择 context
    private func selectNextContext() {
        guard !contexts.isEmpty else { return }

        if let currentIndex = selectedContextIndex, currentIndex < contexts.count - 1 {
            selectedContextIndex = currentIndex + 1
        } else {
            selectedContextIndex = contexts.count - 1
        }

        updateContextSelection()
        print("选中 context: \(selectedContextIndex ?? -1)")
    }

    /// 确认选中的 context
    private func confirmSelectedContext() {
        guard let index = selectedContextIndex, index < contexts.count else {
            print("⚠️ 没有选中的 context")
            return
        }

        let selectedContext = contexts[index]
        print("✅ 确认选择 context: \(selectedContext)")

        // TODO: 通过 delegate 通知外部
        // delegate?.chatView(self, didSelectContext: selectedContext)

        // 清除选中状态
        selectedContextIndex = nil
        updateContextSelection()
    }

    /// 更新 context 选中状态的视觉反馈
    private func updateContextSelection() {
        // TODO: 实现选中状态的视觉反馈（例如高亮显示）
        needsDisplay = true
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
