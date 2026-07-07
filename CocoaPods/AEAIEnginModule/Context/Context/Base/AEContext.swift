//
//  AEContext.swift
//  AEAIEngin
//
//  Created by Claude on 2026/5/11.
//

import Foundation
import AENetworkEngine

/// Context 信息模型
public struct AEContextInfo {

    public var system: String = ""
    public var processor: String = ""
    public var release: String = ""
    public var version: String = ""
    public var machine: String = ""
    public var cwd: String = ""
    public var node: String = ""

    public init() {}

    public init(from data: [String: Any]) {
        system = data["system"] as? String ?? ""
        processor = data["processor"] as? String ?? ""
        release = data["release"] as? String ?? ""
        version = data["version"] as? String ?? ""
        machine = data["machine"] as? String ?? ""
        cwd = data["cwd"] as? String ?? ""
        node = data["node"] as? String ?? ""
    }
}

/// Context 基类，所有 Context 类型继承于此
public class AEContext: AEAIContextInterface {

    public let config: AEAIContextConfig
    public weak var delegate: AEAIContextDelegate?
    public internal(set) var contextInfo: AEContextInfo = AEContextInfo()

    private var questionHistory: [AEAIQuestion] = []
    private var currentHistoryIndex: Int = -1

    public required init(config: AEAIContextConfig) {
        self.config = config
    }

    // MARK: - 子类初始化入口

    /// 子类重写此方法实现自定义初始化逻辑
    /// 默认先请求 contextInfo，子类可 super 调用后追加逻辑
    open func onInitialize() {
        let request = AENetReq(
            post: AEAIServicePath.contextInfo.rawValue
        )
        guard let delegate = delegate else { return }
        delegate.sendRequest(request, from: self)
    }

    // MARK: - AEAIContextInterface

    public func sendQuestion(_ question: AEAIQuestion) {
        addQuestion(question)
        let request = AENetReq(
            post: AEAIServicePath.chat.rawValue,
            parameters: ["ques": question.toInfoMap()]
        )
        guard let delegate = delegate else { return }
        delegate.sendRequest(request, from: self)
    }

    public func receiveRsp(_ response: AENetRsp) {
        guard let message = response.response,
              let req = message["req"] as? [String: Any],
              let path = req["path"] as? String else { return }

        switch path {
        case AEAIServicePath.chat.rawValue:
            handleChatRsp(response, message: message)
        case AEAIServicePath.contextInfo.rawValue:
            handleContextInfoRsp(response, message: message)
        default:
            handleRsp(response, path: path, message: message)
        }
    }

    private func handleChatRsp(_ response: AENetRsp, message: [String: Any]) {
        guard let delegate = delegate else { return }
        delegate.didReceiveRsp(response, from: self)
    }

    private func handleContextInfoRsp(_ response: AENetRsp, message: [String: Any]) {
        guard response.code == .success,
              let rsp = message["rsp"] as? [String: Any] else { return }

        contextInfo = AEContextInfo(from: rsp)
        didReceiveContextInfo()
    }

    /// 子类重写此方法，在收到 contextInfo 后执行额外逻辑
    open func didReceiveContextInfo() {}

    /// 子类重写此方法处理非 chat / contextInfo 的响应
    open func handleRsp(_ response: AENetRsp, path: String, message: [String: Any]) {}


    // MARK: - Question History Navigation

    public func navigateQuestionUp() -> AEAIQuestion? {
        guard !questionHistory.isEmpty else { return nil }

        if currentHistoryIndex == -1 {
            currentHistoryIndex = 0
        } else if currentHistoryIndex < questionHistory.count - 1 {
            currentHistoryIndex += 1
        }

        return questionHistory[currentHistoryIndex]
    }

    public func navigateQuestionDown() -> AEAIQuestion? {
        guard currentHistoryIndex > 0 else {
            currentHistoryIndex = -1
            return nil
        }

        currentHistoryIndex -= 1
        return questionHistory[currentHistoryIndex]
    }

    // MARK: - Private

    private func addQuestion(_ question: AEAIQuestion) {
        questionHistory.insert(question, at: 0)
        currentHistoryIndex = -1
    }
}
