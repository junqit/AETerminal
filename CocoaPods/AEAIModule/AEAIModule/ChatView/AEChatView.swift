//
//  AEChatView.swift
//  AEAIModule
//
//  使用 NSTableView 的新聊天视图 - 支持 cell 复用，降低内存占用
//

import AppKit

/// 聊天视图 - 使用 TableView 实现
public class AEChatView: NSView {

    // MARK: - Properties

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    /// 消息数据源
    private var messages: [ChatMessage] = []

    /// Markdown 渲染器
    private let markdownRenderer = MarkdownRenderer(fontSize: 14)

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
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.sizeLastColumnToFit()

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
    }

    public override func layout() {
        super.layout()
        tableView.sizeLastColumnToFit()
        if messages.count > 0 {
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<messages.count))
        }
    }

    // MARK: - Public Methods

    /// 添加用户消息
    public func addUserMessage(_ message: String) {
        let chatMessage = ChatMessage(type: .user, content: message)
        messages.insert(chatMessage, at: 0)
        reloadAndScrollToTop()
    }

    /// 添加 AI 响应消息
    public func addAssistantMessage(_ message: String, isMarkdown: Bool = true, assistantName: String = "AI") {
        let chatMessage = ChatMessage(
            type: .assistant,
            content: message,
            assistantName: assistantName,
            isMarkdown: isMarkdown
        )
        messages.insert(chatMessage, at: 0)
        reloadAndScrollToTop()
    }

    /// 添加系统消息
    public func addSystemMessage(_ message: String) {
        let chatMessage = ChatMessage(type: .system, content: message)
        messages.insert(chatMessage, at: 0)
        reloadAndScrollToTop()
    }

    /// 添加错误消息
    public func addErrorMessage(_ message: String) {
        let chatMessage = ChatMessage(type: .error, content: message)
        messages.insert(chatMessage, at: 0)
        reloadAndScrollToTop()
    }

    /// 添加 AI 响应（通过解析器自动解析）
    public func addAIResponse(_ response: AnyObject) {
        let parsedResponses = responseParser.parseResponse(response)

        if parsedResponses.isEmpty {
            addErrorMessage("无法解析 AI 响应")
            return
        }

        if parsedResponses.count == 1 {
            let parsed = parsedResponses[0]
            addAssistantMessage(
                parsed.text,
                isMarkdown: parsed.isMarkdown,
                assistantName: parsed.assistantName
            )
        } else {
            let responses = parsedResponses.map { (name: $0.assistantName, text: $0.text) }
            let chatMessage = ChatMessage(
                type: .comparison,
                content: "",
                comparisonResponses: responses
            )
            messages.insert(chatMessage, at: 0)
            reloadAndScrollToTop()
        }
    }

    /// 清空所有消息
    public func clearMessages() {
        messages.removeAll()
        tableView.reloadData()
    }

    /// 添加欢迎消息
    public func addWelcomeMessage() {
        addSystemMessage("欢迎使用 AI Terminal！开始你的对话吧。")
    }

    // MARK: - Private Methods

    private func reloadAndScrollToTop() {
        let reload = { [weak self] in
            guard let self = self else { return }
            self.scrollView.layoutSubtreeIfNeeded()
            self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<self.messages.count))
            self.tableView.reloadData()
            if self.messages.count > 0 {
                self.tableView.scrollRowToVisible(0)
            }
        }

        if Thread.isMainThread {
            reload()
        } else {
            DispatchQueue.main.async(execute: reload)
        }
    }
}

// MARK: - NSTableViewDataSource

extension AEChatView: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return messages.count
    }
}

// MARK: - NSTableViewDelegate

extension AEChatView: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < messages.count else { return nil }

        let message = messages[row]

        var cell = tableView.makeView(
            withIdentifier: AEChatMessageCell.identifier,
            owner: self
        ) as? AEChatMessageCell

        if cell == nil {
            cell = AEChatMessageCell()
            cell?.identifier = AEChatMessageCell.identifier
        }

        cell?.configure(with: message, markdownRenderer: markdownRenderer)
        return cell
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < messages.count else { return 60 }

        let message = messages[row]
        var tableWidth = tableView.bounds.width
        if tableWidth < 200 {
            tableWidth = scrollView.bounds.width > 200 ? scrollView.bounds.width : 600
        }

        // 根据消息类型计算边距
        let (leadingMargin, trailingMargin): (CGFloat, CGFloat)
        switch message.type {
        case .user:
            leadingMargin = 20
            trailingMargin = 80
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
        let containerPadding: CGFloat = 24  // containerView 的左右内边距 12 + 12
        let availableWidth = tableWidth - leadingMargin - trailingMargin - containerPadding

        guard availableWidth > 100 else { return 60 }

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
        } else {
            // 普通文本：使用 NSTextField 计算
            let textField = NSTextField(wrappingLabelWithString: message.content)
            textField.font = NSFont.systemFont(ofSize: 14)
            textField.lineBreakMode = .byWordWrapping
            textField.preferredMaxLayoutWidth = availableWidth
            textField.maximumNumberOfLines = 0  // 允许无限行

            // 设置固定宽度来强制换行
            textField.setFrameSize(NSSize(width: availableWidth, height: 0))
            textField.sizeToFit()

            contentHeight = textField.frame.height
        }

        // 总高度 = 容器顶(4) + 标题顶(8) + 标题(20) + 间距(4) + 内容 + 内容底(8) + 容器底(4)
        let totalHeight = 4 + 8 + titleHeight + 4 + contentHeight + 8 + 4

        return max(totalHeight, 60)
    }
}
