//
//  AEChatViewNew.swift
//  AEAIModule
//
//  使用 NSTableView 的新聊天视图 - 支持 cell 复用，降低内存占用
//

import AppKit

/// 聊天视图 - 使用 TableView 实现
public class AEChatViewNew: NSView {

    // MARK: - Properties

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    /// 消息数据源
    private var messages: [ChatMessage] = []

    /// Markdown 渲染器
    private let markdownRenderer = MarkdownRenderer(fontSize: 13)

    /// 响应解析器
    private let responseParser = AEAIResponseParser()

    // MARK: - Initialization

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        print("🎨 AEChatViewNew setupUI 开始")

        // 创建 TableView
        tableView = NSTableView()
        tableView.headerView = nil  // 不显示表头
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []  // 无网格线
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowSizeStyle = .custom
        // 不使用自动行高，我们手动计算
        tableView.selectionHighlightStyle = .none  // 无选中高亮

        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MessageColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        // Cell 不需要预先注册，会在 makeView 时自动创建

        // 设置数据源和代理
        tableView.dataSource = self
        tableView.delegate = self

        // 创建 ScrollView
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // 设置背景色
        if #available(macOS 10.14, *) {
            scrollView.backgroundColor = NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                } else {
                    return NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
                }
            }
        } else {
            scrollView.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        }

        addSubview(scrollView)

        // 设置约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        print("🎨 AEChatViewNew setupUI 完成")
    }

    // MARK: - Public Methods

    /// 添加用户消息
    public func addUserMessage(_ message: String) {
        print("💬 添加用户消息: \(message)")
        let chatMessage = ChatMessage(type: .user, content: message)
        messages.append(chatMessage)
        reloadAndScroll()
    }

    /// 添加 AI 响应消息
    public func addAssistantMessage(_ message: String, isMarkdown: Bool = true, assistantName: String = "AI") {
        print("🤖 addAssistantMessage 开始")
        print("   助手名: \(assistantName)")
        print("   内容长度: \(message.count)")
        print("   Markdown: \(isMarkdown)")
        print("   内容: \(message.prefix(100))...")

        let chatMessage = ChatMessage(
            type: .assistant,
            content: message,
            assistantName: assistantName,
            isMarkdown: isMarkdown
        )
        messages.append(chatMessage)

        print("   消息已添加到数组，当前共 \(messages.count) 条消息")
        reloadAndScroll()
        print("🤖 addAssistantMessage 完成")
    }

    /// 添加系统消息
    public func addSystemMessage(_ message: String) {
        print("⚙️ 添加系统消息: \(message)")
        let chatMessage = ChatMessage(type: .system, content: message)
        messages.append(chatMessage)
        reloadAndScroll()
    }

    /// 添加错误消息
    public func addErrorMessage(_ message: String) {
        print("❌ 添加错误消息: \(message)")
        let chatMessage = ChatMessage(type: .error, content: message)
        messages.append(chatMessage)
        reloadAndScroll()
    }

    /// 添加 AI 响应（通过解析器自动解析）
    public func addAIResponse(_ response: AnyObject) {
        print("🤖 AEChatViewNew.addAIResponse - 开始处理")

        // 使用解析器解析响应
        let parsedResponses = responseParser.parseResponse(response)

        print("📊 解析结果: 共 \(parsedResponses.count) 个响应")
        for (index, parsed) in parsedResponses.enumerated() {
            print("   [\(index + 1)] \(parsed.assistantName): \(parsed.text.prefix(50))...")
        }

        if parsedResponses.isEmpty {
            print("❌ 解析结果为空，显示错误")
            addErrorMessage("无法解析 AI 响应")
            return
        }

        // 不管单条还是多条，统一显示逻辑
        if parsedResponses.count == 1 {
            // 单个响应：直接显示
            let parsed = parsedResponses[0]
            print("✅ 单条响应，调用 addAssistantMessage")
            print("   内容: \(parsed.text)")
            print("   Markdown: \(parsed.isMarkdown)")
            print("   助手名: \(parsed.assistantName)")

            addAssistantMessage(
                parsed.text,
                isMarkdown: parsed.isMarkdown,
                assistantName: parsed.assistantName
            )
        } else {
            // 多个响应：使用对比视图
            print("✅ 多条响应(\(parsedResponses.count)个)，使用对比视图")
            let responses = parsedResponses.map { (name: $0.assistantName, text: $0.text) }
            let chatMessage = ChatMessage(
                type: .comparison,
                content: "",
                comparisonResponses: responses
            )
            messages.append(chatMessage)
            reloadAndScroll()
        }

        print("✅ AEChatViewNew.addAIResponse - 处理完成")
    }

    /// 清空所有消息
    public func clearMessages() {
        print("🗑️ 清空消息")
        messages.removeAll()
        tableView.reloadData()
    }

    /// 添加欢迎消息
    public func addWelcomeMessage() {
        addSystemMessage("欢迎使用 AI Terminal！开始你的对话吧。")
    }

    // MARK: - Private Methods

    private func reloadAndScroll() {
        print("📊 reloadAndScroll 开始，当前消息数: \(messages.count)")

        // 开始更新
        tableView.beginUpdates()
        tableView.reloadData()
        tableView.endUpdates()

        print("📊 tableView.reloadData() 完成")

        // 滚动到底部
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.messages.count > 0 else {
                print("⚠️ 无法滚动：messages.count = \(self?.messages.count ?? 0)")
                return
            }
            let lastRow = self.messages.count - 1
            print("📊 滚动到第 \(lastRow) 行")
            self.tableView.scrollRowToVisible(lastRow)
        }
    }
}

