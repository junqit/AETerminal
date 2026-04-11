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

    /// 滚动视图
    private var scrollView: NSScrollView!

    /// 文本视图用于显示聊天内容
    private var textView: NSTextView!

    /// 消息记录
    private var messages: [(type: MessageType, content: String)] = []

    enum MessageType {
        case user      // 用户输入
        case assistant // AI 响应
        case system    // 系统消息
        case error     // 错误消息
    }

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
        print("🎨 AEChatView setupUI 开始")

        // 创建滚动视图
        scrollView = NSScrollView(frame: bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false // 改为 false，确保滚动条可见
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor

        // 创建文本视图 - 使用完整的初始化
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        textView = NSTextView(frame: bounds, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // 设置最小尺寸
        textView.minSize = NSSize(width: 0, height: bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView

        addSubview(scrollView)

        // 设置约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        print("🎨 AEChatView setupUI 完成, frame: \(bounds)")
    }

    // MARK: - Public Methods

    /// 添加用户消息
    func addUserMessage(_ message: String) {
        print("💬 AEChatView.addUserMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .user, content: message))
            self?.appendMessage(message, type: .user)
        }
    }

    /// 添加 AI 响应消息
    func addAssistantMessage(_ message: String) {
        print("🤖 AEChatView.addAssistantMessage: \(message.prefix(100))...")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .assistant, content: message))
            self?.appendMessage(message, type: .assistant)
        }
    }

    /// 添加系统消息
    func addSystemMessage(_ message: String) {
        print("⚙️ AEChatView.addSystemMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .system, content: message))
            self?.appendMessage(message, type: .system)
        }
    }

    /// 添加错误消息
    func addErrorMessage(_ message: String) {
        print("❌ AEChatView.addErrorMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .error, content: message))
            self?.appendMessage(message, type: .error)
        }
    }

    /// 清空所有消息
    func clearMessages() {
        print("🗑️ AEChatView.clearMessages")
        DispatchQueue.main.async { [weak self] in
            self?.messages.removeAll()
            self?.textView.string = ""
        }
    }

    /// 测试方法 - 添加欢迎消息
    func addWelcomeMessage() {
        print("👋 AEChatView.addWelcomeMessage")
        addSystemMessage("欢迎使用 AI Terminal！开始你的对话吧。")
    }

    // MARK: - Private Methods

    /// 将消息追加到文本视图
    private func appendMessage(_ message: String, type: MessageType) {
        guard let storage = textView.textStorage else {
            print("⚠️ textView.textStorage is nil")
            return
        }

        print("📝 appendMessage - 当前文本长度: \(storage.length), 新消息类型: \(type)")

        let timestamp = formatTimestamp(Date())
        let prefix: String
        let color: NSColor

        switch type {
        case .user:
            prefix = "👤 User"
            color = .systemBlue
        case .assistant:
            prefix = "🤖 Assistant"
            color = .systemGreen
        case .system:
            prefix = "⚙️ System"
            color = .systemOrange
        case .error:
            prefix = "❌ Error"
            color = .systemRed
        }

        // 如果不是第一条消息，添加分隔线
        if storage.length > 0 {
            let separator = NSAttributedString(string: "\n" + String(repeating: "─", count: 60) + "\n", attributes: [
                .foregroundColor: NSColor.separatorColor,
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .light)
            ])
            storage.append(separator)
        }

        // 创建消息头部（带颜色和粗体）
        let header = "[\(timestamp)] \(prefix)\n"
        let headerAttr = NSAttributedString(string: header, attributes: [
            .foregroundColor: color,
            .font: NSFont.boldSystemFont(ofSize: 13)
        ])

        // 创建消息内容（使用明确的颜色，而不是系统颜色）
        let contentColor: NSColor
        if #available(macOS 10.14, *) {
            contentColor = NSColor(name: nil) { appearance in
                // 根据外观自动选择颜色
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return .white // 深色模式用白色
                } else {
                    return .black // 浅色模式用黑色
                }
            }
        } else {
            contentColor = .labelColor
        }

        let contentAttr = NSAttributedString(string: "\(message)\n", attributes: [
            .foregroundColor: contentColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ])

        // 追加消息
        storage.append(headerAttr)
        storage.append(contentAttr)

        print("✅ appendMessage 完成 - 新文本长度: \(storage.length)")

        // 滚动到底部
        scrollToBottom()
    }

    /// 格式化时间戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 滚动到底部
    private func scrollToBottom() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let range = NSRange(location: self.textView.string.count, length: 0)
            self.textView.scrollRangeToVisible(range)
            print("📜 滚动到底部, 文本长度: \(self.textView.string.count)")
        }
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
