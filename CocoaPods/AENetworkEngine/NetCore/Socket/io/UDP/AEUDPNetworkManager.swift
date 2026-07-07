//
//  AEUDPNetworkManager.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/9.
//

import Foundation

/// UDP 网络管理器 - 业务层友好的 API
public class AEUDPNetworkManager {

    // MARK: - Properties

    /// UDP 客户端
    private var client: AEUDPSocketClient?

    /// 配置
    private var config: AEUDPSocketConfig?

    /// 推送消息类型回调字典 [messageType: [callbacks]]
    private var pushMessageCallbacks: [String: [(([String: Any]) -> Void)]] = [:]
    private let callbackLock = NSLock()

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Configuration

    /// 配置网络管理器
    /// - Parameter config: UDP 配置
    public func configure(config: AEUDPSocketConfig) {
        self.config = config
        self.client = AEUDPSocketClient(config: config)

        // 设置推送消息处理器
        self.client?.pushMessageHandler = { [weak self] message in
            self?.handlePushMessage(message)
        }
    }

    /// 获取配置
    public func getConfig() -> AEUDPSocketConfig? {
        return config
    }

    // MARK: - Connection Management

    /// 连接到服务器
    /// - Parameter completion: 完成回调
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let client = client else {
            let error = NSError(domain: "AEUDPNetworkManager",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "未配置管理器，请先调用 configure()"])
            completion?(false, error)
            return
        }

        client.connect(completion: completion)
    }

    /// 断开连接
    public func disconnect() {
        client?.disconnect()
    }

    /// 是否已连接
    public var isConnected: Bool {
        return client?.isConnected ?? false
    }

    // MARK: - Request-Response Methods

    /// 发送消息并等待响应
    /// - Parameters:
    ///   - type: 消息类型
    ///   - data: 消息数据
    ///   - completion: 完成回调
    public func sendMessage(type: String,
                           data: [String: Any] = [:],
                           completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let client = client else {
            let error = NSError(domain: "AEUDPNetworkManager",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
            completion(nil, error)
            return
        }

        var messageData = data
        messageData["type"] = type

        client.send(data: messageData, completion: completion)
    }

    /// Ping 服务器
    /// - Parameter completion: 完成回调
    public func pingServer(completion: @escaping (Bool) -> Void) {
        guard let client = client else {
            completion(false)
            return
        }

        client.ping { success, _ in
            completion(success)
        }
    }

    /// 发送聊天消息
    /// - Parameters:
    ///   - message: 消息内容
    ///   - contextId: 上下文 ID
    ///   - completion: 完成回调
    public func sendChatMessage(message: String,
                               contextId: String? = nil,
                               completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let client = client else {
            let error = NSError(domain: "AEUDPNetworkManager",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
            completion(nil, error)
            return
        }

        client.sendChat(message: message, contextId: contextId, completion: completion)
    }

    /// 发送自定义消息
    /// - Parameters:
    ///   - data: 自定义数据
    ///   - completion: 完成回调
    public func sendCustomMessage(data: [String: Any],
                                  completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let client = client else {
            let error = NSError(domain: "AEUDPNetworkManager",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
            completion(nil, error)
            return
        }

        client.sendCustom(data: data, completion: completion)
    }

    // MARK: - Push Message Handling

    /// 注册推送消息回调
    /// - Parameters:
    ///   - messageType: 消息类型（使用 "*" 表示所有类型）
    ///   - callback: 回调函数
    public func registerPushMessageCallback(for messageType: String, callback: @escaping ([String: Any]) -> Void) {
        callbackLock.lock()
        defer { callbackLock.unlock() }

        if pushMessageCallbacks[messageType] == nil {
            pushMessageCallbacks[messageType] = []
        }
        pushMessageCallbacks[messageType]?.append(callback)
    }

    /// 取消注册推送消息回调
    /// - Parameter messageType: 消息类型
    public func unregisterPushMessageCallbacks(for messageType: String) {
        callbackLock.lock()
        defer { callbackLock.unlock() }

        pushMessageCallbacks[messageType] = nil
    }

    /// 清除所有推送消息回调
    public func clearAllPushMessageCallbacks() {
        callbackLock.lock()
        defer { callbackLock.unlock() }

        pushMessageCallbacks.removeAll()
    }

    // MARK: - Private Methods

    /// 处理推送消息
    private func handlePushMessage(_ message: [String: Any]) {
        let messageType = message["type"] as? String ?? "unknown"

        callbackLock.lock()
        let typeCallbacks = pushMessageCallbacks[messageType] ?? []
        let globalCallbacks = pushMessageCallbacks["*"] ?? []
        callbackLock.unlock()

        // 调用特定类型的回调
        for callback in typeCallbacks {
            callback(message)
        }

        // 调用通用回调
        for callback in globalCallbacks {
            callback(message)
        }
    }
}

// MARK: - Convenience Methods

extension AEUDPNetworkManager {

    /// 请求接口（类似 HTTP 请求的风格）
    /// - Parameters:
    ///   - endpoint: 端点/类型
    ///   - data: 数据
    ///   - timeout: 超时时间（暂未实现）
    ///   - completion: 完成回调
    public func request(endpoint: String,
                       data: [String: Any] = [:],
                       timeout: TimeInterval? = nil,
                       completion: @escaping ([String: Any]?, Error?) -> Void) {
        sendMessage(type: endpoint, data: data, completion: completion)
    }

    /// 批量发送消息
    /// - Parameters:
    ///   - messages: 消息数组 [(type, data)]
    ///   - completion: 完成回调（返回所有响应）
    public func batchSend(messages: [(String, [String: Any])],
                         completion: @escaping ([[String: Any]?], [Error?]) -> Void) {
        var responses: [[String: Any]?] = []
        var errors: [Error?] = []
        let group = DispatchGroup()

        for (type, data) in messages {
            group.enter()
            sendMessage(type: type, data: data) { response, error in
                responses.append(response)
                errors.append(error)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(responses, errors)
        }
    }
}

// MARK: - Async/Await Support

@available(iOS 13.0, macOS 10.15, *)
extension AEUDPNetworkManager {

    /// 连接到服务器（async/await）
    public func connect() async throws {
        guard let client = client else {
            throw NSError(domain: "AEUDPNetworkManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
        }

        try await client.connect()
    }

    /// 发送消息并等待响应（async/await）
    public func sendMessage(type: String, data: [String: Any] = [:]) async throws -> [String: Any] {
        guard let client = client else {
            throw NSError(domain: "AEUDPNetworkManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
        }

        var messageData = data
        messageData["type"] = type

        return try await client.send(data: messageData)
    }

    /// Ping 服务器（async/await）
    public func pingServer() async throws -> Bool {
        guard let client = client else {
            return false
        }

        return try await client.ping()
    }

    /// 发送聊天消息（async/await）
    public func sendChatMessage(message: String, contextId: String? = nil) async throws -> [String: Any] {
        guard let client = client else {
            throw NSError(domain: "AEUDPNetworkManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未配置管理器"])
        }

        return try await client.sendChat(message: message, contextId: contextId)
    }
}
