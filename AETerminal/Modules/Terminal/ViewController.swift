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
    @IBOutlet weak var multiChatView: AEMultiChatView!

    private var aiEnginModule: AEAIEnginModuleProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        setupAIEnginModule()
        inputTextView.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        DispatchQueue.main.async { [weak self] in
            self?.inputTextView.focus()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        inputTextView.focus()
    }

    private func setupAIEnginModule() {
        aiEnginModule = AEModuleCenter.module(for: AEAIEnginModuleProtocol.self)
        aiEnginModule?.delegate = self
    }
}


// MARK: - AETextViewDelegate

extension ViewController: AETextViewDelegate {

    func aeTextView(_ textView: AETextView, didChangeInput package: AETextPackage) {
        let question = convertToAIQuestion(package)
        aiEnginModule?.handleRealtimeInput(question)
    }

    func aeTextView(_ textView: AETextView, didInputText package: AETextPackage) {
        let question = convertToAIQuestion(package)
        aiEnginModule?.handleInputCompleted(question)
    }

    func aeTextView(_ textView: AETextView, didChangeHeight height: CGFloat) {
    }

    func aeTextViewRequestPreviousHistory(_ textView: AETextView) -> String? {
        guard let context = aiEnginModule?.getCurrentContext() else { return nil }
        return context.navigateQuestionUp()?.content
    }

    func aeTextViewRequestNextHistory(_ textView: AETextView) -> String? {
        guard let context = aiEnginModule?.getCurrentContext() else { return nil }
        return context.navigateQuestionDown()?.content
    }
}

// MARK: - AEAIEnginModuleDelegate

extension ViewController: AEAIEnginModuleDelegate {

    // MARK: - AEAIContextDelegate

    func sendRequest(_ question: AEAIQuestion, from context: AEAIContextInterface) {
        multiChatView?.showUserQuestion(question, for: context.config)
    }

    func didReceiveAnswer(_ answer: AEAIAnswer, from context: AEAIContextInterface) {
        multiChatView?.showAIResponse(answer.content, for: context.config)
    }

    // MARK: - AEAIContextManagerDelegate

    func contextManager(_ manager: AEAIContextManager, didUpdateContexts contexts: [AEAIContextInterface]) {
        // 同步聊天视图：移除不存在的，添加新增的
        let currentIds = Set(multiChatView?.getAllContextIds() ?? [])
        let newIds = Set(contexts.map { $0.ident })

        // 移除已不存在的 Context 视图
        for id in currentIds.subtracting(newIds) {
            multiChatView?.removeChatView(for: id)
        }

        // 添加新增的 Context 视图
        for context in contexts where !currentIds.contains(context.ident) {
            let config = context.config
            multiChatView?.addChatView(for: config.ident, contextName: "\(config.type.rawValue) - \(config.space)")
        }
    }

    func contextManager(_ manager: AEAIContextManager, didAddContext context: AEAIContextInterface) {
        let config = context.config
        multiChatView?.addChatView(for: config.ident, contextName: "\(config.type.rawValue) - \(config.space)")
    }

    func contextManager(_ manager: AEAIContextManager, didRemoveContext context: AEAIContextInterface) {
        multiChatView?.removeChatView(for: context.ident)
    }

    // MARK: - Private

    private func convertToAIQuestion(_ package: AETextPackage) -> AEAIQuestion {
        switch package.type {
        case .text:
            return AEAIQuestion(content: package.content, type: .text)

        case .directory:
            return AEAIQuestion(content: package.content, type: .command, parameters: ["commandType": "directory"])

        case .permission:
            return AEAIQuestion(content: package.content, type: .command, parameters: ["commandType": "permission"])

        case .file:
            return AEAIQuestion(content: package.content, type: .search)
        }
    }
}
