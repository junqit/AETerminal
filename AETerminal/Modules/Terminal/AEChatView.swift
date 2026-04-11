//
//  AEChatView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit

/// 聊天视图 - 显示对话内容
class AEChatView: NSView {

    // MARK: - Properties

    /// 滚动视图
    private var scrollView: NSScrollView!

    /// 文本视图用于显示聊天内容
    private var textView: NSTextView!

    /// 消息记录
    private var messages: [(type: MessageType, content: String)] = []

    /// Markdown 渲染器
    private let markdownRenderer = MarkdownRenderer(fontSize: 13)

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
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        print("🎨 AEChatView setupUI 开始, bounds: \(bounds)")

        // 创建滚动视图
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor

        // 创建文本系统组件
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // 使用足够大的初始尺寸
        let textContainer = NSTextContainer(containerSize: NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        // 创建文本视图
        textView = NSTextView(frame: .zero, textContainer: textContainer)
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

        // 设置尺寸约束
        textView.minSize = NSSize(width: 0, height: 0)
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

        print("🎨 AEChatView setupUI 完成")
        print("   scrollView frame: \(scrollView.frame)")
        print("   textView frame: \(textView.frame)")
        print("   textStorage: \(textView.textStorage != nil ? "✅" : "❌")")

        // 延迟验证布局
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔍 布局后检查:")
            print("   self.bounds: \(self.bounds)")
            print("   scrollView.frame: \(self.scrollView.frame)")
            print("   textView.frame: \(self.textView.frame)")

            // 如果布局后还是有问题，强制刷新
            if self.scrollView.frame.size.width == 0 || self.scrollView.frame.size.height == 0 {
                print("⚠️ scrollView frame 异常，尝试强制布局")
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
            }
        }
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

    /// 添加 AI 响应消息（支持 Markdown）
    func addAssistantMessage(_ message: String, isMarkdown: Bool = true) {
        print("🤖 AEChatView.addAssistantMessage: \(message.prefix(100))... (markdown: \(isMarkdown))")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .assistant, content: message))
            self?.appendMessage(message, type: .assistant, isMarkdown: isMarkdown)
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

        // 添加系统消息
        addSystemMessage("欢迎使用 AI Terminal！开始你的对话吧。")

        // 添加一个测试 Markdown 消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let testMarkdown = """
# 测试 Markdown 渲染

这是一个**粗体**文本测试。

## 代码示例

```swift
let greeting = "Hello, World!"
print(greeting)
```

## 列表测试

- 列表项 1
- 列表项 2
- 列表项 3

