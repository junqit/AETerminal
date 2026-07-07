import Foundation
import AELogProxy

/// AEAIContextManager 扩展 - Context 的创建与删除
extension AEAIContextManager {

    // MARK: - 创建 Context

    /// 创建本地 Context
    public func createLocalContext(config: AEAIContextConfig) -> AEAIContextInterface? {

        let context: AEContext
        switch config.type {
        case .permission:
            context = AEPermissionContext(config: config)
        case .directory:
            context = AEDirectoryContext(config: config)
        case .workspace:
            context = AEWorkSpaceContext(config: config)
        }

        context.delegate = self
        addContext(context)
        DispatchQueue.global().async {
            context.onInitialize()
        }

        if config.type == .workspace {
            _ = selectContext(config: config)
        }

        return context
    }

    // MARK: - 删除 Context

    /// 删除上下文
    public func removeContext(_ context: AEAIContextInterface) {
        var removed = false
        contexts.write { dict in
            if dict.removeValue(forKey: context.ident) != nil {
                removed = true
            }
        }

        if removed {
            if currentContext?.ident == context.ident {
                currentContext = nil
            }
            if let delegate = delegate {
                delegate.contextManager(self, didRemoveContext: context)
            }
        }
    }

    /// 发送删除上下文请求到服务端并移除本地
    public func deleteContext(config: AEAIContextConfig) {

        var context: AEAIContextInterface?
        contexts.read { dict in
            context = dict[config.ident]
        }

        if let context = context {
            removeContext(context)
        }
    }

    /// 清空所有上下文
    public func clearAllContexts() {
        contexts.write { dict in
            dict.removeAll()
        }
        currentContext = nil
            }
}
