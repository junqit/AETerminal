//
//  AEAISocketManager.swift
//  AEAINetworkModule
//
//  Created by Claude on 2026/4/23.
//

import Foundation
import AENetworkEngine

/// AI Socket 管理器 - 使用 AENetworkSocket 进行 UDP 连接
public class AEAISocketManager {

    // MARK: - Properties

    /// Socket 连接实例
    private var socket: AENetworkSocket?

    /// 服务器 IP 地址
    private let serverIP: String

    /// 服务器端口
    private let serverPort: UInt16

    /// 请求路径前缀
    private let path: String

    /// 连接状态变化回调
    public var onConnectionStateChanged: ((AESocketState) -> Void)?

    /// 数据接收回调
    public var onDataReceived: ((Data) -> Void)?

    /// 消息接收回调（解析为字典）
    public var onMessageReceived: (([String: Any]) -> Void)?

    /// 是否已连接
    public var isConnected: Bool {
        if case .connected = socket?.state {
            return true
        }
        return false
    }

    // MARK: - Initialization

    /// 初始化
    /// - Parameters:
    ///   - serverIP: 服务器 IP 地址
    ///   - serverPort: 服务器端口
    ///   - path: 请求路径前缀（默认为空）
    public init(serverIP: String, serverPort: UInt16, path: String = "") {
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.path = path
    }

    // MARK: - Connection Management

    /// 连接到服务器
    /// - Parameter completion: 完成回调
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        // 创建 UDP Socket
        socket = AENetworkSocket(
            ip: serverIP,
            port: serverPort,
            path: path,
            protocolType: .udp
        )

        // 设置状态监听
        socket?.onStateChanged = { [weak self] state in
            self?.handleStateChange(state)
            self?.onConnectionStateChanged?(state)

            // 在状态变化时通知完成回调
            switch state {
            case .connected:
                completion?(true, nil)
            case .failed(let error):
                completion?(false, error)
            default:
                break
            }
        }

        // 设置数据接收监听
        socket?.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
            self?.onDataReceived?(data)
        }

        // 执行连接
        do {
            try socket?.connect()
        } catch {
            completion?(false, error)
        }
    }

    /// 断开连接
    public func disconnect() {
        socket?.disconnect()
        socket = nil
    }

    // MARK: - Send Methods

    /// 发送 AENetReq 请求
    /// - Parameter request: HTTP 请求对象
    /// - Throws: 发送失败时抛出错误
    public func send(_ request: AENetReq) throws {
        guard let socket = socket else {
            throw AESocketError.notConnected
        }

        try socket.send(request)
    }

    /// 发送字典数据
    /// - Parameter data: 要发送的数据字典
    /// - Throws: 发送失败时抛出错误
    public func send(data: [String: Any]) throws {
        guard let socket = socket else {
            throw AESocketError.notConnected
        }

        // 将字典转换为 JSON 数据
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])

        // 发送原始数据
        try socket.send(jsonData)
    }

    /// 发送原始数据
    /// - Parameter data: 要发送的数据
    /// - Throws: 发送失败时抛出错误
    public func send(rawData data: Data) throws {
        guard let socket = socket else {
            throw AESocketError.notConnected
        }

        try socket.send(data)
    }

    // MARK: - Private Methods

    /// 处理状态变化
    private func handleStateChange(_ state: AESocketState) {
        switch state {
        case .disconnected:
            print("[AEAISocketManager] Socket 已断开")
        case .connecting:
            print("[AEAISocketManager] Socket 连接中...")
        case .connected:
            print("[AEAISocketManager] Socket 已连接")
        case .failed(let error):
            print("[AEAISocketManager] Socket 连接失败: \(error)")
        }
    }

    /// 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        // 尝试解析为 JSON 字典
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            print("[AEAISocketManager] 收到消息: \(json)")
            onMessageReceived?(json)
        } else {
            print("[AEAISocketManager] 收到原始数据，大小: \(data.count) 字节")
        }
    }

    // MARK: - Deinit

    deinit {
        disconnect()
    }
}

// MARK: - Convenience Methods

extension AEAISocketManager {

    /// 便利方法：创建并连接
    /// - Parameters:
    ///   - serverIP: 服务器 IP
    ///   - serverPort: 服务器端口
    ///   - path: 请求路径
    ///   - completion: 完成回调
    /// - Returns: Socket 管理器实例
    public static func createAndConnect(
        serverIP: String,
        serverPort: UInt16,
        path: String = "",
        completion: ((Bool, Error?) -> Void)? = nil
    ) -> AEAISocketManager {
        let manager = AEAISocketManager(serverIP: serverIP, serverPort: serverPort, path: path)
        manager.connect(completion: completion)
        return manager
    }

    /// 便利方法：发送 GET 请求
    /// - Parameters:
    ///   - path: 请求路径
    ///   - parameters: 请求参数
    /// - Throws: 发送失败时抛出错误
    public func sendGet(path: String, parameters: [String: Any]? = nil) throws {
        let request = AENetReq(
            get: path,
            parameters: parameters
        )
        try send(request)
    }

    /// 便利方法：发送 POST 请求
    /// - Parameters:
    ///   - path: 请求路径
    ///   - parameters: 请求参数
    ///   - body: 请求体
    /// - Throws: 发送失败时抛出错误
    public func sendPost(path: String, parameters: [String: Any]? = nil, body: Data? = nil) throws {
        let request = AENetReq(
            post: path,
            parameters: parameters,
            body: body
        )
        try send(request)
    }
}
