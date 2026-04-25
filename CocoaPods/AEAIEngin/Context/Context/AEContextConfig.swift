//
//  AEContextConfig.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation

/// AI 上下文配置
public class AEContextConfig {
    /// 上下文目录
    public let dir: String

    /// 向后兼容：content 属性（已废弃）
    @available(*, deprecated, renamed: "dir")
    public var content: String { dir }

    /// 最大消息数量（可选）
    public let maxMessageCount: Int?

    /// 上下文元数据（可选）
    public let metadata: [String: Any]?

    /// 初始化配置
    /// - Parameters:
    ///   - content: 上下文目录路径
    ///   - maxMessageCount: 最大消息数量，默认为 nil（无限制）
    ///   - metadata: 上下文元数据，默认为 nil
    public init(
        content: String,
        maxMessageCount: Int? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.dir = content
        self.maxMessageCount = maxMessageCount
        self.metadata = metadata
    }
}
