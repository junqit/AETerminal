//
//  AENetConfig.swift
//  AENetworkEngine
//
//  Created on 2026/04/25.
//

import Foundation

/// 网络配置
public struct AENetConfig {
    /// 服务器 IP 地址
    public var ip: String

    /// 服务器主机名
    public var host: String

    /// 服务器端口
    public var port: UInt16

    public init(ip: String = "", host: String, port: UInt16) {
        self.ip = ip
        self.host = host
        self.port = port
    }
}
