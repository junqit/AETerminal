//
//  AEMultiChatView.swift
//  AEAIModule
//
//  横向排列的聊天视图包装器 - 支持同时显示多个 Context 的会话界面
//

import AppKit
import AEAIEnginModule
import AELogProxy


/// 多 Context 聊天视图包装器
public class AEMultiChatView: NSView {

    // MARK: - Properties

    /// 水平堆栈视图，用于横向排列聊天视图
    @IBOutlet private weak var stackView: NSStackView!

    /// 聊天视图字典 [contextId: AEChatViewContainer]
    private var chatViews: [String: AEChatViewContainer] = [:]

    /// 当前激活的 Context ID
    private var activeContextId: String?

    /// 代理
    public weak var delegate: AEMultiChatViewDelegate?

    /// 内容视图（从 XIB 加载）
    private var contentView: NSView?

    // MARK: - Initialization

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // MARK: - Setup

    private func commonInit() {
        if !loadFromNib() {
            setupUI()
        }
    }

    /// 从 NIB 加载视图
    /// - Returns: 加载是否成功
    private func loadFromNib() -> Bool {
        // 获取 Bundle
        let bundle = Bundle(for: type(of: self))

        // 尝试加载 NIB
        var topLevelObjects: NSArray?
        guard bundle.loadNibNamed("AEMultiChatView", owner: self, topLevelObjects: &topLevelObjects) else {
            return false
        }

        // 查找内容视图
        guard let objects = topLevelObjects as? [AnyObject],
              let view = objects.first(where: { $0 is NSView && $0 !== self }) as? NSView else {
            return false
        }

        // 设置内容视图
        contentView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        // 设置约束
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        return true
    }

    private func setupUI() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 1.0
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        self.stackView = stack

