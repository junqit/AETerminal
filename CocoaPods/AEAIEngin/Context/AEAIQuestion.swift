//
//  AEAIQuestion.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation

/// AI 问题数据包装
public class AEAIQuestion {
    /// 问题内容
    public let content: String

    /// 问题类型（可选）
    public let type: QuestionType

    /// 附加参数（可选）
    public let parameters: [String: Any]?

    /// 时间戳
    public let timestamp: Date

    /// 问题类型
    public enum QuestionType {
        case text       // 纯文本问题
        case command    // 命令类问题
        case search     // 搜索类问题
        case custom(String)  // 自定义类型
    }

    /// 初始化问题
    /// - Parameters:
    ///   - content: 问题内容
    ///   - type: 问题类型，默认为 .text
    ///   - parameters: 附加参数，默认为 nil
    public init(
        content: String,
        type: QuestionType = .text,
        parameters: [String: Any]? = nil
    ) {
        self.content = content
        self.type = type
        self.parameters = parameters
        self.timestamp = Date()
    }

    /// 便捷方法：创建文本问题
    /// - Parameter content: 问题内容
    /// - Returns: 文本问题实例
    public static func text(_ content: String) -> AEAIQuestion {
        return AEAIQuestion(content: content, type: .text)
    }

    /// 便捷方法：创建命令问题
    /// - Parameter content: 命令内容
    /// - Returns: 命令问题实例
    public static func command(_ content: String) -> AEAIQuestion {
        return AEAIQuestion(content: content, type: .command)
    }

    /// 便捷方法：创建搜索问题
    /// - Parameter content: 搜索内容
    /// - Returns: 搜索问题实例
    public static func search(_ content: String) -> AEAIQuestion {
        return AEAIQuestion(content: content, type: .search)
    }
}
