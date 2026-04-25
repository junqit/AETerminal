//
//  AENetworkMessageListener.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation

/// 网络消息监听器协议
public protocol AENetworkMessageListener: AnyObject {
    /// 接收到消息
    /// - Parameter message: 反序列化后的消息字典
    func didReceiveMessage(_ message: [String: Any])
}

/// 网络发送结果
public enum AENetworkSendResult {
    case success
    case failure(Error)
}
