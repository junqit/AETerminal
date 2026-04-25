//
//  AEChatMessageCell.swift
//  AEAIModule
//
//  聊天消息 Cell - 支持 cell 复用
//

import AppKit

/// 消息模型
public struct ChatMessage {
    public enum MessageType {
        case user
        case assistant
        case system
        case error
        case comparison  // 对比视图
    }

    public let id: UUID
    public let type: MessageType
    public let content: String
    public let assistantName: String?
    public let isMarkdown: Bool
    public let timestamp: Date
    public let comparisonResponses: [(name: String, text: String)]?  // 用于对比视图

    public init(
        type: MessageType,
        content: String,
        assistantName: String? = nil,
        isMarkdown: Bool = false,
        comparisonResponses: [(name: String, text: String)]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.assistantName = assistantName
        self.isMarkdown = isMarkdown
        self.timestamp = Date()
        self.comparisonResponses = comparisonResponses
    }
}

/// 通用消息 Cell
public class AEChatMessageCell: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("AEChatMessageCell")

    private var containerView: NSView!
    private var titleLabel: NSTextField!
    private var contentLabel: NSTextField!  // 用于简单文本
    private var contentTextView: NSTextView!  // 用于 markdown 富文本
    private var comparisonView: AEComparisonView?

    // 动态约束
    private var containerLeadingConstraint: NSLayoutConstraint?
    private var containerTrailingConstraint: NSLayoutConstraint?

    // 内容控件的约束（需要动态切换）
    private var labelConstraints: [NSLayoutConstraint] = []
    private var textViewConstraints: [NSLayoutConstraint] = []

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // 容器视图
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // 标题标签
        titleLabel = NSTextField()
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // 内容标签 - 用于简单文本
        contentLabel = NSTextField()
        contentLabel.isEditable = false
        contentLabel.isSelectable = true
        contentLabel.isBezeled = false
        contentLabel.drawsBackground = false
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.maximumNumberOfLines = 0  // 允许多行
        contentLabel.font = NSFont.systemFont(ofSize: 13)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerView.addSubview(contentLabel)

        // 内容 TextView - 用于 markdown 富文本
        contentTextView = NSTextView()
        contentTextView.isEditable = false
        contentTextView.isSelectable = true
        contentTextView.drawsBackground = false
        contentTextView.backgroundColor = .clear
        contentTextView.textContainerInset = NSSize(width: 0, height: 0)
        contentTextView.textContainer?.lineFragmentPadding = 0
        contentTextView.textContainer?.widthTracksTextView = true
        contentTextView.textContainer?.heightTracksTextView = false  // 关键：不要跟踪高度
        contentTextView.isVerticallyResizable = true
        contentTextView.isHorizontallyResizable = false
        contentTextView.autoresizingMask = []
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        // 关键：设置 TextView 的最小和最大尺寸
        contentTextView.minSize = NSSize(width: 0, height: 0)
        contentTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // 设置文本容器大小
        contentTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        containerView.addSubview(contentTextView)

        // 设置动态约束
        containerLeadingConstraint = containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        containerTrailingConstraint = containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)

        // 保存 contentLabel 的约束（不立即激活）
        labelConstraints = [
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            contentLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ]

        // 保存 contentTextView 的约束（不立即激活）
        textViewConstraints = [
            contentTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            contentTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ]

        // 激活基础约束
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            containerLeadingConstraint!,
            containerTrailingConstraint!,

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4)
        ])

        // 默认激活 label 约束
        NSLayoutConstraint.activate(labelConstraints)
    }

    public func configure(with message: ChatMessage, markdownRenderer: MarkdownRenderer) {
        // 移除旧的对比视图
        comparisonView?.removeFromSuperview()
        comparisonView = nil

        // 格式化时间戳
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: message.timestamp)

        // 根据消息类型设置样式
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }

        switch message.type {
        case .user:
            // 用户消息：右对齐
            titleLabel.stringValue = "You  \(timestamp)"
            titleLabel.textColor = isDarkMode ? NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0) : NSColor.systemBlue
            titleLabel.alignment = .right

            // 使用 Label 显示简单文本
            switchToLabel()
            contentLabel.stringValue = message.content
            contentLabel.textColor = .labelColor
            contentLabel.alignment = .right

            // 无背景
            containerView.layer?.backgroundColor = NSColor.clear.cgColor

            // 右对齐：增加左边距
            containerLeadingConstraint?.constant = 80
            containerTrailingConstraint?.constant = -20

        case .assistant:
            // AI消息：左对齐
            let name = message.assistantName ?? "AI"
            titleLabel.stringValue = "\(name)  \(timestamp)"
            titleLabel.textColor = isDarkMode ? NSColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0) : NSColor.systemGreen
            titleLabel.alignment = .left

            // 无背景
            containerView.layer?.backgroundColor = NSColor.clear.cgColor

            // 左对齐：增加右边距
            containerLeadingConstraint?.constant = 20
            containerTrailingConstraint?.constant = -80

            if message.isMarkdown {
                // Markdown：使用 TextView 显示富文本
                print("   📝 显示 Markdown 内容")
                print("   内容长度: \(message.content.count)")
                print("   内容前100字符: \(message.content.prefix(100))")

                switchToTextView()

                let rendered = markdownRenderer.render(
                    markdown: message.content,
                    textColor: .labelColor,
                    alignment: .left
                )

                print("   渲染后长度: \(rendered.length)")
                print("   textView 是否隐藏: \(contentTextView.isHidden)")

                contentTextView.textStorage?.setAttributedString(rendered)

                // 确保 textView 可见
                contentTextView.alphaValue = 1.0

                // 关键：强制 TextView 重新布局并计算大小
                contentTextView.sizeToFit()

                print("   textStorage 内容长度: \(contentTextView.textStorage?.length ?? 0)")
                print("   textView frame: \(contentTextView.frame)")
                print("   textView bounds: \(contentTextView.bounds)")
            } else {
                // 普通文本：使用 Label
                switchToLabel()
                contentLabel.stringValue = message.content
                contentLabel.textColor = .labelColor
                contentLabel.alignment = .left
            }

        case .system:
            titleLabel.stringValue = "System  \(timestamp)"
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.alignment = .center

            switchToLabel()
            contentLabel.stringValue = message.content
            contentLabel.textColor = .secondaryLabelColor
            contentLabel.alignment = .center

            containerView.layer?.backgroundColor = NSColor.clear.cgColor

            containerLeadingConstraint?.constant = 40
            containerTrailingConstraint?.constant = -40

        case .error:
            titleLabel.stringValue = "Error  \(timestamp)"
            titleLabel.textColor = .systemRed
            titleLabel.alignment = .left

            switchToLabel()
            contentLabel.stringValue = message.content
            contentLabel.textColor = .systemRed
            contentLabel.alignment = .left

            containerView.layer?.backgroundColor = NSColor.clear.cgColor

            containerLeadingConstraint?.constant = 20
            containerTrailingConstraint?.constant = -20

        case .comparison:
            titleLabel.stringValue = "AI 对比  \(timestamp)"
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.alignment = .center

            // 隐藏两个文本控件
            switchToLabel()
            contentLabel.isHidden = true
            contentTextView.isHidden = true

            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerLeadingConstraint?.constant = 20
            containerTrailingConstraint?.constant = -20

            // 添加对比视图
            if let responses = message.comparisonResponses, !responses.isEmpty {
                let comparison = AEComparisonView(responses: responses)
                comparison.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(comparison)

                NSLayoutConstraint.activate([
                    comparison.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                    comparison.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                    comparison.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                    comparison.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
                    comparison.heightAnchor.constraint(equalToConstant: 300)
                ])

                comparisonView = comparison
            }
        }
    }

    // 切换到 Label 显示
    private func switchToLabel() {
        // 停用 textView 约束，激活 label 约束
        NSLayoutConstraint.deactivate(textViewConstraints)
        NSLayoutConstraint.activate(labelConstraints)

        contentLabel.isHidden = false
        contentTextView.isHidden = true
    }

    // 切换到 TextView 显示
    private func switchToTextView() {
        // 停用 label 约束，激活 textView 约束
        NSLayoutConstraint.deactivate(labelConstraints)
        NSLayoutConstraint.activate(textViewConstraints)

        contentLabel.isHidden = true
        contentTextView.isHidden = false
    }

    // 重写此方法，在 TableView 询问尺寸时提供正确的宽度
    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        // 当 cell 被添加到 TableView 时，更新文本宽度
        if superview != nil {
            updateTextWidths()
        }
    }

    // 在布局改变时更新
    public override func layout() {
        super.layout()
        updateTextWidths()
    }

    // 更新文本宽度的核心方法
    private func updateTextWidths() {
        // 获取 TableView 的宽度
        guard let tableView = self.superview as? NSTableView else {
            print("   ⚠️ updateTextWidths: superview 不是 NSTableView")
            return
        }
        let tableWidth = tableView.bounds.width

        // 根据当前的约束常量计算可用宽度
        let leadingConstant = containerLeadingConstraint?.constant ?? 20
        let trailingConstant = abs(containerTrailingConstraint?.constant ?? -20)
        let padding: CGFloat = 8  // 内边距

        let maxWidth = tableWidth - leadingConstant - trailingConstant - padding

        print("   📏 updateTextWidths:")
        print("      tableWidth: \(tableWidth)")
        print("      leadingConstant: \(leadingConstant)")
        print("      trailingConstant: \(trailingConstant)")
        print("      maxWidth: \(maxWidth)")

        // 只有当宽度有效时才设置
        guard maxWidth > 0 else {
            print("   ⚠️ maxWidth <= 0，跳过设置")
            return
        }

        // 为可见的文本控件设置宽度
        if !contentLabel.isHidden {
            contentLabel.preferredMaxLayoutWidth = maxWidth
            print("   ✅ 设置 contentLabel.preferredMaxLayoutWidth = \(maxWidth)")

            // 强制 label 重新计算大小
            contentLabel.invalidateIntrinsicContentSize()
        }

        if !contentTextView.isHidden {
            contentTextView.textContainer?.containerSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
            contentTextView.layoutManager?.ensureLayout(for: contentTextView.textContainer!)
            print("   ✅ 设置 contentTextView containerSize width = \(maxWidth)")

            // 获取实际布局后的高度
            let layoutManager = contentTextView.layoutManager!
            let textContainer = contentTextView.textContainer!
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            print("   📐 textView usedRect: \(usedRect)")
        }
    }
}
