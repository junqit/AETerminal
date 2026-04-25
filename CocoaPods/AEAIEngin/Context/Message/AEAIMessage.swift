import Foundation

/// AI 消息模型
public struct AEAIMessage {
    /// 消息唯一标识
    public let id: String

    /// 消息内容
    public let content: String

    /// 创建时间
    public let timestamp: Date

    /// 所属的上下文 ID
    public let contextID: String

    public init(content: String, contextID: String) {
        self.id = UUID().uuidString
        self.content = content
        self.timestamp = Date()
        self.contextID = contextID
    }
}

// MARK: - Equatable
extension AEAIMessage: Equatable {
    public static func == (lhs: AEAIMessage, rhs: AEAIMessage) -> Bool {
        return lhs.id == rhs.id
    }
}
