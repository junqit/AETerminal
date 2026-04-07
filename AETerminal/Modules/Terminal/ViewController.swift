//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AENetworkEngine
import AEAIEngin

class ViewController: NSViewController {

    @IBOutlet weak var inputTextView: AETextView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!

    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200

    @IBOutlet weak var leftView: AELeftView!

    // 命令历史记录管理器
    private let historyManager = CommandHistoryManager.shared

    // 暂存当前输入（用于在浏览历史时保存）
    private var currentInput: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor

        AENetHttpEngine.configure(config: AENetHttpConfig(baseURL: "http://127.0.0.1:9000"))

        // 设置 AETextView 的 delegate
        inputTextView.delegate = self

        // 设置文本高度变化回调
        inputTextView.onTextHeightChanged = { [weak self] in
            self?.updateTextViewHeight()
        }

        // 设置初始高度
        updateTextViewHeight()

        // 设置左侧视图
        setupLeftView()

        // 监听键盘事件（用于处理回车键和上下键）
        setupKeyboardMonitor()

        // Do any additional setup after loading the view.
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // 预先准备获取焦点
        DispatchQueue.main.async { [weak self] in
            self?.inputTextView.focus()
        }
    }

    // MARK: - Keyboard Monitor

    /// 设置键盘监听器
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let key = event.characters ?? ""
            let modifiers = event.modifierFlags
            let cleanModifiers = modifiers.intersection([.command, .option, .shift, .control, .function])

            // 检查是否为上下键（用于历史记录导航）
            if event.keyCode == 0x7E { // 上箭头
                self.navigateHistoryUp()
                return nil
            }

            if event.keyCode == 0x7D { // 下箭头
                self.navigateHistoryDown()
                return nil
            }

            // 处理组合键
            if cleanModifiers.contains(.command) {
                self.handleCommandKey(key: key, event: event)
                return nil
            }

            if cleanModifiers.contains(.control) {
                self.handleControlKey(key: key, event: event)
                return nil
            }

            if cleanModifiers.contains(.option) {
                self.handleOptionKey(key: key, event: event)
                return nil
            }

            if cleanModifiers == .shift {
                self.handleShiftKey(key: key, event: event)
                return nil
            }

            if cleanModifiers.contains(.function) {
                self.handleFnKey(key: key, event: event)
                return nil
            }

            return event
        }
    }

    // MARK: - Key Handlers

    private func handleCommandKey(key: String, event: NSEvent) {
        let processedKey = AECommandKey.process(key: key, event: event)
        print("⌘ Command + \(processedKey)")

        switch processedKey.uppercased() {
        case "S":
            print("保存文档")
            // TODO: 实现保存功能
        default:
            if let description = AECommandKey.getShortcutDescription(processedKey) {
                print("系统快捷键: \(description)")
            }
        }
    }

    private func handleOptionKey(key: String, event: NSEvent) {
        let processedKey = AEOptionKey.process(key: key, event: event)
        print("⌥ Option + \(processedKey)")

        if AEOptionKey.isTextEditingShortcut(processedKey) {
            if let description = AEOptionKey.getShortcutDescription(processedKey) {
                print("文本编辑: \(description)")
            }
        }
    }

    private func handleShiftKey(key: String, event: NSEvent) {
        let processedKey = AEShiftKey.process(key: key, event: event)
        print("⇧ Shift + \(processedKey)")

        if AEShiftKey.isTextSelectionShortcut(processedKey) {
            if let description = AEShiftKey.getShortcutDescription(processedKey) {
                print("文本选择: \(description)")
            }
        }
    }

    private func handleControlKey(key: String, event: NSEvent) {
        let processedKey = AEControlKey.process(key: key, event: event)
        print("⌃ Control + \(processedKey)")

        // 处理上下键：浏览历史记录
        switch processedKey.uppercased() {
        case "P", "UP":
            navigateHistoryUp()
            return
        case "N", "DOWN":
            navigateHistoryDown()
            return
        default:
            break
        }

        // 处理 Emacs 风格快捷键
        if AEControlKey.isEmacsShortcut(processedKey) {
            if let description = AEControlKey.getEmacsDescription(processedKey) {
                print("Emacs 快捷键: \(description)")
            }
        }
    }

    private func handleFnKey(key: String, event: NSEvent) {
        let processedKey = AEFnKey.process(key: key, event: event)
        print("Fn + \(processedKey)")

        if AEFnKey.isFunctionKey(processedKey) {
            if let usage = AEFnKey.getFunctionKeyUsage(processedKey) {
                print("功能键: \(usage)")
            }
        }
    }

    // MARK: - Left View Setup

    /// 设置左侧目录视图
    private func setupLeftView() {
        guard let leftView = leftView else { return }

        leftView.delegate = self

        // 加载用户主目录
        let homePath = AEDirectory.homeDirectory()
        leftView.loadDirectories(atPath: homePath)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // 让 AETextView 成为第一响应者，可以直接接收键盘输入
        inputTextView.focus()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // 根据内容更新 TextView 高度
    private func updateTextViewHeight() {
        let textView = inputTextView.innerTextView
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // 强制布局
        layoutManager.ensureLayout(for: textContainer)

        // 计算所需高度
        let usedRect = layoutManager.usedRect(for: textContainer)
        var newHeight = ceil(usedRect.height)

        // 限制在最小和最大高度之间
        newHeight = max(minHeight, min(newHeight, maxHeight))

        // 更新约束
        scrollViewHeightConstraint.constant = newHeight
    }

    // MARK: - History Navigation

    /// 向上浏览历史记录（更旧的命令）
    private func navigateHistoryUp() {
        // 如果是第一次按上下键，保存当前输入
        if historyManager.currentIndex == -1 {
            currentInput = inputTextView.text
        }

        if let command = historyManager.navigateUp() {
            inputTextView.text = command
            updateTextViewHeight()
            moveCursorToEnd()

            // 确保焦点在输入框
            inputTextView.focus()
        }
    }

    /// 向下浏览历史记录（更新的命令）
    private func navigateHistoryDown() {
        if let command = historyManager.navigateDown() {
            inputTextView.text = command
        } else {
            // 回到当前输入
            inputTextView.text = currentInput
        }

        updateTextViewHeight()
        moveCursorToEnd()

        // 确保焦点在输入框
        inputTextView.focus()
    }

    /// 将光标移到文本末尾
    private func moveCursorToEnd() {
        let textView = inputTextView.innerTextView
        let textLength = textView.string.count
        textView.setSelectedRange(NSRange(location: textLength, length: 0))
    }
}

