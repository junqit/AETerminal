import Foundation
import AENetworkEngine
import AEModuleCenter
import AEAINetworkModule
import AEFoundation
import AEUserAccountModule
import AELogProxy

/// AI 上下文管理器
public class AEAIContextManager {
    
    internal let contexts = AEAtom<[String: AEAIContextInterface]>([:])
    internal var currentContext: AEAIContextInterface?

    public weak var delegate: AEAIContextManagerDelegate?
    public weak var contextDelegate: AEAIContextDelegate?
    public weak var lifecycleDelegate: AEAIContextLifecycleDelegate?

    internal var networkService: AEAINetworkProtocol? {
        return AEModuleCenter.module(for: AEAINetworkProtocol.self)
    }

    public init() {}

    // MARK: - 初始化检查
    public func checkAndRestoreContext() {
        if currentContext != nil { return }

        var hasDirectory = false
        var hasPermission = false
        
        contexts.read { dict in
            for value in dict.values {
                if let dir = value as? AEDirectoryContext {
                    hasDirectory = true
                } else if value is AEPermissionContext {
                    hasPermission = true
                }
            }
        }

        if !hasDirectory {
            let config = AEAIContextConfig(ident: "", space: "", type: .directory)
            createContext(config: config)
        }

        if !hasPermission {
            let config = AEAIContextConfig(ident: "", space: "", type: .permission)
            createContext(config: config)
        }
    }

    // MARK: - 统一创建 Context
    internal func createContext(config: AEAIContextConfig) {
        let request = AENetReq(
            post: AEAIServicePath.createContext.rawValue
        )
        AELog("[AEAIContextManager] 请求创建 Context: type=\(config.type.rawValue)")
        sendRequest(request, contextInfo: config.toInfoMap())
    }

    // MARK: - 管理上下文

    public func selectContext(config: AEAIContextConfig) -> Bool {
        var context: AEAIContextInterface?
        contexts.read { dict in
            context = dict[config.ident]
        }
        guard let found = context else { return false }
        currentContext = found
        delegate?.contextManager(self, didChangeCurrentContext: found)
        return true
    }

    public func getCurrentContext() -> AEAIContextInterface? {
        return currentContext
    }

    public func addContext(_ context: AEAIContextInterface) {
        var exists = false
        contexts.read { dict in
            exists = dict[context.ident] != nil
        }

        guard !exists else {
            AELog("[AEAIContextManager] Context 已存在: \(context.ident)")
            return
        }

        contexts.write { dict in
            dict[context.ident] = context
        }

        if context is AEWorkSpaceContext, let delegate = delegate {
            delegate.contextManager(self, didAddContext: context)
        }
    }

    public func getAllContexts() -> [AEAIContextInterface] {
        var result: [AEAIContextInterface] = []
        contexts.read { dict in
            result = Array(dict.values)
        }
        return result
    }

    public func getContext(id: String) -> AEAIContextInterface? {
        var result: AEAIContextInterface?
        contexts.read { dict in
            result = dict[id]
        }
        return result
    }

    // MARK: - 统一发送请求
    internal func sendRequest(_ request: AENetReq, contextInfo: [String: Any]) {
        guard let networkService = networkService else {
            AELog("❌ [AEAIContextManager] 网络服务未初始化")
            return
        }

        var parameters = request.parameters ?? [:]

        // 将 ques 嵌套进 cont 内发送：cont = { type, ident, ..., ques: {...} }
        var cont = contextInfo
        if let ques = parameters.removeValue(forKey: "ques") {
            cont["ques"] = ques
        }
        parameters["cont"] = cont

        if let account = AEModuleCenter.module(for: AEUserAccountModuleProtocol.self) {
            let user = account.toInfoMap()
            if !user.isEmpty { parameters["user"] = user }
        }

        request.parameters = parameters
        networkService.sendRequest(request)
    }

}

// MARK: - AEAIContextDelegate

extension AEAIContextManager: AEAIContextDelegate {

    public func sendRequest(_ request: AENetReq, from context: AEAIContextInterface) {
        sendRequest(request, contextInfo: context.toInfoMap())
        if let contextDelegate = contextDelegate {
            contextDelegate.sendRequest(request, from: context)
        }
    }

    public func didReceiveRsp(_ response: AENetRsp, from context: AEAIContextInterface) {
        if let contextDelegate = contextDelegate {
            contextDelegate.didReceiveRsp(response, from: context)
        }
    }

    public func contextDidFinishInitialization(_ context: AEAIContextInterface) {
        if context is AEDirectoryContext {
            let request = AENetReq(
                post: AEAIServicePath.contextList.rawValue
            )
            sendRequest(request, contextInfo: context.toInfoMap())
        }
    }
}
