//
//  AENetworkMessageListener.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AENetworkEngine

/// 网络消息监听器协议
public protocol AENetworkMessageListener: AnyObject {
    /// 接收到消息
    /// - Parameter response: 网络响应对象
    func didReceiveMessage(_ response: AENetRsp)
}
