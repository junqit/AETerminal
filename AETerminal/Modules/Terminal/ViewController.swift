//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AEAIEngin
import AEAIModule

class ViewController: NSViewController {

    @IBOutlet weak var inputTextView: AETextView!
    @IBOutlet weak var leftView: AELeftView!
    @IBOutlet weak var rightView: AERightView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var statusView: NSView!
    @IBOutlet weak var chatView: AEChatView!
    
    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200
    
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

        // 检查 chatView 是否正确连接
        if chatView != nil {
            print("✅ chatView 已连接")
        } else {
            print("❌ chatView 未连接！请检查 Storyboard/XIB 连接")
        }

        // Do any additional setup after loading the view.
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // 预先准备获取焦点
        DispatchQueue.main.async { [weak self] in
            self?.inputTextView.focus()
        }

        // 在视图即将显示时测试 chatView
        print("🔍 viewWillAppear - chatView frame: \(chatView?.frame ?? .zero)")
        print("🔍 viewWillAppear - chatView superview: \(chatView?.superview != nil ? "有" : "无")")
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

        // 视图完全显示后，测试添加一条欢迎消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let chatView = self.chatView else {
                print("❌ chatView 为 nil，无法添加欢迎消息")
                return
            }

            print("🎯 添加欢迎消息到 chatView")
            chatView.addWelcomeMessage()
        }
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

        // 确保焦点在输入框
        inputTextView.focus()
    }
}

// MARK: - AELeftViewDelegate

extension ViewController: AELeftViewDelegate, AELeftViewFocusDelegate {

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

    /// 当 leftView 获得焦点时
    func leftViewDidBecomeFocused(_ leftView: AELeftView) {
        // 清除 rightView 的选中状态
        rightView?.clearSelection()
        print("⚠️ leftView 获得焦点，清除 rightView 选中状态")
    }

    // MARK: - Helper Methods

    /// 创建第一个 AI Context
    private func createFirstContext(withDirectory path: String) {
        // 创建配置
        let config = AEContextConfig(content: path)

        // 通过 Manager 创建并管理 Context
        currentContext = AEAIContextManager.createContext(config)

        print("✅ 创建第一个 Context: \(currentContext?.dir ?? "")")
        print("   Context ID: \(currentContext?.id ?? "")")

        // 同时通知 rightView 刷新列表
        rightView?.reloadData()
    }
}

// MARK: - AERightViewDelegate

extension ViewController: AERightViewDelegate, AERightViewFocusDelegate {

    /// 用户选中某个 Context
    func rightView(_ rightView: AERightView, didSelectContext context: AEAIContext) {
        print("✅ 切换 Context: \(context.dir)")
        print("   Context ID: \(context.id)")

        // 切换当前活动的 Context
        currentContext = context

        // 在 statusView 中显示当前 Context 的目录信息
        updateStatusView(with: context)

        // 切换 Context 后，加载新 Context 的历史消息
        switchToContext(context)
    }

    // MARK: - Context Switching

    /// 切换到指定的 Context
    private func switchToContext(_ context: AEAIContext) {
        // 1. 清空当前输入
        inputTextView.text = ""

        // 2. 清空 chatView 的消息记录
        chatView?.clearMessages()

        // 3. 显示系统消息：切换到新的 Context
        chatView?.addSystemMessage("切换到新的 Context: \(context.dir)")

        // 4. 加载新 Context 的当前消息（如果有）
        if let currentMessage = context.getCurrentQuestion() {
            inputTextView.text = currentMessage.content
            print("✅ 加载 Context 的当前消息: \(currentMessage.content)")
        } else {
            print("⚠️ 新 Context 没有历史消息")
        }

        // 5. 重置历史导航状态
        historyManager.resetNavigation()
        currentInput = ""

        // 6. 让输入框获得焦点
        inputTextView.focus()
    }

    /// 当 rightView 获得焦点时
    func rightViewDidBecomeFocused(_ rightView: AERightView) {
        // 清除 leftView 的选中状态
        leftView?.clearSelection()
        print("⚠️ rightView 获得焦点，清除 leftView 选中状态")
    }

    // MARK: - Status View Update

