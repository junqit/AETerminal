import Foundation

/// AEAIContextManager 状态变化的代理协议
public protocol AEAIContextManagerDelegate: AnyObject {

    /// 添加了新的 Context
    func contextManager(_ manager: AEAIContextManager, didAddContext context: AEAIContextInterface)

    /// 删除了 Context
    func contextManager(_ manager: AEAIContextManager, didRemoveContext context: AEAIContextInterface)

    /// 当前 Context 发生变更
    func contextManager(_ manager: AEAIContextManager, didChangeCurrentContext context: AEAIContextInterface)
}

public extension AEAIContextManagerDelegate {

    func contextManager(_ manager: AEAIContextManager, didAddContext context: AEAIContextInterface) {}

    func contextManager(_ manager: AEAIContextManager, didRemoveContext context: AEAIContextInterface) {}

    func contextManager(_ manager: AEAIContextManager, didChangeCurrentContext context: AEAIContextInterface) {}
}
