//
//  AEAIAnswer.swift
//  AEAIEngin
//
//  Created by Claude on 2026/5/9.
//

import Foundation
import AEFoundation
import AELogProxy

/// 回答状态（数值类型，节省流量）
public enum AEAIAnswerStatus: Int {
    case streaming = 0
    case completed = 1
    case error = 2
}

/// AI 回答数据包装
public class AEAIAnswer: AEInfoProtocol {

    /// 对应的问题（确认是哪个问题的回答）
    public let question: AEAIQuestion

    /// 回答内容
    public let content: String

    /// 回答状态
    public let status: AEAIAnswerStatus

    /// 附加数据（可选）
    public let metadata: [String: Any]?

    public init(
        question: AEAIQuestion,
        content: String,
        status: AEAIAnswerStatus = .completed,
        metadata: [String: Any]? = nil
    ) {
        self.question = question
        self.content = content
        self.status = status
        self.metadata = metadata
    }

    // MARK: - JSON -> Model

    public static func fromJSON(_ json: [String: Any]) -> AEAIAnswer? {
        
        guard let questionJSON = json["question"] as? [String: Any],
              let question = AEAIQuestion.fromJSON(questionJSON),
              let content = json["content"] as? String else {
            return nil
        }

        let statusValue = json["status"] as? Int ?? 1
        let status = AEAIAnswerStatus(rawValue: statusValue) ?? .completed
        let metadata = json["metadata"] as? [String: Any]

        return AEAIAnswer(
            question: question,
            content: content,
            status: status,
            metadata: metadata
        )
    }

    // MARK: - AEInfoProtocol

    public func toInfoMap() -> [String: Any] {
        var dict: [String: Any] = [:]

        let questionMap = question.toInfoMap()
        if !questionMap.isEmpty {
            dict["question"] = questionMap
        } else {
            AELog("⚠️ [AEAIAnswer] toInfoMap: question 为空")
        }

        if !content.isEmpty {
            dict["content"] = content
        } else {
            AELog("⚠️ [AEAIAnswer] toInfoMap: content 为空")
        }

        dict["status"] = status.rawValue

        if let metadata = metadata {
            dict["metadata"] = metadata
        }

        return dict
    }
}