// MARK: - NSTableViewDataSource

extension AEChatViewNew: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        print("📊 numberOfRows 被调用，返回: \(messages.count)")
        return messages.count
    }
}

// MARK: - NSTableViewDelegate

extension AEChatViewNew: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        print("📊 tableView viewFor row: \(row)")
        guard row < messages.count else {
            print("❌ row \(row) 超出范围，messages.count = \(messages.count)")
            return nil
        }

        let message = messages[row]
        print("   消息类型: \(message.type)")

        // 尝试复用 cell
        var cell = tableView.makeView(
            withIdentifier: AEChatMessageCell.identifier,
            owner: self
        ) as? AEChatMessageCell

        // 如果没有可复用的 cell，创建新的
        if cell == nil {
            print("   创建新 cell")
            cell = AEChatMessageCell()
            cell?.identifier = AEChatMessageCell.identifier
        } else {
            print("   复用已有 cell")
        }

        // 配置 cell
        print("   配置 cell，内容长度: \(message.content.count)")
        cell?.configure(with: message, markdownRenderer: markdownRenderer)
        print("   cell 配置完成")

        return cell
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < messages.count else { return 60 }

        let message = messages[row]
        let tableWidth = tableView.bounds.width

        // 根据消息类型计算边距
        let (leadingMargin, trailingMargin): (CGFloat, CGFloat)
        switch message.type {
        case .user:
            leadingMargin = 80
            trailingMargin = 20
        case .assistant:
            leadingMargin = 20
            trailingMargin = 80
        case .system:
            leadingMargin = 40
            trailingMargin = 40
        case .error:
            leadingMargin = 20
            trailingMargin = 20
        case .comparison:
            return 320  // 对比视图固定高度
        }

        // 计算可用宽度
        let containerPadding: CGFloat = 8  // containerView 的内边距
        let availableWidth = tableWidth - leadingMargin - trailingMargin - containerPadding

        guard availableWidth > 0 else { return 60 }

        // 计算标题高度
        let titleHeight: CGFloat = 20

        // 计算内容高度
        var contentHeight: CGFloat = 0

        if message.type == .assistant && message.isMarkdown {
            // Markdown 内容：使用 NSTextView 计算
            let rendered = markdownRenderer.render(
                markdown: message.content,
                textColor: .labelColor,
                alignment: .left
            )

            // 创建临时 layoutManager 来计算高度
            let textStorage = NSTextStorage(attributedString: rendered)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            contentHeight = usedRect.height

            print("   📏 row \(row) markdown 高度计算: availableWidth=\(availableWidth), contentHeight=\(contentHeight)")
        } else {
            // 普通文本：使用 NSTextField 计算
            let textField = NSTextField(wrappingLabelWithString: message.content)
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.lineBreakMode = .byWordWrapping
            textField.preferredMaxLayoutWidth = availableWidth
            textField.maximumNumberOfLines = 0  // 允许无限行

            // 设置固定宽度来强制换行
            textField.setFrameSize(NSSize(width: availableWidth, height: 0))
            textField.sizeToFit()

            contentHeight = textField.frame.height

            print("   📏 row \(row) 普通文本高度计算: availableWidth=\(availableWidth), contentHeight=\(contentHeight), 文本长度=\(message.content.count)")
        }

        // 总高度 = 上边距(4) + 标题(20) + 间距(2) + 内容 + 下边距(4) + 额外间距(8)
        let totalHeight = 4 + titleHeight + 2 + contentHeight + 4 + 8

        return max(totalHeight, 60)
    }
}