// MARK: - AELeftViewDelegate

extension ViewController: AELeftViewDelegate {

    /// 处理目录确认选择
    func leftView(_ leftView: AELeftView, didConfirmDirectory path: String) {
        print("确认选择目录: \(path)")

        // 检查是否为目录
        guard AEDirectory.isDirectory(atPath: path) else {
            print("不是有效的目录: \(path)")
            return
        }

        // TODO: 在这里处理用户选择的目录
        // 例如：切换工作目录、显示目录内容等
    }
}

// MARK: - AETextViewDelegate

extension ViewController: AETextViewDelegate {

    /// 用户输入文本时调用（回车提交）
    func aeTextView(_ textView: AETextView, didInputText text: String) {
        // 这是回车提交的完整内容
        print("✅ 提交内容: \(text)")
        handleSubmittedText(text)
    }

    // MARK: - Helper Methods

    /// 处理提交的文本（回车提交）
    private func handleSubmittedText(_ text: String) {
        print("📤 处理提交: \(text)")

        // 添加到历史记录
        historyManager.addCommand(text)

        // 重置导航和当前输入
        currentInput = ""

        // 处理输入的文本
        handleInputText(text)

        // 更新高度（输入框已被 AETextView 自动清空）
        updateTextViewHeight()

        // 确保焦点仍在输入框
        inputTextView.focus()
    }

    /// 处理输入文本的方法
    private func handleInputText(_ text: String) {
        // 这里可以添加处理输入文本的逻辑
        // 例如：执行命令、发送消息等

        let req = AENetHttpReq(post: "chat", parameters: ["user_input":text, "session_id":"session_id"])
        AENetHttpEngine.send(request: req) { rsp in
            print("服务器响应: \(rsp.response)")
        }
    }
}

