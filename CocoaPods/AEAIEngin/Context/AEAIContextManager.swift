import Foundation

/// AI 上下文管理器
public class AEAIContextManager {
    /// 存储的上下文列表
    private static var contexts: [String: AEAIContext] = [:]

    /// 状态变化的代理
    public static weak var delegate: AEAIContextManagerDelegate?

    // 防止实例化
    private init() {}

    /// 创建并添加上下文
    /// - Parameter config: 上下文配置对象
    /// - Returns: 如果已存在相同 ID 的上下文则返回现有的，否则返回新创建的
    @discardableResult
    public static func createContext(_ config: AEContextConfig) -> AEAIContext {
        // 创建上下文
        let context = AEAIContext(config: config)

        // 检查是否已存在相同的上下文
        if let existingContext = contexts[context.id] {
            print("警告: 上下文 ID '\(context.id)' 已存在，返回现有上下文")
            return existingContext
        }

        // 添加新的上下文
        contexts[context.id] = context

        // 通知代理
        delegate?.contextManager(self, didAddContext: context)
        notifyContextsChanged()

        return context
    }

    /// 创建并添加上下文（使用自定义 ID）
    /// - Parameters:
    ///   - config: 上下文配置对象
    ///   - customId: 自定义的 Context ID（通常来自云端）
    /// - Returns: 如果已存在相同 ID 的上下文则返回现有的，否则返回新创建的
    @discardableResult
    public static func createContext(_ config: AEContextConfig, withId customId: String) -> AEAIContext {
        // 使用自定义 ID 创建上下文
        let context = AEAIContext(config: config, customId: customId)

        // 检查是否已存在相同的上下文
        if let existingContext = contexts[context.id] {
            print("警告: 上下文 ID '\(context.id)' 已存在，返回现有上下文")
            return existingContext
        }

        // 添加新的上下文
        contexts[context.id] = context

        // 通知代理
        delegate?.contextManager(self, didAddContext: context)
        notifyContextsChanged()

        return context
    }

    // MARK: - 管理上下文

    /// 添加上下文（如果已存在相同 ID 则覆盖）
    /// - Parameter context: 要添加的上下文对象
    public static func addContext(_ context: AEAIContext) {
        let isNew = contexts[context.id] == nil
        contexts[context.id] = context

        // 只有新增时才通知
        if isNew {
            delegate?.contextManager(self, didAddContext: context)
        }
        notifyContextsChanged()
    }

    /// 删除上下文
    /// - Parameter context: 要删除的上下文对象
    public static func removeContext(_ context: AEAIContext) {
        if contexts.removeValue(forKey: context.id) != nil {
            // 通知代理
            delegate?.contextManager(self, didRemoveContext: context)
            notifyContextsChanged()
        }
    }

    /// 获取所有上下文
    /// - Returns: 上下文数组
    public static func getAllContexts() -> [AEAIContext] {
        return Array(contexts.values)
    }

    /// 根据 ID 获取上下文
    /// - Parameter id: 上下文的唯一标识
    /// - Returns: 上下文对象，如果不存在则返回 nil
    public static func getContext(id: String) -> AEAIContext? {
        return contexts[id]
    }

    /// 清空所有上下文
    public static func clearAllContexts() {
        contexts.removeAll()
        notifyContextsChanged()
    }

    // MARK: - Private Helpers

    /// 通知代理上下文列表已更新
    private static func notifyContextsChanged() {
        let allContexts = Array(contexts.values)
        delegate?.contextManager(self, didUpdateContexts: allContexts)
    }
}
