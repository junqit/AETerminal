//
//  AEAIQuestion.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/7.
//

import Foundation
import AEFoundation
import AELogProxy

/// 问题类型（数值定义，节省流量）
public enum AEAIQuestionType: Int {
    case text = 0
    case command = 1
    case search = 2
}

/// AI 问题数据包装
public class AEAIQuestion: AEInfoProtocol {
    /// 问题唯一标识
    public let ident: String

    /// 问题内容
    public let content: String

    /// 问题类型
    public let type: AEAIQuestionType

    /// 附加参数（可选）
    public let parameters: [String: Any]?

    public init(
        ident: String = UUID().uuidString,
        content: String,
        type: AEAIQuestionType = .text,
        parameters: [String: Any]? = nil
    ) {
        self.ident = ident
        self.content = content
        self.type = type
        self.parameters = parameters
    }

    // MARK: - JSON -> Model

    public static func fromJSON(_ json: [String: Any]) -> AEAIQuestion? {
        guard let content = json["content"] as? String else {
            return nil
        }

        let ident = json["ident"] as? String ?? UUID().uuidString
        let typeValue = json["type"] as? Int ?? 0
        let type = AEAIQuestionType(rawValue: typeValue) ?? .text
        let parameters = json["parameters"] as? [String: Any]

        return AEAIQuestion(
            ident: ident,
            content: content,
            type: type,
            parameters: parameters
        )
    }

    // MARK: - AEInfoProtocol

    public func toInfoMap() -> [String: Any] {
        var dict: [String: Any] = [:]

        if !ident.isEmpty {
            dict["ident"] = ident
        } else {
            AELog("⚠️ [AEAIQuestion] toInfoMap: ident 为空")
        }

        if !content.isEmpty {
            dict["content"] = content
        } else {
            AELog("⚠️ [AEAIQuestion] toInfoMap: content 为空")
        }

        dict["type"] = type.rawValue

        if let parameters = parameters {
            dict["parameters"] = parameters
        }

        return dict
    }
}
