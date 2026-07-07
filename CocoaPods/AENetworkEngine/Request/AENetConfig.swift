//
//  AENetConfig.swift
//  AENetworkEngine
//
//  Created on 2026/04/25.
//

import Foundation

/// 网络类型
public enum AENetworkType: Hashable {
    case http
    case socket
}

/// Socket 协议类型
public enum AENetSocketType: Hashable {
    case tcp
    case udp
}

/// 网络配置
public struct AENetConfig: Hashable {
    /// 网络类型
    public var type: AENetworkType


    /// 服务器 IP 地址
    public var ip: String

    /// 服务器主机名
    public var host: String

    /// 服务器端口
    public var port: UInt16

    /// Socket 协议类型（仅对 socket 类型有效，默认 UDP）
    public var socketType: AENetSocketType

    /// 请求路径前缀（仅对 socket 类型有效）
    public var path: String

    /// 初始化（完整参数）
    public init(
        type: AENetworkType,
        ip: String = "",
        host: String,
        port: UInt16,
        socketType: AENetSocketType = .udp,
        path: String = ""
    ) {
        self.type = type
        self.ip = ip
        self.host = host
        self.port = port
        self.socketType = socketType
        self.path = path
    }

    /// 初始化（向后兼容，默认 HTTP）
    public init(ip: String = "", host: String, port: UInt16) {
        self.type = .http
        self.ip = ip
        self.host = host
        self.port = port
        self.socketType = .udp
        self.path = ""
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(ip)
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(socketType)
        hasher.combine(path)
    }

    public static func == (lhs: AENetConfig, rhs: AENetConfig) -> Bool {
        return lhs.type == rhs.type &&
               lhs.ip == rhs.ip &&
               lhs.host == rhs.host &&
               lhs.port == rhs.port &&
               lhs.socketType == rhs.socketType &&
               lhs.path == rhs.path
    }
}