    /// 更新 statusView 显示 Context 信息
    private func updateStatusView(with context: AEAIContext) {
        // 清除 statusView 中的所有子视图
        statusView.subviews.forEach { $0.removeFromSuperview() }

        // 创建显示 Context 目录的标签
        let label = NSTextField()
        label.stringValue = "📁 \(context.dir)"
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        statusView.addSubview(label)

        // 设置约束
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: statusView.centerYAnchor)
        ])

        print("✅ 更新 statusView 显示: \(context.dir)")
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

    /// 请求上一条历史记录（当前 Context 的）
    func aeTextViewRequestPreviousHistory(_ textView: AETextView) -> String? {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return nil
        }

        if let previousMessage = context.getPreviousQuestion() {
            print("⬆️ 加载上一条消息: \(previousMessage.content)")
            return previousMessage.content
        } else {
            print("⚠️ 没有更早的消息")
            return nil
        }
    }

    /// 请求下一条历史记录（当前 Context 的）
    func aeTextViewRequestNextHistory(_ textView: AETextView) -> String? {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return nil
        }

        if let nextMessage = context.getNextQuestion() {
            print("⬇️ 加载下一条消息: \(nextMessage.content)")
            return nextMessage.content
        } else {
            print("⚠️ 没有更新的消息")
            return nil
        }
    }

    /// 处理提交的文本（回车提交）
    private func handleSubmittedText(_ text: String) {
        print("📤 处理提交: \(text)")

        // 添加到历史记录
        historyManager.addCommand(text)

        // 重置导航和当前输入
        currentInput = ""

        // 在 chatView 中显示用户消息
        chatView?.addUserMessage(text)

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
        print("🔍 AI 响应原始数据: \(response)")

        var responseText = ""
        var isMarkdown = false
        var assistantName = "AI"  // 默认名字

        // 解析响应数据
        if let dict = response as? [String: Any] {
            print("📦 响应是字典类型，键: \(dict.keys.sorted())")

            // 调试：打印完整的数据结构
            print("📊 完整数据结构：")
            debugPrintDictStructure(dict)

            // 优先查找 llm_responses（支持数组或字典格式）
            if let llmResponsesArray = dict["llm_responses"] as? [[String: Any]], let firstResponse = llmResponsesArray.first {
                // 格式 1: llm_responses 是数组
                print("✅ 找到 llm_responses 数组，共 \(llmResponsesArray.count) 项")
                print("📝 解析第一个响应: \(firstResponse.keys.sorted())")
                (responseText, isMarkdown) = parseResponseContent(firstResponse)
            }
            else if let llmResponsesDict = dict["llm_responses"] as? [String: Any] {
                // 格式 2: llm_responses 是字典（如 {"claude": {...}, "gpt": {...}}）
                print("✅ 找到 llm_responses 字典，键: \(llmResponsesDict.keys.sorted())")

                // 优先尝试 "claude" 键，如果没有则取第一个值
                if let claudeResponse = llmResponsesDict["claude"] as? [String: Any] {
                    print("📝 解析 claude 响应: \(claudeResponse.keys.sorted())")
                    assistantName = "Claude"  // 使用键名作为 AI 名字
                    (responseText, isMarkdown) = parseResponseContent(claudeResponse)
                } else if let firstKey = llmResponsesDict.keys.first,
                          let firstValue = llmResponsesDict[firstKey] as? [String: Any] {
                    print("📝 解析第一个响应: \(firstValue.keys.sorted())")
                    assistantName = firstKey.capitalized  // 使用键名作为 AI 名字
                    (responseText, isMarkdown) = parseResponseContent(firstValue)
                }
            }
            // 兼容其他可能的数据格式
            else if let data = dict["data"] as? [String: Any] {
                print("📝 找到 data 字段，尝试解析")
                (responseText, isMarkdown) = parseResponseContent(data)
            }
            // 直接在根级别查找
            else {
                print("📝 在根级别查找内容")
                (responseText, isMarkdown) = parseResponseContent(dict)
            }

            // 如果都没找到，格式化整个字典
            if responseText.isEmpty {
                print("⚠️ 未找到标准字段，格式化整个响应")
                if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    responseText = "```json\n\(jsonString)\n```"
                    isMarkdown = true
                } else {
                    responseText = "\(dict)"
                    isMarkdown = false
                }
            }
        } else if let string = response as? String {
            // 如果已经是字符串
            responseText = string
            isMarkdown = detectMarkdown(string)
            print("✅ 响应是字符串类型")
        } else if let data = response as? Data, let string = String(data: data, encoding: .utf8) {
            // 如果是 Data 类型
            responseText = string
            isMarkdown = detectMarkdown(string)
            print("✅ 响应是 Data 类型")
        } else {
            // 其他类型，直接转换为字符串描述
            responseText = "\(response)"
            isMarkdown = false
            print("⚠️ 响应类型未知: \(type(of: response))")
        }

        // 显示在 chatView 中
        DispatchQueue.main.async { [weak self] in
            if responseText.isEmpty {
                self?.chatView?.addErrorMessage("AI 响应为空")
            } else {
                self?.chatView?.addAssistantMessage(responseText, isMarkdown: isMarkdown, assistantName: assistantName)
            }
        }
    }

    /// 解析响应内容（支持多种字段名和类型）
    /// - Parameter dict: 响应字典
    /// - Returns: (内容文本, 是否为 Markdown)
    private func parseResponseContent(_ dict: [String: Any]) -> (String, Bool) {
        // 优先级顺序尝试不同的字段名
        let fieldNames = [
            ("response", true),      // 通用字段，默认 markdown
            ("markdown", true),      // 明确的 markdown 字段
            ("content", true),       // 内容字段，默认 markdown
            ("text", false),         // 普通文本
            ("message", false),      // 消息字段
            ("answer", true),        // 答案字段
            ("result", true)         // 结果字段
        ]

        for (fieldName, defaultMarkdown) in fieldNames {
            if let value = dict[fieldName] {
                // 尝试多种类型
                if let stringValue = value as? String {
                    print("✅ 找到字段 '\(fieldName)' (String)")
                    return (stringValue, detectMarkdown(stringValue, default: defaultMarkdown))
                } else if let dictValue = value as? [String: Any] {
                    print("✅ 找到字段 '\(fieldName)' (Dictionary), 递归解析")
                    return parseResponseContent(dictValue)
                } else if let arrayValue = value as? [[String: Any]], let first = arrayValue.first {
                    print("✅ 找到字段 '\(fieldName)' (Array), 解析第一个元素")
                    return parseResponseContent(first)
                } else if let arrayValue = value as? [String], let first = arrayValue.first {
                    print("✅ 找到字段 '\(fieldName)' (String Array), 取第一个")
                    return (first, detectMarkdown(first, default: defaultMarkdown))
                } else {
                    // 其他类型，转为字符串
                    let stringValue = "\(value)"
                    print("✅ 找到字段 '\(fieldName)' (Other: \(type(of: value)))")
                    return (stringValue, detectMarkdown(stringValue, default: defaultMarkdown))
                }
            }
        }

        print("⚠️ 未找到任何已知字段")
        return ("", false)
    }

    /// 检测文本是否包含 Markdown 标记
    /// - Parameters:
    ///   - text: 待检测的文本
    ///   - default: 默认值（如果无法判断）
    /// - Returns: 是否为 Markdown
    private func detectMarkdown(_ text: String, default defaultValue: Bool = true) -> Bool {
        // 检查常见的 Markdown 标记
        let markdownPatterns = [
            "```",           // 代码块
            "##",            // 标题
            "**",            // 粗体
            "- ",            // 列表
            "* ",            // 列表
            "> ",            // 引用
            "[",             // 链接
            "`"              // 行内代码
        ]

        for pattern in markdownPatterns {
            if text.contains(pattern) {
                return true
            }
        }

        // 如果没有检测到 Markdown 标记，使用默认值
        return defaultValue
    }

    /// 调试工具：打印字典的完整结构
    /// - Parameter dict: 待打印的字典
    /// - Parameter indent: 缩进级别
    private func debugPrintDictStructure(_ dict: [String: Any], indent: Int = 0) {
        let indentStr = String(repeating: "  ", count: indent)
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if let dictValue = value as? [String: Any] {
                print("\(indentStr)\(key): [Dictionary]")
                debugPrintDictStructure(dictValue, indent: indent + 1)
            } else if let arrayValue = value as? [[String: Any]] {
                print("\(indentStr)\(key): [Array of Dictionary] (count: \(arrayValue.count))")
                if let first = arrayValue.first {
                    debugPrintDictStructure(first, indent: indent + 1)
                }
            } else if let arrayValue = value as? [String] {
                print("\(indentStr)\(key): [Array of String] (count: \(arrayValue.count))")
                if let first = arrayValue.first {
                    print("\(indentStr)  [0]: \(first.prefix(50))...")
                }
            } else {
                let valueStr = "\(value)"
                let preview = valueStr.prefix(100)
                print("\(indentStr)\(key): \(type(of: value)) = \(preview)...")
            }
        }
    }

    /// 处理 AI 错误
    private func handleAIError(_ error: Error) {
        print("错误: \(error.localizedDescription)")

        // 在 chatView 中显示错误消息
        DispatchQueue.main.async { [weak self] in
            self?.chatView?.addErrorMessage(error.localizedDescription)
        }
    }
}
