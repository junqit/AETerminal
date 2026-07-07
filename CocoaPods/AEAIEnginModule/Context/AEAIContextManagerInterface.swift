//
//  AEAIContextManagerInterface.swift
//  AEAIEnginModule
//
//  Created by Claude on 2026/5/6.
//

import Foundation

/// AI Context 管理器接口协议
public protocol AEAIContextManagerInterface: AnyObject {

    /// 创建 Context
    /// - Parameter config: Context 配置对象（包含类型信息）
    func createContext(config: AEAIContextConfig)

    /// 选中当前目标 Context
    /// - Parameter config: Context 配置对象
    /// - Returns: 是否选中成功
    func selectContext(config: AEAIContextConfig) -> Bool

    /// 获取当前选中的 Context
    /// - Returns: 当前选中的 Context（如果没有则返回 nil）
    func getCurrentContext() -> AEAIContextInterface?
}
