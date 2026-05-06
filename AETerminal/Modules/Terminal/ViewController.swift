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
    @IBOutlet weak var chatView: AEChatViewNew!

    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200

    // 暂存当前输入（用于在浏览历史时保存）
    private var currentInput: String = ""

    // AI Engine 模块
    private var aiEnginModule: AEAIEnginModuleProtocol?

    // 当前活动的 AI Context（用于发送问题）
    private var currentContext: AEAIContextInterface?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor

        // 获取 AI Engine 模块
        setupAIEnginModule()

        // 设置 AETextView 的 delegate
        inputTextView.delegate = self

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

    // MARK: - AI Engine Module Setup

    /// 设置 AI Engine 模块
    private func setupAIEnginModule() {
        // 通过 AEModuleCenter 获取 AI Engine 模块
        aiEnginModule = AEModuleCenter.module(for: AEAIEnginModuleProtocol.self)

        if aiEnginModule != nil {
            print("✅ AI Engine 模块获取成功")
        } else {
            print("⚠️ 未找到 AI Engine 模块")
        }
    }

    // MARK: - History Navigation

    /// 向上浏览历史记录（更旧的命令）
    private func navigateHistoryUp() {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return
        }

        if let question = context.navigateQuestionUp() {
            inputTextView.text = question.content
            inputTextView.focus()
        }
    }

    /// 向下浏览历史记录（更新的命令）
    private func navigateHistoryDown() {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return
        }

        if let question = context.navigateQuestionDown() {
            inputTextView.text = question.content
        } else {
            // 回到当前输入
            inputTextView.text = currentInput
        }

        inputTextView.focus()
    }
}


// MARK: - AETextViewDelegate

extension ViewController: AETextViewDelegate {

    /// 用户实时输入文本时调用
    func aeTextView(_ textView: AETextView, didChangeInput package: AETextPackage) {
        print("⌨️ 实时输入: \(package.rawText)")

        // 委托给 AI Engine 模块处理
        aiEnginModule?.handleRealtimeInput(package)
    }

    /// 用户输入文本时调用（回车提交）
    func aeTextView(_ textView: AETextView, didInputText package: AETextPackage) {
        print("✅ 提交内容: \(package.rawText)")
        print("📦 包类型: \(package.type), 内容: \(package.content)")

        // 委托给 AI Engine 模块处理
        aiEnginModule?.handleInputCompleted(package)
    }

    /// 文本高度变化时调用（AETextView 已计算好高度）
    func aeTextView(_ textView: AETextView, didChangeHeight height: CGFloat) {
        // 高度变化处理（如果需要可以在这里更新约束）
        // 目前不需要处理，因为已删除 scrollViewHeightConstraint
    }

    /// 请求上一条历史记录（当前 Context 的）
    func aeTextViewRequestPreviousHistory(_ textView: AETextView) -> String? {
        guard let context = currentContext else {
            print("⚠️ 没有当前 Context")
            return nil
        }

        if let question = context.navigateQuestionUp() {
            print("⬆️ 加载上一条消息: \(question.content)")
            return question.content
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

        if let question = context.navigateQuestionDown() {
            print("⬇️ 加载下一条消息: \(question.content)")
            return question.content
        } else {
            print("⚠️ 没有更新的消息")
            return nil
        }
    }
}
