//
//  AEAISocketConfig.swift
//  AENetworkEngine
//
//  Created on 2026/04/15.
//

import Foundation

/// Socket 配置
public struct AEAISocketConfig {
    /// 服务器 IP
    public var serverIP: String

    /// 服务器端口
    public var serverPort: UInt16

    /// 请求路径前缀
    public var path: String

    /// 协议类型（默认 UDP）
    public var protocolType: AESocketProtocol

    public init(
        serverIP: String,
        serverPort: UInt16,
        path: String = "",
        protocolType: AESocketProtocol = .udp
    ) {
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.path = path
        self.protocolType = protocolType
    }
}
