//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AEAIEngin

class ViewController: NSViewController {

    @IBOutlet weak var inputTextView: AETextView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!

    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200

    @IBOutlet weak var leftView: AELeftView!
    @IBOutlet weak var rightView: AERightView!

    // 命令历史记录管理器
    private let historyManager = CommandHistoryManager.shared

    // 暂存当前输入（用于在浏览历史时保存）
    private var currentInput: String = ""

    // 当前活动的 AI Context（用于发送问题）
    private var currentContext: AEAIContext? {
        didSet {
            // 当 currentContext 变化时，通知 rightView 更新选中状态
            if let context = currentContext {
                rightView?.setSelectedContext(context)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor

        // 设置 AETextView 的 delegate
        inputTextView.delegate = self

        // 设置左侧视图
        setupLeftView()

        // 设置右侧视图
        setupRightView()

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

    // MARK: - Right View Setup

    /// 设置右侧 Context 列表视图
    private func setupRightView() {
        guard let rightView = rightView else { return }

        rightView.delegate = self
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

    // 根据 AETextView 计算好的高度更新约束
    private func updateTextViewHeight(_ calculatedHeight: CGFloat) {
        // 限制在最小和最大高度之间
        let newHeight = max(minHeight, min(calculatedHeight, maxHeight))

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
        print("✅ 确认选择目录: \(path)")

        // 检查是否为目录
        guard AEDirectory.isDirectory(atPath: path) else {
            print("❌ 不是有效的目录: \(path)")
            return
        }

        createFirstContext(withDirectory: path)
    }

    // MARK: - Helper Methods

    /// 创建第一个 AI Context
    private func createFirstContext(withDirectory path: String) {
        // 创建配置
        let config = AEContextConfig(content: path)

        // 通过 Manager 创建并管理 Context
        currentContext = AEAIContextManager.createContext(config)

        print("✅ 创建第一个 Context: \(currentContext?.content ?? "")")
        print("   Context ID: \(currentContext?.id ?? "")")

        // 同时通知 rightView 刷新列表
        rightView?.reloadData()
    }
}

// MARK: - AERightViewDelegate

extension ViewController: AERightViewDelegate {

    /// 用户选中某个 Context
    func rightView(_ rightView: AERightView, didSelectContext context: AEAIContext) {
        print("✅ 切换 Context: \(context.content)")
        print("   Context ID: \(context.id)")

        // 切换当前活动的 Context
        currentContext = context
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

    /// 文本高度变化时调用（AETextView 已计算好高度）
    func aeTextView(_ textView: AETextView, didChangeHeight height: CGFloat) {
        updateTextViewHeight(height)
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

        // 确保焦点仍在输入框（输入框已被 AETextView 自动清空并回调高度）
        inputTextView.focus()
    }

    /// 处理输入文本的方法
    private func handleInputText(_ text: String) {
        // 检查是否有当前的 Context
        guard let context = currentContext else {
            print("⚠️ 没有活动的 Context，请先加载目录")
            return
        }

        // 创建 AI 问题
        let question = AEAIQuestion.text(text)

        print("📤 发送问题到 Context [\(context.id)]")
        print("   问题内容: \(text)")

        // 通过 Context 发送问题
        context.sendQuestion(question) { [weak self] result in
            switch result {
            case .success(let response):
                print("✅ AI 响应成功")
                self?.handleAIResponse(response)
            case .failure(let error):
                print("❌ AI 响应失败: \(error.localizedDescription)")
                self?.handleAIError(error)
            }
        }

        // 发送问题后，刷新 rightView（因为 lastUsedTime 更新了）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rightView?.reloadData()
        }
    }

    /// 处理 AI 响应
    private func handleAIResponse(_ response: AnyObject) {
        // TODO: 在这里处理 AI 的响应
        // 例如：显示在聊天界面、更新UI等
        print("AI 响应内容: \(response)")
    }

    /// 处理 AI 错误
    private func handleAIError(_ error: Error) {
        // TODO: 在这里处理错误
        // 例如：显示错误提示等
        print("错误: \(error.localizedDescription)")
    }
}