> 这是一个引用块
"""
            self?.addAssistantMessage(testMarkdown, isMarkdown: true)
        }
    }

    // MARK: - Private Methods

    /// 将消息追加到文本视图
    private func appendMessage(_ message: String, type: MessageType, isMarkdown: Bool = false) {
        guard let storage = textView.textStorage else {
            print("❌ textView.textStorage is nil!")
            return
        }

        print("📝 appendMessage 开始")
        print("   当前文本长度: \(storage.length)")
        print("   消息类型: \(type)")
        print("   是否 Markdown: \(isMarkdown)")
        print("   消息内容长度: \(message.count)")
        print("   消息预览: \(message.prefix(100))...")

        let timestamp = formatTimestamp(Date())
        let prefix: String
        let color: NSColor
        let alignment: NSTextAlignment

        switch type {
        case .user:
            prefix = "👤 User"
            color = .systemBlue
            alignment = .right  // 用户消息右对齐
        case .assistant:
            prefix = "🤖 Assistant"
            color = .systemGreen
            alignment = .left   // AI 消息左对齐
        case .system:
            prefix = "⚙️ System"
            color = .systemOrange
            alignment = .left
        case .error:
            prefix = "❌ Error"
            color = .systemRed
            alignment = .left
        }

        // 创建段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        // 如果不是第一条消息，添加分隔线
        if storage.length > 0 {
            let separator = NSAttributedString(string: "\n" + String(repeating: "─", count: 60) + "\n", attributes: [
                .foregroundColor: NSColor.separatorColor,
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .light)
            ])
            storage.append(separator)
            print("   ✅ 添加分隔线")
        }

        // 创建消息头部（带颜色、粗体和对齐方式）
        let header = "[\(timestamp)] \(prefix)\n"
        let headerAttr = NSAttributedString(string: header, attributes: [
            .foregroundColor: color,
            .font: NSFont.boldSystemFont(ofSize: 13),
            .paragraphStyle: paragraphStyle
        ])

        // 追加消息头部
        storage.append(headerAttr)
        print("   ✅ 添加消息头部，长度: \(headerAttr.length), 对齐方式: \(alignment == .right ? "右对齐" : "左对齐")")

        // 根据类型处理消息内容
        if isMarkdown && type == .assistant {
            // 使用 Markdown 渲染器（AI 消息总是左对齐）
            print("   🎨 开始 Markdown 渲染...")
            let renderedContent = markdownRenderer.render(message)
            print("   🎨 Markdown 渲染完成，长度: \(renderedContent.length)")
            print("   🎨 渲染后字符串预览: \(renderedContent.string.prefix(200))...")
            storage.append(renderedContent)
            print("   ✅ 添加 Markdown 内容")
        } else {
            // 普通文本
            let contentColor: NSColor
            if #available(macOS 10.14, *) {
                contentColor = NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return .white
                    } else {
                        return .black
                    }
                }
            } else {
                contentColor = .labelColor
            }

            let contentAttr = NSAttributedString(string: "\(message)\n", attributes: [
                .foregroundColor: contentColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .paragraphStyle: paragraphStyle  // 应用对齐方式
            ])
            storage.append(contentAttr)
            print("   ✅ 添加普通文本内容，长度: \(contentAttr.length)")
        }

        print("✅ appendMessage 完成 - 新文本总长度: \(storage.length)")
        print("   textView.string 长度: \(textView.string.count)")

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

// MARK: - MarkdownRenderer

/// Markdown 渲染器 - 将 Markdown 文本转换为 NSAttributedString
class MarkdownRenderer {

    // MARK: - 字体配置

    private let baseFont: NSFont
    private let baseFontSize: CGFloat
    private let codeFont: NSFont

    init(fontSize: CGFloat = 13) {
        self.baseFontSize = fontSize
        self.baseFont = NSFont.systemFont(ofSize: fontSize)
        self.codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
    }

    // MARK: - 公共方法

    /// 渲染 Markdown 文本为富文本
    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 按行处理
        let lines = markdown.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""

        for line in lines {
            // 处理代码块
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3).trimmingCharacters(in: .whitespaces))
                }
                continue
            }

            if inCodeBlock {
                // 收集代码块内容
                codeBlockContent += line + "\n"
            } else {
                // 处理普通行
                result.append(renderLine(line))
            }
        }

        // 如果还有未关闭的代码块
        if inCodeBlock {
            result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
        }

        return result
    }

    // MARK: - 私有方法

    /// 渲染单行文本
    private func renderLine(_ line: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 空行
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(NSAttributedString(string: "\n"))
            return result
        }

        // 标题
        if line.hasPrefix("#") {
            return renderHeading(line)
        }

        // 无序列表
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return renderListItem(line, ordered: false)
        }

        // 有序列表 (1. 2. 3. 等)
        if line.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
            return renderListItem(line, ordered: true)
        }

        // 引用
        if line.hasPrefix("> ") {
            return renderBlockquote(line)
        }

        // 普通段落
        return renderParagraph(line)
    }

    /// 渲染标题
    private func renderHeading(_ line: String) -> NSAttributedString {
        var level = 0
        var content = line

        // 计算标题级别
        for char in line {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        // 提取标题内容
        if level > 0 && level <= 6 {
            content = String(line.dropFirst(level).trimmingCharacters(in: .whitespaces))
        }

        // 根据级别设置字体大小
        let fontSize = baseFontSize + CGFloat(7 - level) * 2
        let font = NSFont.boldSystemFont(ofSize: fontSize)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: dynamicTextColor()
        ]

        let result = NSMutableAttributedString(string: content + "\n", attributes: attrs)
        return result
    }

    /// 渲染列表项
    private func renderListItem(_ line: String, ordered: Bool) -> NSAttributedString {
        let bullet = ordered ? "  " : "  • "
        let content: String

        if ordered {
            // 有序列表，保留数字
            if let match = line.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                content = String(line[match.upperBound...])
            } else {
                content = line
            }
        } else {
            // 无序列表，去掉标记
            content = String(line.dropFirst(2))
        }

        let result = NSMutableAttributedString(string: bullet)
        result.append(renderInlineFormats(content))
        result.append(NSAttributedString(string: "\n"))

        return result
    }

    /// 渲染引用
    private func renderBlockquote(_ line: String) -> NSAttributedString {
        let content = String(line.dropFirst(2))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.headIndent = 20
                style.firstLineHeadIndent = 20
                return style
            }()
        ]

        let result = NSMutableAttributedString(string: "▎ " + content + "\n", attributes: attrs)
        return result
    }

    /// 渲染段落
    private func renderParagraph(_ line: String) -> NSAttributedString {
        let result = renderInlineFormats(line)
        let mutable = NSMutableAttributedString(attributedString: result)
        mutable.append(NSAttributedString(string: "\n"))
        return mutable
    }

    /// 渲染行内格式
    private func renderInlineFormats(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 暂时使用简单的文本处理
        result.append(NSAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: dynamicTextColor()
        ]))

        return result
    }

    /// 渲染代码块
    private func renderCodeBlock(_ code: String, language: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 代码块背景和边框效果
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: codeTextColor(),
            .backgroundColor: codeBackgroundColor(),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.headIndent = 10
                style.firstLineHeadIndent = 10
                style.tailIndent = -10
                return style
            }()
        ]

        // 语言标签（如果有）
        if !language.isEmpty {
            let langAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: baseFontSize - 2),
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: codeBackgroundColor()
            ]
            result.append(NSAttributedString(string: "[\(language)]\n", attributes: langAttrs))
        }

        // 代码内容
        result.append(NSAttributedString(string: code, attributes: codeAttrs))
        result.append(NSAttributedString(string: "\n"))

        return result
    }

    // MARK: - 颜色工具

    /// 动态文本颜色
    private func dynamicTextColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return .white
                } else {
                    return .black
                }
            }
        } else {
            return .labelColor
        }
    }

    /// 代码文本颜色
    private func codeTextColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                } else {
                    return NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                }
            }
        } else {
            return .labelColor
        }
    }

    /// 代码背景颜色
    private func codeBackgroundColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
                } else {
                    return NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
                }
            }
        } else {
            return .controlBackgroundColor
        }
    }
}
