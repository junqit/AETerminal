//
//  AENetConfig.swift
//  AENetworkEngine
//
//  Created on 2026/04/25.
//

import Foundation

/// 网络类型
public enum AENetworkType {
    case http
    case socket
}

/// 网络配置
public struct AENetConfig {
    /// 网络类型
    public var type: AENetworkType

    /// 服务器 IP 地址
    public var ip: String

    /// 服务器主机名
    public var host: String

    /// 服务器端口
    public var port: UInt16

    /// 初始化（完整参数）
    public init(type: AENetworkType, ip: String = "", host: String, port: UInt16) {
        self.type = type
        self.ip = ip
        self.host = host
        self.port = port
    }

    /// 初始化（向后兼容，默认 HTTP）
    public init(ip: String = "", host: String, port: UInt16) {
        self.type = .http
        self.ip = ip
        self.host = host
        self.port = port
    }
}
