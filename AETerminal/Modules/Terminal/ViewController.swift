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

    private var aiEnginModule: AEAIEnginModuleProtocol? {
        return AEModuleCenter.module(for: AEAIEnginModuleProtocol.self)
    }

    private var isRegistered = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        inputTextView.isEditable = false
        inputTextView.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc private func onAppDidFinishLaunching() {
        registerDelegate()
    }

    private func registerDelegate() {
        guard !isRegistered, let module = aiEnginModule else { return }
        module.addDelegate(self)
        isRegistered = true
    }
}


// MARK: - AETextViewDelegate

extension ViewController: AETextViewDelegate {

    func aeTextView(_ textView: AETextView, didChangeInput package: AETextPackage) {
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

    func enginModuleDidFinishInitialization(_ module: AEAIEnginModuleProtocol) {
        inputTextView.isEditable = true
        inputTextView.focus()
    }

    func enginModule(_ module: AEAIEnginModuleProtocol, didReceiveRsp response: AENetRsp, from context: AEAIContextInterface) {
    }

    func enginModule(_ module: AEAIEnginModuleProtocol, didAddContext context: AEAIContextInterface) {
        let config = context.config
        multiChatView?.addChatView(for: config.ident, contextName: "\(config.type.rawValue) - \(config.space)")
    }

    func enginModule(_ module: AEAIEnginModuleProtocol, didRemoveContext context: AEAIContextInterface) {
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
