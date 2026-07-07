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

    /// 发送请求，响应通过 request.onStreamReceived / request.onCompleted 回调
    /// - Parameter request: 网络请求对象
    func sendRequest(_ request: AENetReq)

    /// 注册消息监听者
    func addListener(_ listener: AENetworkMessageListener)

    /// 移除消息监听者
    func removeListener(_ listener: AENetworkMessageListener)
}

