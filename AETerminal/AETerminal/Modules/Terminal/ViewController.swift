//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AEAIEngin
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

    // 暂存当前输入（用于在浏览历史时保存）
    private var currentInput: String = ""

    // 网络服务模块
    private var networkService: AEAINetworkProtocol?

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

        // 配置 AENetHttpEngine
        let httpConfig = AENetConfig(
            host: "localhost",
            port: 8000
        )
        AENetHttpEngine.configure(config: httpConfig, timeout: 30)

        // 获取网络能力并注册监听
        setupNetworkService()

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

    // MARK: - Network Service Setup

    /// 设置网络服务并注册监听
    private func setupNetworkService() {
        // 通过协议获取网络能力
        networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self)

        // 注册网络消息监听
        if let service = networkService {
            service.addListener(self)
            print("✅ 网络服务监听注册成功")
        } else {
            print("⚠️ 未找到网络服务模块")
        }
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
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return
        }

        // 如果是第一次按上下键，保存当前输入
        if context.historyIndex == -1 {
            currentInput = inputTextView.text
        }

        if let command = context.navigateHistoryUp() {
            inputTextView.text = command
            inputTextView.focus()
        }
    }

    /// 向下浏览历史记录（更新的命令）
    private func navigateHistoryDown() {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return
        }

        if let command = context.navigateHistoryDown() {
            inputTextView.text = command
        } else {
            // 回到当前输入
            inputTextView.text = currentInput
        }

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
        // 1. 发送请求到云端创建 Context
        sendCreateContextRequest(aedir: path) { [weak self] contextId in
            guard let self = self, let contextId = contextId else {
                print("❌ 云端 Context 创建失败")
                return
            }

            print("✅ 云端 Context 创建成功")
            print("   Context ID: \(contextId)")

            // 2. 使用云端返回的 contextId 创建本地 Context
            let config = AEContextConfig(content: path)

            // 使用云端返回的 contextId 作为本地 Context 的 ID
            self.currentContext = AEAIContextManager.createContext(config, withId: contextId)

            print("✅ 本地 Context 创建成功")
            print("   Context ID: \(self.currentContext?.id ?? "")")
            print("   Directory: \(self.currentContext?.dir ?? "")")

            // 3. 刷新右侧视图
            self.rightView?.reloadData()
        }
    }

    // MARK: - Network Request

    /// 发送创建 Context 请求到云端
    private func sendCreateContextRequest(aedir: String, completion: @escaping (String?) -> Void) {
        print("📤 发送创建 Context 请求")
        print("   AE Dir: \(aedir)")

        // 使用 AENetReq 构建 POST 请求
        let request = AENetReq(
            post: AEAIServicePath.createContext.rawValue,
            parameters: ["aedir": aedir],
            protocolType: .http
        )

        // 通过 AEModuleCenter 获取网络服务并发送请求
        guard let networkService = networkService else {
            print("❌ 网络服务未初始化")
            completion(nil)
            return
        }

        networkService.sendRequest(request) { response in
            if response.isSuccess {
                // 解析响应
                if let contextId = response.response?["contextid"] as? String {
                    print("✅ 收到云端响应")
                    print("   Context ID: \(contextId)")
                    completion(contextId)
                } else {
                    print("❌ 响应格式错误 - 缺少 contextid 字段")
                    completion(nil)
                }
            } else {
                print("❌ 网络请求失败")
                if let error = response.error {
                    print("   错误: \(error.localizedDescription)")
                }
                completion(nil)
            }
        }
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

        // 4. 重置 Context 的消息导航索引（确保从最新开始）
        context.messageManager.resetToLatest()

        // 5. 重置历史导航状态
        context.resetHistoryNavigation()
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

        // 添加到当前 Context 的历史记录
        currentContext?.addCommandToHistory(text)

        // 重置当前输入
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

        // 使用 chatView 的 addAIResponse 方法来自动解析和显示响应
        // 该方法内部会使用 AEAIResponseParser 解析 llm_responses 中的所有内容
        DispatchQueue.main.async { [weak self] in
            self?.chatView?.addAIResponse(response)
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

// MARK: - AENetworkMessageListener

extension ViewController: AENetworkMessageListener {

    /// 接收到网络消息
    func didReceiveMessage(_ response: AENetRsp) {
        print("📥 收到网络消息, requestId: \(response.requestId)")

        guard let message = response.response else {
            print("⚠️ 响应数据为空")
            return
        }

        guard let sessionId = message["sessionid"] as? String else {
            print("⚠️ 消息中缺少 sessionid 字段")
            return
        }

        guard let context = AEAIContextManager.getContext(id: sessionId) else {
            print("⚠️ 未找到 sessionid 对应的 Context: \(sessionId)")
            return
        }

        print("✅ 找到对应的 Context: \(context.id)")

        handleNetworkMessage(message, for: context)
    }

    /// 处理网络消息（由 Context 处理）
    private func handleNetworkMessage(_ message: [String: Any], for context: AEAIContext) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if context.id == self.currentContext?.id {
                self.chatView?.addAIResponse(message as AnyObject)
                print("✅ 已显示网络消息到 chatView")
            } else {
                print("⚠️ 收到的消息不属于当前活动的 Context")
            }
        }
    }
}
