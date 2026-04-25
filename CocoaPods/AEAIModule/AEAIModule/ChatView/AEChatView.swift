//
//  AEChatView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit

/// 聊天视图 - 显示对话内容
public class AEChatView: NSView {
    
    // MARK: - Properties
    
    /// 滚动视图
    private var scrollView: NSScrollView!
    
    /// 文本视图用于显示聊天内容
    private var textView: NSTextView!
    
    /// 消息记录
    private var messages: [(type: MessageType, content: String)] = []
    
    /// Markdown 渲染器
    private let markdownRenderer = MarkdownRenderer(fontSize: 13)
    
    /// 响应解析器
    private let responseParser = AEAIResponseParser()
    
    public enum MessageType {
        case user      // 用户输入
        case assistant // AI 响应
        case system    // 系统消息
        case error     // 错误消息
    }
    
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
        print("🎨 AEChatView setupUI 开始, bounds: \(bounds)")
        
        // 创建滚动视图
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true  // 自动隐藏滚动条，更现代
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        
        // 现代化背景颜色（深浅模式适配）
        if #available(macOS 10.14, *) {
            scrollView.backgroundColor = NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    // 深色模式：深灰蓝色背景
                    return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                } else {
                    // 浅色模式：浅灰色背景
                    return NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
                }
            }
        } else {
            scrollView.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        }
        
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
        
        // 文本视图使用相同的背景色
        if #available(macOS 10.14, *) {
            textView.backgroundColor = NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                } else {
                    return NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
                }
            }
        } else {
            textView.backgroundColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        }
        
        textView.textColor = .labelColor
        textView.font = NSFont.systemFont(ofSize: 14, weight: .regular)  // 更大更易读的字体
        textView.textContainerInset = NSSize(width: 20, height: 20)  // 更大的内边距
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
    public func addUserMessage(_ message: String) {
        print("💬 AEChatView.addUserMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .user, content: message))
            self?.appendMessage(message, type: .user)
        }
    }
    
    /// 添加 AI 响应消息（支持 Markdown）
    public func addAssistantMessage(_ message: String, isMarkdown: Bool = true, assistantName: String = "AI") {
        print("🤖 AEChatView.addAssistantMessage: \(message.prefix(100))... (markdown: \(isMarkdown))")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .assistant, content: message))
            self?.appendMessage(message, type: .assistant, isMarkdown: isMarkdown, assistantName: assistantName)
        }
    }
    
    /// 添加系统消息
    public func addSystemMessage(_ message: String) {
        print("⚙️ AEChatView.addSystemMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .system, content: message))
            self?.appendMessage(message, type: .system)
        }
    }
    
    /// 添加错误消息
    public func addErrorMessage(_ message: String) {
        print("❌ AEChatView.addErrorMessage: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.messages.append((type: .error, content: message))
            self?.appendMessage(message, type: .error)
        }
    }
    
    /// 添加 AI 响应（通过解析器自动解析）
    /// - Parameter response: AI 原始响应对象
    public func addAIResponse(_ response: AnyObject) {
        print("🤖 AEChatView.addAIResponse - 开始处理")
        
        // 使用解析器解析响应
        let parsedResponses = responseParser.parseResponse(response)
        
        // 如果没有解析到任何响应，显示错误
        if parsedResponses.isEmpty {
            addErrorMessage("无法解析 AI 响应")
            return
        }
        
        // 根据响应数量选择显示方式
        if parsedResponses.count == 1 {
            // 单个响应：使用传统垂直显示
            let parsedResponse = parsedResponses[0]
            if parsedResponse.text.isEmpty {
                addErrorMessage("AI 响应为空")
            } else {
                addAssistantMessage(
                    parsedResponse.text,
                    isMarkdown: parsedResponse.isMarkdown,
                    assistantName: parsedResponse.assistantName
                )
            }
        } else {
            // 多个响应：使用横向对比视图
            DispatchQueue.main.async { [weak self] in
                self?.addComparisonView(with: parsedResponses)
            }
        }
    }
    
    /// 清空所有消息
    public func clearMessages() {
        print("🗑️ AEChatView.clearMessages")
        DispatchQueue.main.async { [weak self] in
            self?.messages.removeAll()
            self?.textView.string = ""
        }
    }
    
    /// 测试方法 - 添加欢迎消息
    public func addWelcomeMessage() {
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
    
    /// 将消息追加到文本视图（简洁设计，无气泡）
    private func appendMessage(_ message: String, type: MessageType, isMarkdown: Bool = false, assistantName: String = "AI") {
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
        
        // 定义颜色方案
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }
        
        // 如果不是第一条消息，添加间距
        if storage.length > 0 {
            let spacing = NSAttributedString(string: "\n\n", attributes: [:])
            storage.append(spacing)
        }
        
        // 根据消息类型配置样式
        let timestamp = formatTimestamp(Date())
        let displayName: String
        let nameColor: NSColor
        let contentColor: NSColor
        let alignment: NSTextAlignment
        let fontSize: CGFloat = 15  // 更大的字体
        
        switch type {
        case .user:
            displayName = "You"
            nameColor = isDarkMode
            ? NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)   // 深色模式亮蓝
            : NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)  // 浅色模式蓝色
            contentColor = isDarkMode ? .white : .black
            alignment = .right
        case .assistant:
            displayName = assistantName  // 使用传入的名字
            nameColor = isDarkMode
            ? NSColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0)   // 深色模式亮绿
            : NSColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0)  // 浅色模式绿色
            contentColor = isDarkMode ? .white : .black
            alignment = .left
        case .system:
            displayName = "System"
            nameColor = isDarkMode
            ? NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)   // 深色模式橙色
            : NSColor(red: 0.9, green: 0.6, blue: 0.0, alpha: 1.0)  // 浅色模式橙色
            contentColor = isDarkMode ? .white : .black
            alignment = .center
        case .error:
            displayName = "Error"
            nameColor = isDarkMode
            ? NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)   // 深色模式亮红
            : NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)  // 浅色模式红色
            contentColor = nameColor
            alignment = .left
        }
        
        // 创建段落样式
        let headerParagraphStyle = NSMutableParagraphStyle()
        headerParagraphStyle.alignment = alignment
        
        let contentParagraphStyle = NSMutableParagraphStyle()
        contentParagraphStyle.alignment = alignment
        contentParagraphStyle.lineSpacing = 4  // 行间距
        contentParagraphStyle.paragraphSpacing = 6  // 段落间距
        
        // 添加消息头部（名字和时间戳）
        let headerText = "\(displayName)  \(timestamp)\n"
        let headerAttr = NSAttributedString(string: headerText, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: nameColor,
            .paragraphStyle: headerParagraphStyle
        ])
        storage.append(headerAttr)
        print("   ✅ 添加消息头部，对齐: \(alignment)")
        
        // 添加消息内容
        if isMarkdown && type == .assistant {
            // Markdown 渲染
            print("   🎨 开始 Markdown 渲染...")
            let renderedContent = markdownRenderer.render(markdown: message, textColor: contentColor, alignment: alignment)
            storage.append(renderedContent)
            print("   ✅ 添加 Markdown 内容")
        } else {
            // 普通文本
            let contentAttr = NSAttributedString(string: "\(message)\n", attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: contentColor,
                .paragraphStyle: contentParagraphStyle
            ])
            storage.append(contentAttr)
            print("   ✅ 添加普通文本内容")
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
    
    // MARK: - 多响应对比视图
    
    /// 添加多个AI响应的横向对比视图
    /// - Parameter responses: 解析后的多个响应
    private func addComparisonView(with responses: [AEAIResponseParser.ParsedResponse]) {
        guard let storage = textView.textStorage else {
            print("❌ textView.textStorage is nil!")
            return
        }

        print("📊 添加对比视图，共 \(responses.count) 个响应")

        // 如果不是第一条消息，添加间距
        if storage.length > 0 {
            let spacing = NSAttributedString(string: "\n\n", attributes: [:])
            storage.append(spacing)
        }

        // 添加对比标题
        let timestamp = formatTimestamp(Date())
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }

        let headerText = "AI 对比  \(timestamp)\n"
        let headerAttr = NSAttributedString(string: headerText, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: isDarkMode ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
        ])
        storage.append(headerAttr)

        // 记录插入位置
        let insertPosition = storage.length

        // 准备响应数据
        let comparisonData = responses.map { (name: $0.assistantName, text: $0.text) }

        // 使用新的 AEComparisonView
        let comparisonView = AEComparisonView(responses: comparisonData)

        // 将对比视图添加到 textView
        textView.addSubview(comparisonView)

        // 固定高度
        let fixedHeight: CGFloat = 300

        // 添加占位符
        let placeholderLines = Int(ceil((fixedHeight + 20) / 20))
        let placeholder = NSAttributedString(
            string: String(repeating: "\n", count: placeholderLines),
            attributes: [.font: NSFont.systemFont(ofSize: 1)]
        )
        storage.append(placeholder)

        // 布局对比视图
        layoutComparisonView(comparisonView, insertPosition: insertPosition, height: fixedHeight)

        // 滚动到底部
        scrollToBottom()
    }

    /// 布局对比视图到指定位置
    /// - Parameters:
    ///   - view: 对比视图
    ///   - insertPosition: 插入位置
    ///   - height: 视图高度
    private func layoutComparisonView(_ view: NSView, insertPosition: Int, height: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 计算可用宽度（占满整个 textView 宽度，减去内边距）
            let availableWidth = self.textView.bounds.width - self.textView.textContainerInset.width * 2

            // 获取插入位置的坐标
            let glyphIndex = self.textView.layoutManager?.glyphIndexForCharacter(at: insertPosition) ?? 0
            let rect = self.textView.layoutManager?.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: self.textView.textContainer!
            ) ?? .zero

            print("📐 布局对比视图:")
            print("   可用宽度: \(availableWidth)")
            print("   高度: \(height)")
            print("   Y 位置: \(rect.minY + 5)")

            // 设置视图的 frame
            view.frame = CGRect(
                x: self.textView.textContainerInset.width,
                y: rect.minY + 5,
                width: availableWidth,
                height: height
            )

            print("   最终 frame: \(view.frame)")
        }
    }

    // MARK: - MarkdownRenderer

    /// Markdown 渲染器 - 将 Markdown 文本转换为 NSAttributedString
    class MarkdownRenderer {
        
        // MARK: - 字体配置
        
        private let baseFont: NSFont
        private let baseFontSize: CGFloat
        private let codeFont: NSFont
        private var currentTextColor: NSColor = .labelColor
        private var currentAlignment: NSTextAlignment = .left
        
        init(fontSize: CGFloat = 15) {  // 增大默认字体
            self.baseFontSize = fontSize
            self.baseFont = NSFont.systemFont(ofSize: fontSize)
            self.codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
        }
        
        // MARK: - 公共方法
        
        /// 渲染 Markdown 文本为富文本
        func render(markdown: String, textColor: NSColor, alignment: NSTextAlignment) -> NSAttributedString {
            // 设置当前颜色和对齐
            self.currentTextColor = textColor
            self.currentAlignment = alignment
            
            let result = NSMutableAttributedString()
            
            // 创建段落样式
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacing = 6
            
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
            
            // 根据级别设置字体大小（增大）
            let fontSize = baseFontSize + CGFloat(7 - level) * 3
            let font = NSFont.boldSystemFont(ofSize: fontSize)
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: currentTextColor
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
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),  // 更大字体
                .foregroundColor: currentTextColor,
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
                    .font: NSFont.systemFont(ofSize: 12),
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
}
