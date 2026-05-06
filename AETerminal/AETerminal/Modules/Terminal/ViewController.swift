//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AEAIEnginModule
import AEAIModule
import AENetworkEngine
import AEModuleCenter
import AEAINetworkModule

class ViewController: NSViewController {

    @IBOutlet weak var inputTextView: AETextView!
    @IBOutlet weak var leftView: AELeftView!
    @IBOutlet weak var rightView: AERightView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var statusView: NSView!
    @IBOutlet weak var chatView: AEChatViewNew!
    
    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200

    // 网络服务模块（计算属性，实时获取）
    private var networkService: AEAINetworkProtocol? {
        return AEModuleCenter.module(for: AEAINetworkProtocol.self)
    }

    // AI Engine 模块（计算属性，实时获取）
    private var engineModule: AEAIEnginModuleProtocol? {
        return AEModuleCenter.module(for: AEAIEnginModuleProtocol.self)
    }

    // 当前活动的 AI Context（用于发送问题）
    private var currentContext: AEAIContextInterface? {
        didSet {
            // 当 currentContext 变化时，通知 rightView 更新选中状态
            if let context = currentContext {
//                rightView?.setSelectedContext(context)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor

        // AENetHttpEngine 不再需要单独配置
        // HTTP 引擎实例由 AEAINetworkModule 管理

        // 设置 AETextView 的 delegate
        inputTextView.delegate = self

        // 设置左侧视图
        setupLeftView()

        // 设置右侧视图
        setupRightView()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        DispatchQueue.main.async { [weak self] in
            self?.inputTextView.focus()
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

//        rightView.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        inputTextView.focus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let chatView = self.chatView else { return }
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
        let newHeight = max(minHeight, min(calculatedHeight, maxHeight))
        scrollViewHeightConstraint.constant = newHeight
    }

    // MARK: - History Navigation

    /// 向上浏览历史记录（更旧的问题）
    private func navigateHistoryUp() {
        guard let context = currentContext else { return }

        if let question = context.navigateQuestionUp() {
            inputTextView.text = question.content
            inputTextView.focus()
        }
    }

    /// 向下浏览历史记录（更新的问题）
    private func navigateHistoryDown() {
        guard let context = currentContext else { return }

        if let question = context.navigateQuestionDown() {
            inputTextView.text = question.content
        }

        inputTextView.focus()
    }
}

// MARK: - AELeftViewDelegate

extension ViewController: AELeftViewDelegate, AELeftViewFocusDelegate {

    /// 处理目录确认选择
    func leftView(_ leftView: AELeftView, didConfirmDirectory path: String) {
        guard AEDirectory.isDirectory(atPath: path) else {
            print("❌ 不是有效的目录: \(path)")
            return
        }

        createFirstContext(withDirectory: path)
    }

    /// 当 leftView 获得焦点时
    func leftViewDidBecomeFocused(_ leftView: AELeftView) {
        rightView?.clearSelection()
    }

    // MARK: - Helper Methods

    /// 创建第一个 AI Context
    private func createFirstContext(withDirectory path: String) {
        sendCreateContextRequest(aedir: path) { [weak self] contextId in
            guard let self = self, let contextId = contextId else {
                print("❌ Context 创建失败")
                return
            }

            // 直接创建 WorkSpaceContext
            let newContext = AEWorkSpaceContext(ident: contextId, space: path)

            // 设置 Context 的 delegate
            newContext.delegate = self

            // 添加到 ContextManager
            AEAIContextManager.addContext(newContext)

            // 设置为当前 Context
            self.currentContext = newContext

            self.rightView?.reloadData()
            print("✅ Context 创建成功: \(contextId)")
        }
    }

    // MARK: - Network Request

    /// 发送创建 Context 请求到云端
    private func sendCreateContextRequest(aedir: String, completion: @escaping (String?) -> Void) {
        guard let networkService = networkService else {
            print("❌ 网络服务未初始化")
            completion(nil)
            return
        }

        let request = AENetReq(
            post: AEAIServicePath.createContext.rawValue,
            parameters: ["aedir": aedir],
            protocolType: .http
        )

        networkService.sendRequest(request) { response in
            if response.isSuccess, let contextId = response.response?["contextid"] as? String {
                completion(contextId)
            } else {
                if let error = response.error {
                    print("❌ 网络请求失败: \(error.localizedDescription)")
                }
                completion(nil)
            }
        }
    }
}

// MARK: - AERightViewDelegate

extension ViewController: AERightViewFocusDelegate {

    /// 用户选中某个 Context
    func rightView(_ rightView: AERightView, didSelectContext context: AEAIContextInterface) {
        print("✅ 切换 Context: \(context.space)")
        print("   Context ID: \(context.ident)")

        // 切换当前活动的 Context
        currentContext = context

        // 设置 Context 的 delegate 为当前控制器
        context.delegate = self

        // 在 statusView 中显示当前 Context 的目录信息
        updateStatusView(with: context)

        // 切换 Context 后，加载新 Context 的历史消息
        switchToContext(context)
    }

    // MARK: - Context Switching

    /// 切换到指定的 Context
    private func switchToContext(_ context: AEAIContextInterface) {
        // 1. 清空当前输入
        inputTextView.text = ""

        // 2. 清空 chatView 的消息记录
        chatView?.clearMessages()

        // 3. 显示系统消息：切换到新的 Context
        chatView?.addSystemMessage("切换到新的 Context: \(context.space)")


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
    private func updateStatusView(with context: AEAIContextInterface) {
        // 清除 statusView 中的所有子视图
        statusView.subviews.forEach { $0.removeFromSuperview() }

        // 创建显示 Context 目录的标签
        let label = NSTextField()
        label.stringValue = "📁 \(context.space)"
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

        print("✅ 更新 statusView 显示: \(context.space)")
    }
}

// MARK: - AETextViewDelegate

extension ViewController: AETextViewDelegate {

    /// 用户实时输入文本时调用
    func aeTextView(_ textView: AETextView, didChangeInput package: AETextPackage) {
        print("⌨️ 实时输入: \(package.rawText)")

        // 获取 AI Engine 模块并传入用户实时输入的文本包
        if let engineModule = engineModule {
            engineModule.handleRealtimeInput(package)
        } else {
            print("⚠️ AI Engine 模块未初始化")
        }
    }

    /// 用户输入文本时调用（回车提交）
    func aeTextView(_ textView: AETextView, didInputText package: AETextPackage) {
        // 这是回车提交的完整内容
        print("✅ 提交内容: \(package.rawText)")
        print("📦 包类型: \(package.type), 内容: \(package.content)")

        // 获取 AI Engine 模块并传入用户输入完成的文本包
        if let engineModule = engineModule {
            engineModule.handleInputCompleted(package)
        } else {
            print("⚠️ AI Engine 模块未初始化")
        }

        // 对于文本类型，继续原有的处理逻辑（显示在 UI 中）
        if package.type == .text {
            handleSubmittedText(package.content)
        }
    }

    /// 文本高度变化时调用（AETextView 已计算好高度）
    func aeTextView(_ textView: AETextView, didChangeHeight height: CGFloat) {
        updateTextViewHeight(height)
    }

    /// 请求上一条历史记录（当前 Context 的）
    func aeTextViewRequestPreviousHistory(_ textView: AETextView) -> String? {
        guard let context = currentContext else { return nil }
        return context.navigateQuestionUp()?.content
    }

    /// 请求下一条历史记录（当前 Context 的）
    func aeTextViewRequestNextHistory(_ textView: AETextView) -> String? {
        guard let context = currentContext else { return nil }
        return context.navigateQuestionDown()?.content
    }

    /// 处理提交的文本（回车提交）
    private func handleSubmittedText(_ text: String) {
        print("📤 处理提交: \(text)")

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
        context.sendQuestion(question)

        // 发送问题后，刷新 rightView（因为 lastUsedTime 更新了）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rightView?.reloadData()
        }
    }
}

// MARK: - AEAIContextDelegate

extension ViewController: AEAIContextDelegate {

    /// 发送问题请求
    /// - Parameters:
    ///   - question: AI 问题对象
    ///   - context: 发送请求的 Context
    func sendRequest(_ question: AEAIQuestion, from context: any AEAIContextInterface) {
        print("📤 [ViewController] 收到问题请求: \(question.content)")
        // TODO: 实现发送逻辑
    }
}
