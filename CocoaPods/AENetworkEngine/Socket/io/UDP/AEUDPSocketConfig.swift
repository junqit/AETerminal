//
//  AEUDPSocketConfig.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/9.
//

import Foundation

/// UDP Socket 配置
public struct AEUDPSocketConfig {
    /// 服务器地址
    public var serverHost: String

    /// 服务器端口
    public var serverPort: UInt16

    public init(serverHost: String, serverPort: UInt16 = 9999) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }
}

/// UDP 消息类型
public enum AEUDPMessageType: String, Codable {
    case ping = "ping"
    case pong = "pong"
    case chat = "chat"
    case chatResponse = "chat_response"
    case context = "context"
    case contextResponse = "context_response"
    case custom = "custom"
    case customResponse = "custom_response"
    case notification = "notification"      // 推送通知
    case confirmation = "confirmation"      // 确认消息
    case unknown = "unknown"
}

/// UDP 消息状态
public enum AEUDPMessageStatus: String, Codable {
    case success = "success"
    case error = "error"
    case pending = "pending"
}
