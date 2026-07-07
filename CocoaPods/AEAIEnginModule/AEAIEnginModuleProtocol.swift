//
//  AEAIEnginModuleProtocol.swift
//  AEAIEnginModule
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AEModuleCenter

/// AI Engine 模块协议
public protocol AEAIEnginModuleProtocol: AEModuleProtocol, AEAIContextManagerInterface {

    /// 添加代理
    func addDelegate(_ delegate: AEAIEnginModuleDelegate)

    /// 移除代理
    func removeDelegate(_ delegate: AEAIEnginModuleDelegate)

    /// 处理用户提交的问题
    func handleInputCompleted(_ question: AEAIQuestion)
}
