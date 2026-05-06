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

    func sendRequest(_ question: AEAIQuestion, from context: AEAIContextInterface) {
        // 显示用户消息到对应的 Context 聊天视图
        multiChatView?.showUserQuestion(question, for: context.config)
    }

    private func convertToAIQuestion(_ package: AETextPackage) -> AEAIQuestion {
        switch package.type {
        case .text:
            return AEAIQuestion.text(package.content)

        case .directory:
            return AEAIQuestion.command(package.content, parameters: ["commandType": "directory"])

        case .permission:
            return AEAIQuestion.command(package.content, parameters: ["commandType": "permission"])

        case .file:
            return AEAIQuestion.search(package.content)
        }
    }
}
