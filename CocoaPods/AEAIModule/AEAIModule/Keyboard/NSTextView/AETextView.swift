//
//  AETextView.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Cocoa
import AEFoundation

/// 不响应鼠标事件的 Label（用于占位符）
private class NonInteractiveLabel: NSTextField {

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 返回 nil，让鼠标事件穿透到下层视图
        return nil
    }

    override var acceptsFirstResponder: Bool {
        return false
    }
}

/// 自定义 TextView，支持组合键处理和自定义样式
@IBDesignable
public class AETextView: NSView, NSTextViewDelegate {

    // MARK: - Properties

    /// 代理
    public weak var delegate: AETextViewDelegate?

    /// 标记是否已完成设置
    private var isConfigured: Bool = false

    /// 内部的 NSTextView
    private var textView: NSTextView!

    /// 是否是焦点视图
    private var isFocused: Bool = false

    /// ScrollView
    private var scrollView: NSScrollView!

    // MARK: - IBInspectable Properties

    /// 占位符文本（可在 Storyboard 中设置）
    @IBInspectable public var placeholderText: String = "请输入您的问题" {
        didSet {
            placeholderLabel?.stringValue = placeholderText
        }
    }

    /// 字体大小（可在 Storyboard 中设置）
    @IBInspectable public var fontSize: CGFloat = 15 {
        didSet {
            updateFont()
        }
    }

    /// 文本颜色（可在 Storyboard 中设置）
    @IBInspectable public var textColor: NSColor = .systemOrange {
        didSet {
            updateTextColor()
        }
    }

    /// 占位符 Label（不响应鼠标事件）
    private var placeholderLabel: NonInteractiveLabel!

