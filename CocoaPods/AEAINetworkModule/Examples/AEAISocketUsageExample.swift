//
//  AEAISocketUsageExample.swift
//  AEAINetworkModule
//
//  Created by Claude on 2026/4/23.
//

import Foundation
import AENetworkEngine

/**
 AEAISocketManager 使用示例

 演示如何在 AEAINetworkModule 中使用 AENetSocket 进行 UDP 连接
 */

// MARK: - 基础使用示例

func exampleBasicUDPConnection() {
    // 创建 Socket 管理器
    let socketManager = AEAISocketManager(
        serverIP: "192.168.1.100",
        serverPort: 9999,
        path: ""
    )

    // 设置消息接收回调
    socketManager.onMessageReceived = { message in
        print("收到服务器消息: \(message)")
    }

    // 连接到服务器
    socketManager.connect { success, error in
        if success {
            print("UDP 连接成功")

            // 发送数据
            do {
                try socketManager.send(data: [
                    "type": "greeting",
                    "message": "Hello Server",
                    "timestamp": Date().timeIntervalSince1970
                ])
                print("数据已发送")
            } catch {
                print("发送失败: \(error)")
            }
        } else {
            print("UDP 连接失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
}

// MARK: - 发送 AENetReq 示例

func exampleSendHttpRequest() {
    let socketManager = AEAISocketManager(
        serverIP: "10.0.0.50",
        serverPort: 8080
    )

    socketManager.connect { success, _ in
        guard success else { return }

        do {
            // 创建 GET 请求
            let getRequest = AENetReq(
                get: "/api/status",
                parameters: ["device_id": "12345"],
                headers: ["Authorization": "Bearer token123"]
            )

            // 发送请求（会被组装成 map 格式）
            try socketManager.send(getRequest)

            // 或使用便利方法
            try socketManager.sendGet(
                path: "/api/status",
                parameters: ["device_id": "12345"]
            )

        } catch {
            print("发送请求失败: \(error)")
        }
    }
}

// MARK: - 发送 POST 请求示例

func exampleSendPostRequest() {
    let socketManager = AEAISocketManager(
        serverIP: "api.example.com",
        serverPort: 9090
    )

    socketManager.connect { success, _ in
        guard success else { return }

        do {
            // 准备 POST 数据
            let userData = [
                "username": "testuser",
                "email": "test@example.com"
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: userData)

            // 创建 POST 请求
            let postRequest = AENetReq(
                post: "/api/users",
                parameters: nil,
                headers: ["Content-Type": "application/json"],
                body: bodyData
            )

            // 发送请求
            try socketManager.send(postRequest)

            // 或使用便利方法
            try socketManager.sendPost(
                path: "/api/users",
                body: bodyData
            )

        } catch {
            print("发送 POST 请求失败: \(error)")
        }
    }
}

// MARK: - 状态监听示例

func exampleStateMonitoring() {
    let socketManager = AEAISocketManager(
        serverIP: "192.168.1.100",
        serverPort: 9999
    )

    // 监听连接状态变化
    socketManager.onConnectionStateChanged = { state in
        switch state {
        case .disconnected:
            print("状态: 已断开")
        case .connecting:
            print("状态: 连接中...")
        case .connected:
            print("状态: 已连接")
        case .failed(let error):
            print("状态: 连接失败 - \(error)")
        }
    }

    // 监听原始数据
    socketManager.onDataReceived = { data in
        print("收到原始数据: \(data.count) 字节")
    }

    // 监听解析后的消息
    socketManager.onMessageReceived = { message in
        print("收到解析消息: \(message)")

        // 处理不同类型的消息
        if let type = message["type"] as? String {
            switch type {
            case "notification":
                handleNotification(message)
            case "response":
                handleResponse(message)
            default:
                print("未知消息类型: \(type)")
            }
        }
    }

    socketManager.connect()
}

// MARK: - 集成到 AEAINetworkModule 示例

class AEAINetworkModuleWithSocket {

    /// Socket 管理器
    private var socketManager: AEAISocketManager?

    /// 配置并连接 Socket
    func configure(serverIP: String, serverPort: UInt16) {
        socketManager = AEAISocketManager(
            serverIP: serverIP,
            serverPort: serverPort
        )

        // 设置回调
        socketManager?.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }

        // 连接
        socketManager?.connect { success, error in
            if success {
                print("✅ Socket 连接成功")
            } else {
                print("❌ Socket 连接失败: \(error?.localizedDescription ?? "")")
            }
        }
    }

    /// 发送数据
    func sendData(_ data: [String: Any]) {
        do {
            try socketManager?.send(data: data)
        } catch {
            print("发送数据失败: \(error)")
        }
    }

    /// 处理接收到的消息
    private func handleIncomingMessage(_ message: [String: Any]) {
        print("处理消息: \(message)")

        // 在这里实现具体的消息处理逻辑
        // 例如：通知监听者、更新状态等
    }

    /// 断开连接
    func disconnect() {
        socketManager?.disconnect()
        socketManager = nil
    }
}

// MARK: - 便利方法使用示例

func exampleConvenienceMethod() {
    // 一行代码创建并连接
    let socketManager = AEAISocketManager.createAndConnect(
        serverIP: "192.168.1.100",
        serverPort: 9999
    ) { success, error in
        if success {
            print("连接成功")
        } else {
            print("连接失败: \(error?.localizedDescription ?? "")")
        }
    }

    // 设置回调
    socketManager.onMessageReceived = { message in
        print("收到消息: \(message)")
    }
}

// MARK: - 辅助方法

private func handleNotification(_ message: [String: Any]) {
    print("处理通知消息: \(message)")
}

private func handleResponse(_ message: [String: Any]) {
    print("处理响应消息: \(message)")
}

// MARK: - 实际应用场景示例

/// AI 服务通信管理器
class AIServiceCommunicator {

    private let socketManager: AEAISocketManager

    init(serverIP: String, serverPort: UInt16) {
        self.socketManager = AEAISocketManager(
            serverIP: serverIP,
            serverPort: serverPort
        )

        setupCallbacks()
    }

    private func setupCallbacks() {
        socketManager.onMessageReceived = { [weak self] message in
            self?.processAIResponse(message)
        }
    }

    func connect(completion: @escaping (Bool) -> Void) {
        socketManager.connect { success, _ in
            completion(success)
        }
    }

    /// 发送 AI 查询请求
    func sendQuery(text: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let queryData: [String: Any] = [
            "type": "query",
            "text": text,
            "timestamp": Date().timeIntervalSince1970,
            "request_id": UUID().uuidString
        ]

        do {
            try socketManager.send(data: queryData)
        } catch {
            completion(.failure(error))
        }
    }

    /// 处理 AI 响应
    private func processAIResponse(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "query_response":
            print("收到 AI 查询响应")
        case "error":
            print("收到错误消息: \(message)")
        default:
            print("未知消息类型: \(type)")
        }
    }
}
