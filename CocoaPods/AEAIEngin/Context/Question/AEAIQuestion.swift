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

    /// 问题类型
    public enum QuestionType: String {
        case text = "text"
        case command = "command"
        case search = "search"
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

    /// 转换为字典
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "content": content,
            "type": type.rawValue
        ]

        if let parameters = parameters {
            dict["parameters"] = parameters
        }

        return dict
    }
}
