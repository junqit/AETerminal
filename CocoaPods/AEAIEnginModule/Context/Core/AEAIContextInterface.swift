//
//  AEAIContextInterface.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AEFoundation
import AENetworkEngine
import AELogProxy

/// Context 配置
public struct AEAIContextConfig: AEInfoProtocol {

    /// Context 类型枚举
    public enum AEAIContextType: String {
        case permission = "Permission"
        case directory = "Directory"
        case workspace = "WorkSpace"
    }

    /// Context 唯一标识
    public let ident: String

    /// 工作空间
    public let space: String

    /// Context 类型
    public let type: AEAIContextType

    /// 初始化配置
    /// - Parameters:
    ///   - ident: 唯一标识
    ///   - space: 工作空间
    ///   - type: Context 类型
    public init(ident: String, space: String, type: AEAIContextType) {
        self.ident = ident
        self.space = space
        self.type = type
    }

    // MARK: - AEInfoProtocol

    /// 实现 AEInfoProtocol 协议
    /// 将配置对象转换为字典映射
    /// - Returns: 包含配置信息的字典
    public func toInfoMap() -> [String: Any] {
        var map: [String: Any] = [:]

        if !ident.isEmpty {
            map["ident"] = ident
        } else {
            AELog("⚠️ [AEAIContextConfig] toInfoMap: ident 为空")
        }

        if !space.isEmpty {
            map["space"] = space
        } else {
            AELog("⚠️ [AEAIContextConfig] toInfoMap: space 为空")
        }

        map["type"] = type.rawValue
        return map
    }
}

/// AI Context 协议
/// 定义所有 Context 必须实现的接口
public protocol AEAIContextInterface: AnyObject, AEInfoProtocol {

    /// Context 配置
    var config: AEAIContextConfig { get }

    /// Context 代理，用于发送请求
    var delegate: AEAIContextDelegate? { get set }

    /// 初始化方法
    /// - Parameter config: Context 配置对象
    init(config: AEAIContextConfig)

    /// 接收用户提交的问题，由 Context 内部处理发送
    /// - Parameter question: AI 问题对象
    func sendQuestion(_ question: AEAIQuestion)

    /// 接收服务端返回的响应
    /// - Parameter response: 网络响应对象
    func receiveRsp(_ response: AENetRsp)

    // MARK: - Question History Navigation

    /// 导航到上一条历史问题
    /// - Returns: 上一条问题对象，如果没有则返回 nil
    func navigateQuestionUp() -> AEAIQuestion?

    /// 导航到下一条历史问题
    /// - Returns: 下一条问题对象，如果没有则返回 nil
    func navigateQuestionDown() -> AEAIQuestion?
}

// MARK: - AEInfoProtocol 默认实现

public extension AEAIContextInterface {

    /// 实现 AEInfoProtocol 协议
    /// 将 Context 对象转换为字典映射
    /// - Returns: 包含 Context 信息的字典
    func toInfoMap() -> [String: Any] {
        return config.toInfoMap()
    }
}

// MARK: - 便利属性默认实现

public extension AEAIContextInterface {

    /// 从配置中获取唯一标识
    var ident: String {
        return config.ident
    }

    /// 从配置中获取工作空间
    var space: String {
        return config.space
    }
}