        // 设置约束
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        // 如果 stackView 已经通过 IBOutlet 连接，则不需要再创建
        if stackView == nil {
            setupUI()
        }
    }

    /// 添加到堆栈视图
    /// - Parameter view: 要添加的视图
    private func addToStackView(_ view: NSView) {
        guard let stackView = stackView else {
            AELog("⚠️ [AEMultiChatView] stackView 未初始化")
            return
        }
        stackView.addArrangedSubview(view)
    }

    /// 从堆栈视图移除
    /// - Parameter view: 要移除的视图
    private func removeFromStackView(_ view: NSView) {
        guard let stackView = stackView else {
            AELog("⚠️ [AEMultiChatView] stackView 未初始化")
            return
        }
        stackView.removeArrangedSubview(view)
    }

    // MARK: - Public Methods

    /// 添加新的 Context 聊天视图
    /// - Parameters:
    ///   - contextId: Context 唯一标识
    ///   - contextName: Context 显示名称
    /// - Returns: 创建的聊天视图
    @discardableResult
    public func addChatView(for contextId: String, contextName: String) -> AEChatView {

        // 如果已存在，返回现有的
        if let existing = chatViews[contextId] {
            return existing.chatView
        }

        // 创建容器
        let container = AEChatViewContainer(contextId: contextId, contextName: contextName)
        container.delegate = self

        // 添加到堆栈视图
        addToStackView(container)

        // 保存到字典
        chatViews[contextId] = container

        // 如果是第一个，设置为激活
        if activeContextId == nil {
            setActiveContext(contextId)
        }

        // 通知代理
        delegate?.multiChatView(self, didAddContext: contextId)

        return container.chatView
    }

    /// 移除 Context 聊天视图
    /// - Parameter contextId: Context 唯一标识
    public func removeChatView(for contextId: String) {

        guard let container = chatViews[contextId] else {
            AELog("⚠️ [AEMultiChatView] Context 不存在: \(contextId)")
            return
        }

        // 从堆栈视图移除
        removeFromStackView(container)
        container.removeFromSuperview()

        // 从字典移除
        chatViews.removeValue(forKey: contextId)

        // 如果移除的是当前激活的，切换到其他的
        if activeContextId == contextId {
            activeContextId = chatViews.keys.first
            if let newActiveId = activeContextId {
                setActiveContext(newActiveId)
            }
        }

        // 通知代理
        delegate?.multiChatView(self, didRemoveContext: contextId)
    }

    /// 获取指定 Context 的聊天视图
    /// - Parameter contextId: Context 唯一标识
    /// - Returns: 聊天视图，如果不存在则返回 nil
    public func getChatView(for contextId: String) -> AEChatView? {
        return chatViews[contextId]?.chatView
    }

    /// 设置激活的 Context
    /// - Parameter contextId: Context 唯一标识
    public func setActiveContext(_ contextId: String) {

        guard let container = chatViews[contextId] else {
            AELog("⚠️ [AEMultiChatView] Context 不存在: \(contextId)")
            return
        }

        // 取消之前的激活状态
        if let previousId = activeContextId, let previousContainer = chatViews[previousId] {
            previousContainer.setActive(false)
        }

        // 设置新的激活状态
        activeContextId = contextId
        container.setActive(true)

        // 通知代理
        delegate?.multiChatView(self, didActivateContext: contextId)
    }

    /// 获取当前激活的 Context ID
    /// - Returns: 当前激活的 Context ID，如果没有则返回 nil
    public func getActiveContextId() -> String? {
        return activeContextId
    }

    /// 获取所有 Context ID 列表
    /// - Returns: Context ID 数组
    public func getAllContextIds() -> [String] {
        return Array(chatViews.keys)
    }

    /// 清空所有聊天视图
    public func removeAllChatViews() {

        let contextIds = Array(chatViews.keys)
        for contextId in contextIds {
            removeChatView(for: contextId)
        }

        activeContextId = nil
    }

    /// 向指定 Context 的聊天视图发送消息（同步处理）
    /// - Parameters:
    ///   - contextId: Context 唯一标识
    ///   - message: 消息内容
    ///   - type: 消息类型
    public func sendMessage(to contextId: String, message: String, type: MessageType) {
        guard let container = chatViews[contextId] else {
            AELog("⚠️ [AEMultiChatView] Context 不存在: \(contextId)")
            return
        }

        switch type {
        case .user:
            container.chatView.addUserMessage(message)
        case .assistant(let isMarkdown, let assistantName):
            container.chatView.addAssistantMessage(message, isMarkdown: isMarkdown, assistantName: assistantName)
        case .system:
            container.chatView.addSystemMessage(message)
        case .error:
            container.chatView.addErrorMessage(message)
        }
    }

    /// 向所有 Context 的聊天视图广播消息
    /// - Parameters:
    ///   - message: 消息内容
    ///   - type: 消息类型
    public func broadcastMessage(_ message: String, type: MessageType) {

        for contextId in chatViews.keys {
            sendMessage(to: contextId, message: message, type: type)
        }
    }

    // MARK: - Context Message Methods

    /// 确认当前 Context 并显示 workspace 信息
    /// - Parameter config: Context 配置对象
    public func confirmCurrentContext(_ config: AEAIContextConfig) {
        let contextId = config.ident
        if chatViews[contextId] == nil {
            addChatView(for: contextId, contextName: "\(config.type.rawValue) - \(config.space)")
        }
        setActiveContext(contextId)
        let info = "Workspace: \(config.space) [\(config.type.rawValue)]"
        sendMessage(to: contextId, message: info, type: .system)
    }

    /// 显示用户问题到指定 Context
    /// - Parameters:
    ///   - question: AI 问题对象
    ///   - config: Context 配置对象
    public func showUserQuestion(_ question: AEAIQuestion, for config: AEAIContextConfig) {
        // 确保 Context 的聊天视图存在
        let contextId = config.ident
        if chatViews[contextId] == nil {
            addChatView(for: contextId, contextName: "\(config.type.rawValue) - \(config.space)")
        }

        // 显示用户消息
        sendMessage(to: contextId, message: question.content, type: .user)
    }

    /// 显示 AI 响应到指定 Context
    /// - Parameters:
    ///   - response: 响应内容
    ///   - config: Context 配置对象
    public func showAIResponse(_ response: String, for config: AEAIContextConfig) {
        let contextId = config.ident

        // 确保 Context 的聊天视图存在
        if chatViews[contextId] == nil {
            addChatView(for: contextId, contextName: "\(config.type.rawValue) - \(config.space)")
        }

        // 显示 AI 响应
        sendMessage(to: contextId, message: response, type: .assistant(isMarkdown: true, assistantName: "AI"))
    }

    /// 显示错误消息到指定 Context
    /// - Parameters:
    ///   - error: 错误信息
    ///   - config: Context 配置对象
    public func showError(_ error: String, for config: AEAIContextConfig) {
        let contextId = config.ident

        // 确保 Context 的聊天视图存在
        if chatViews[contextId] == nil {
            addChatView(for: contextId, contextName: "\(config.type.rawValue) - \(config.space)")
        }

        // 显示错误消息
        sendMessage(to: contextId, message: error, type: .error)
    }

    /// 显示系统消息到指定 Context
    /// - Parameters:
    ///   - message: 系统消息
    ///   - config: Context 配置对象
    public func showSystemMessage(_ message: String, for config: AEAIContextConfig) {
        let contextId = config.ident

        // 确保 Context 的聊天视图存在
        if chatViews[contextId] == nil {
            addChatView(for: contextId, contextName: "\(config.type.rawValue) - \(config.space)")
        }

        // 显示系统消息
        sendMessage(to: contextId, message: message, type: .system)
    }
}

// MARK: - AEChatViewContainerDelegate

extension AEMultiChatView: AEChatViewContainerDelegate {

    func containerDidTap(_ container: AEChatViewContainer) {
        setActiveContext(container.contextId)
    }

    func containerDidClose(_ container: AEChatViewContainer) {
        removeChatView(for: container.contextId)
    }
}

// MARK: - Public Protocols

/// 多聊天视图代理协议
public protocol AEMultiChatViewDelegate: AnyObject {
    /// Context 添加时调用
    func multiChatView(_ view: AEMultiChatView, didAddContext contextId: String)

    /// Context 移除时调用
    func multiChatView(_ view: AEMultiChatView, didRemoveContext contextId: String)

    /// Context 激活时调用
    func multiChatView(_ view: AEMultiChatView, didActivateContext contextId: String)
}

/// 消息类型
public enum MessageType {
    case user
    case assistant(isMarkdown: Bool, assistantName: String)
    case system
    case error
}

