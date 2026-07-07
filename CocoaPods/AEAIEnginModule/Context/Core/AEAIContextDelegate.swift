//
//  AEAIContextDelegate.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AENetworkEngine

/// AI Context 代理协议
/// 用于 Context 通过代理发送问题请求和接收回答
public protocol AEAIContextDelegate: AnyObject {

    /// 发送网络请求（统一入口，所有 Context 请求都通过此方法）
    func sendRequest(_ request: AENetReq, from context: AEAIContextInterface)

    /// 接收服务端响应
    func didReceiveRsp(_ response: AENetRsp, from context: AEAIContextInterface)

    /// Context 初始化完成回调
    func contextDidFinishInitialization(_ context: AEAIContextInterface)
}

public extension AEAIContextDelegate {

    func sendRequest(_ request: AENetReq, from context: AEAIContextInterface) {}

    func didReceiveRsp(_ response: AENetRsp, from context: AEAIContextInterface) {}

    func contextDidFinishInitialization(_ context: AEAIContextInterface) {}
}

/// Context 生命周期代理协议
/// 用于 ContextManager 内部监听 Context 初始化完成事件
public protocol AEAIContextLifecycleDelegate: AnyObject {

    func contextDidFinishInitialization(_ context: AEAIContextInterface)
}

public extension AEAIContextLifecycleDelegate {

    func contextDidFinishInitialization(_ context: AEAIContextInterface) {}
}