    // MARK: - Initialization

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        // 从 Storyboard 加载时，在 awakeFromNib 中初始化
    }

    /// 从 Storyboard 加载完成后调用
    public override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }

    /// 通用初始化方法
    private func commonInit() {
        guard !isConfigured else { return }
        isConfigured = true

        setupUI()
        setupStyle()
        registerCombinationKeyHandler()
    }

    deinit {
        AECombinationKeyManager.shared.unregister(self)
    }

    /// 注册组合键处理器
    private func registerCombinationKeyHandler() {
        AECombinationKeyManager.shared.register(self)
    }

    /// 支持 Interface Builder 预览
    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    // MARK: - Setup

    private func setupUI() {
        // 创建 NSTextView（使用默认构造器）
        textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // 配置 textContainer
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }

        // 创建 ScrollView
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = textView

        addSubview(scrollView)

        // 创建占位符 Label（不响应鼠标事件，不会遮挡 textView）
        placeholderLabel = NonInteractiveLabel(labelWithString: placeholderText)
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.drawsBackground = false
        placeholderLabel.isBordered = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = NSFont.boldSystemFont(ofSize: fontSize)
        placeholderLabel.textColor = textColor.withAlphaComponent(0.5)
        addSubview(placeholderLabel)

        // 设置约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        ])
    }

    private func setupStyle() {
        // 设置背景透明
        textView.backgroundColor = .clear

        // 设置字体和颜色
        let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
        textView.font = boldFont
        textView.textColor = textColor

        // 设置输入时的字体和颜色
        textView.typingAttributes = [
            .font: boldFont,
            .foregroundColor: textColor
        ]

        // 设置光标颜色
        textView.insertionPointColor = textColor

        // 设置 delegate
        textView.delegate = self

        // 初始显示占位符
        updatePlaceholderVisibility()

        // 延迟计算初始高度（确保布局完成）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let initialHeight = self.calculateTextHeight()
            self.delegate?.aeTextView(self, didChangeHeight: initialHeight)
        }
    }

    // MARK: - Style Updates

    /// 更新字体
    private func updateFont() {
        guard textView != nil else { return }
        let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
        textView.font = boldFont
        textView.typingAttributes = [
            .font: boldFont,
            .foregroundColor: textColor
        ]
        placeholderLabel?.font = boldFont
    }

    /// 更新文本颜色
    private func updateTextColor() {
        guard textView != nil else { return }
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.typingAttributes = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: textColor
        ]
        placeholderLabel?.textColor = textColor.withAlphaComponent(0.5)
    }

    // MARK: - Public Methods

    /// 获取文本内容
    public var text: String {
        get {
            return textView.string
        }
        set {
            textView.string = newValue
            updatePlaceholderVisibility()
            applyStyleToAllText()

            // 计算并通知高度变化
            let newHeight = calculateTextHeight()
            delegate?.aeTextView(self, didChangeHeight: newHeight)
        }
    }

    /// 清空文本
    public func clear() {
        textView.string = ""
        updatePlaceholderVisibility()

        // 计算并通知高度变化
        let newHeight = calculateTextHeight()
        delegate?.aeTextView(self, didChangeHeight: newHeight)
    }

    /// 获取内部的 NSTextView（如需直接访问）
    public var innerTextView: NSTextView {
        return textView
    }

    // MARK: - Placeholder

    /// 更新占位符显示/隐藏
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    // MARK: - NSTextViewDelegate

    /// 文本即将改变时调用（在输入或删除字符之前）
    public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // 计算改变后的文本长度
        let currentLength = textView.string.count
        let replacementLength = replacementString?.count ?? 0
        let rangeLength = affectedCharRange.length
        let newLength = currentLength - rangeLength + replacementLength

        // 如果改变后文本为空，显示占位符
        if newLength == 0 {
            placeholderLabel.isHidden = false
        }
        // 如果改变后文本不为空，隐藏占位符
        else if newLength > 0 {
            placeholderLabel.isHidden = true
        }

        return true // 允许文本改变
    }

    /// 文本改变时调用
    public func textDidChange(_ notification: Notification) {
        // 更新占位符显示状态
        updatePlaceholderVisibility()

        // 应用样式到所有文本
        applyStyleToAllText()

        // 计算并通知高度变化
        let newHeight = calculateTextHeight()
        delegate?.aeTextView(self, didChangeHeight: newHeight)
    }

    /// 处理特殊命令（如回车键、上下键）
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // 处理回车键
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let inputText = text

            // 如果内容为空，不处理
            guard !inputText.isEmpty else {
                return true
            }

            // 通知代理输入内容
            delegate?.aeTextView(self, didInputText: inputText)

            // 清空输入框
            clear()

            return true // 表示已处理，不执行默认行为
        }

        // 处理上键：加载上一条历史记录
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if let previousText = delegate?.aeTextViewRequestPreviousHistory(self) {
                text = previousText
                // 光标移到末尾
                moveCursorToEnd()
            }
            return true
        }

        // 处理下键：加载下一条历史记录
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if let nextText = delegate?.aeTextViewRequestNextHistory(self) {
                text = nextText
                // 光标移到末尾
                moveCursorToEnd()
            } else {
                // 如果没有下一条，清空输入框
                clear()
            }
            return true
        }

        return false // 其他命令使用默认处理
    }

    /// 将光标移到文本末尾
    private func moveCursorToEnd() {
        let textLength = textView.string.count
        textView.setSelectedRange(NSRange(location: textLength, length: 0))
    }

    /// 应用样式到所有文本
    private func applyStyleToAllText() {
        guard let textStorage = textView.textStorage else { return }
        guard textStorage.length > 0 else { return }

        let range = NSRange(location: 0, length: textStorage.length)
        let boldFont = NSFont.boldSystemFont(ofSize: fontSize)

        textStorage.addAttributes([
            .font: boldFont,
            .foregroundColor: textColor
        ], range: range)
    }

    /// 计算文本所需高度
    private func calculateTextHeight() -> CGFloat {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return 20
        }

        // 强制布局
        layoutManager.ensureLayout(for: textContainer)

        // 计算所需高度
        let usedRect = layoutManager.usedRect(for: textContainer)
        return ceil(usedRect.height)
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func becomeFirstResponder() -> Bool {
        isFocused = true
        // 让内部的 NSTextView 成为第一响应者
        window?.makeFirstResponder(textView)
        let result = textView.becomeFirstResponder()
        return result
    }

    public override func resignFirstResponder() -> Bool {
        isFocused = false
        return textView.resignFirstResponder()
    }

    /// 设置为第一响应者（便捷方法）
    public func focus() {
        window?.makeFirstResponder(textView)
    }
}

// MARK: - AECombinationKeyHandler

extension AETextView: AECombinationKeyHandler {

    public var combinationKeyHandlerID: String {
        return "AETextView"
    }

    public func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        // 处理 Command+I：激活输入框
        if modifiers.contains(.command) && key.lowercased() == "i" {
            print("⌨️ Command+I 激活 AETextView")
            focus()
            return true
        }

        return false
    }
}
