//
//  AEAIEnginModuleDelegate.swift
//  AEAIEnginModule
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AENetworkEngine

/// AI Engine 模块代理协议
public protocol AEAIEnginModuleDelegate: AnyObject {

    /// 即将发送请求
    func enginModule(_ module: AEAIEnginModuleProtocol, willSendRequest request: AENetReq, from context: AEAIContextInterface)

    /// 收到服务端响应
    func enginModule(_ module: AEAIEnginModuleProtocol, didReceiveRsp response: AENetRsp, from context: AEAIContextInterface)

    /// 添加了新的 Context
    func enginModule(_ module: AEAIEnginModuleProtocol, didAddContext context: AEAIContextInterface)

    /// 删除了 Context
    func enginModule(_ module: AEAIEnginModuleProtocol, didRemoveContext context: AEAIContextInterface)

    /// 当前 Context 发生变更
    func enginModule(_ module: AEAIEnginModuleProtocol, didChangeCurrentContext context: AEAIContextInterface)
}

public extension AEAIEnginModuleDelegate {

    func enginModule(_ module: AEAIEnginModuleProtocol, willSendRequest request: AENetReq, from context: AEAIContextInterface) {}

    func enginModule(_ module: AEAIEnginModuleProtocol, didReceiveRsp response: AENetRsp, from context: AEAIContextInterface) {}

    func enginModule(_ module: AEAIEnginModuleProtocol, didAddContext context: AEAIContextInterface) {}

    func enginModule(_ module: AEAIEnginModuleProtocol, didRemoveContext context: AEAIContextInterface) {}

    func enginModule(_ module: AEAIEnginModuleProtocol, didChangeCurrentContext context: AEAIContextInterface) {}
}
