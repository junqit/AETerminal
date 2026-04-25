import Foundation

/// AI 消息管理器 - 管理单个 Context 的消息历史
public class AEAIMessageManager {
    /// 消息列表（按发送顺序）
    private var messages: [AEAIMessage] = []

    /// 当前消息索引（用于上一条/下一条导航）
    private var currentIndex: Int?

    /// 所属的上下文 ID
    public let contextID: String

    /// 消息总数
    public var messageCount: Int {
        return messages.count
    }

    /// 是否有上一条消息
    public var hasPrevious: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }

    /// 是否有下一条消息
    public var hasNext: Bool {
        guard let index = currentIndex else { return false }
        return index < messages.count - 1
    }

    public init(contextID: String) {
        self.contextID = contextID
    }

    // MARK: - 添加消息

    /// 添加新消息（接收 UI 发送的问题）
    /// - Parameter content: 消息内容
    /// - Returns: 创建的消息对象
    /// - Note: 如果存在相同内容的消息，会先删除旧消息再添加新消息到最后
    @discardableResult
    public func addMessage(_ content: String) -> AEAIMessage {
        // 检查是否已存在相同内容的消息
        if let existingIndex = messages.firstIndex(where: { $0.content == content }) {
            // 删除旧消息
            messages.remove(at: existingIndex)

            // 调整当前索引
            if let currentIdx = currentIndex {
                if currentIdx == existingIndex {
                    // 如果删除的是当前消息，重置索引
                    currentIndex = nil
                } else if currentIdx > existingIndex {
                    // 如果当前索引在删除位置之后，需要减1
                    currentIndex = currentIdx - 1
                }
            }
        }

        // 创建并添加新消息到最后
        let message = AEAIMessage(content: content, contextID: contextID)
        messages.append(message)

        // 添加新消息后，设置索引为 count（表示在最新消息之后，没有选中任何历史）
        currentIndex = messages.count

        return message
    }

    // MARK: - 获取消息

    /// 获取所有消息
    /// - Returns: 消息数组
    public func getAllMessages() -> [AEAIMessage] {
        return messages
    }

    /// 获取当前消息
    /// - Returns: 当前消息，如果没有则返回 nil
    public func getCurrentMessage() -> AEAIMessage? {
        guard let index = currentIndex, index < messages.count else {
            return nil
        }
        return messages[index]
    }

    /// 获取上一条消息
    /// - Returns: 上一条消息，如果没有则返回 nil
    /// - Note: currentIndex 范围是 [0, count]，其中 count 表示没有选中任何历史
    public func getPreviousMessage() -> AEAIMessage? {
        guard let index = currentIndex, index > 0 else {
            return nil
        }

        // 往前移动索引
        currentIndex = index - 1
        return messages[currentIndex!]
    }

    /// 获取下一条消息
    /// - Returns: 下一条消息，如果没有则返回 nil（表示清空输入框）
    /// - Note: 当 currentIndex 到达 count 时，返回 nil 表示回到初始状态
    public func getNextMessage() -> AEAIMessage? {
        guard let index = currentIndex, index < messages.count else {
            return nil
        }

        // 往后移动索引
        currentIndex = index + 1

        // 如果到达 count，返回 nil（表示清空输入框）
        if currentIndex == messages.count {
            return nil
        }

        return messages[currentIndex!]
    }

    /// 根据 ID 获取消息
    /// - Parameter id: 消息 ID
    /// - Returns: 消息对象，如果不存在则返回 nil
    public func getMessage(id: String) -> AEAIMessage? {
        return messages.first { $0.id == id }
    }

    /// 获取指定索引的消息
    /// - Parameter index: 消息索引
    /// - Returns: 消息对象，如果索引无效则返回 nil
    public func getMessage(at index: Int) -> AEAIMessage? {
        guard index >= 0 && index < messages.count else {
            return nil
        }
        return messages[index]
    }

    // MARK: - 导航控制

    /// 重置当前索引到最新消息（设为 count，表示在最新消息之后）
    public func resetToLatest() {
        currentIndex = messages.count
    }

    /// 重置当前索引到最早消息
    public func resetToFirst() {
        currentIndex = messages.isEmpty ? nil : 0
    }

    /// 设置当前索引
    /// - Parameter index: 目标索引
    /// - Returns: 是否设置成功
    @discardableResult
    public func setCurrentIndex(_ index: Int) -> Bool {
        guard index >= 0 && index < messages.count else {
            return false
        }
        currentIndex = index
        return true
    }

    // MARK: - 清除消息

    /// 清除所有消息
    public func clearAllMessages() {
        messages.removeAll()
        currentIndex = nil
    }

    /// 删除指定消息
    /// - Parameter id: 消息 ID
    /// - Returns: 是否删除成功
    @discardableResult
    public func removeMessage(id: String) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return false
        }
        messages.remove(at: index)

        // 调整当前索引
        if let currentIdx = currentIndex {
            if currentIdx >= messages.count {
                currentIndex = messages.isEmpty ? nil : messages.count - 1
            }
        }

        return true
    }
}
