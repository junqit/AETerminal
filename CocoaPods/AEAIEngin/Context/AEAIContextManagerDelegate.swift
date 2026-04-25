import Foundation

/// AEAIContextManager 状态变化的代理协议
public protocol AEAIContextManagerDelegate: AnyObject {

    /// Context 列表发生变化时调用
    /// - Parameters:
    ///   - manager: 上下文管理器类型
    ///   - contexts: 当前所有的上下文列表
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext])

    /// 添加了新的 Context
    /// - Parameters:
    ///   - manager: 上下文管理器类型
    ///   - context: 新添加的上下文
    func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext)

    /// 删除了 Context
    /// - Parameters:
    ///   - manager: 上下文管理器类型
    ///   - context: 被删除的上下文
    func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext)
}

// MARK: - 可选实现的扩展

public extension AEAIContextManagerDelegate {

    /// 提供默认实现，子类可选择性实现
    func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext) {
        // 默认不做处理
    }

    /// 提供默认实现，子类可选择性实现
    func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext) {
        // 默认不做处理
    }
}
