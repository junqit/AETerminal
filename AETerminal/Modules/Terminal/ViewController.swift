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

    private var currentContext: AEAIContextInterface?
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
        return currentContext?.navigateQuestionUp()?.content
    }

    func aeTextViewRequestNextHistory(_ textView: AETextView) -> String? {
        return currentContext?.navigateQuestionDown()?.content
    }
}

// MARK: - AEAIEnginModuleDelegate

extension ViewController: AEAIEnginModuleDelegate {

    func enginModule(_ module: AEAIEnginModuleProtocol, willSendRequest request: AENetReq, from context: AEAIContextInterface) {
        guard context.ident == currentContext?.ident else { return }
        // ques 嵌套在 cont 内解析
        guard let cont = request.parameters?["cont"] as? [String: Any],
              let quesMap = cont["ques"] as? [String: Any],
              let content = quesMap["content"] as? String else { return }
        let question = AEAIQuestion(content: content, type: .text)
        multiChatView?.showUserQuestion(question, for: context.config)
    }

    func enginModule(_ module: AEAIEnginModuleProtocol, didReceiveRsp response: AENetRsp, from context: AEAIContextInterface) {
        guard context.ident == currentContext?.ident else { return }
        guard let rsp = response.response?["rsp"] as? [String: Any],
              let reply = rsp["reply"] as? String else { return }
        multiChatView?.showAIResponse(reply, for: context.config)
    }

    func enginModule(_ module: AEAIEnginModuleProtocol, didChangeCurrentContext context: AEAIContextInterface) {
        currentContext = context
        multiChatView?.confirmCurrentContext(context.config)
        if !inputTextView.isEditable {
            inputTextView.isEditable = true
            inputTextView.focus()
        }
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
