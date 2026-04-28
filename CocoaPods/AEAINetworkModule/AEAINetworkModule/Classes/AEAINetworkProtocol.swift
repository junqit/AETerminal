//
//  AEAINetworkProtocol.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AEModuleCenter
import AENetworkEngine

/// AEAI 网络能力协议
public protocol AEAINetworkProtocol: AEModuleProtocol {

    /// 配置网络参数
    /// - Parameter config: 网络配置
    func configure(with config: AENetConfig)

    /// 发送请求并返回响应
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - completion: 完成回调，返回响应对象（默认为空）
    func sendRequest(_ request: AENetReq, completion: ((AENetRsp) -> Void)?)

    /// 注册消息监听者
    func addListener(_ listener: AENetworkMessageListener)

    /// 移除消息监听者
    func removeListener(_ listener: AENetworkMessageListener)
}

