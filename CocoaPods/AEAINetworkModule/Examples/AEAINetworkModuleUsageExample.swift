//
//  AEAINetworkModuleUsageExample.swift
//  AEAINetworkModule
//
//  Created by Claude on 2026/4/24.
//

import Foundation
import AENetworkEngine

/**
 AEAINetworkModule 使用示例（基于 AENetSocket）

 演示如何使用 AEAINetworkModule 进行网络连接和数据发送
 */

// MARK: - 基础使用示例

func exampleBasicUsage() {
    // 创建网络模块实例
    let networkModule = AEAINetworkModule()

    // 配置网络参数
    networkModule.configure(
        serverIP: "192.168.1.100",
        serverPort: 9999,
        protocolType: .udp  // 使用 UDP 协议
    )

    // 手动连接（如果不使用 AEModuleCenter 自动初始化）
    networkModule.connect { success, error in
        if success {
            print("✅ 网络连接成功")

            // 发送字典数据
            do {
                try networkModule.send(data: [
                    "type": "greeting",
                    "message": "Hello Server",
                    "timestamp": Date().timeIntervalSince1970
                ])
                print("✅ 数据发送成功")
            } catch {
                print("❌ 数据发送失败: \(error)")
            }
        } else {
            print("❌ 网络连接失败: \(error?.localizedDescription ?? "")")
        }
    }
}

// MARK: - 发送 AENetReq 请求示例

func exampleSendRequest() {
    let networkModule = AEAINetworkModule()

    // 配置网络
    networkModule.configure(
        serverIP: "10.0.0.50",
        serverPort: 8080,
        protocolType: .udp
    )

    // 连接
    networkModule.connect { success, _ in
        guard success else { return }

        // 创建 GET 请求
        let getRequest = AENetReq(
            get: "/api/status",
            parameters: [
                "device_id": "12345",
                "version": "1.0.0"
            ],
            headers: ["Authorization": "Bearer token123"]
        )

        // 发送请求
        do {
            try networkModule.send(getRequest)
            print("✅ GET 请求已发送")
        } catch {
            print("❌ 请求发送失败: \(error)")
        }

        // 创建 POST 请求
        let userData = ["username": "test", "email": "test@example.com"]
        let bodyData = try? JSONSerialization.data(withJSONObject: userData)

        let postRequest = AENetReq(
            post: "/api/users",
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )

        do {
            try networkModule.send(postRequest)
            print("✅ POST 请求已发送")
        } catch {
            print("❌ 请求发送失败: \(error)")
        }
    }
}

// MARK: - 异步发送示例

func exampleAsyncSend() {
    let networkModule = AEAINetworkModule()

    networkModule.configure(
        serverIP: "192.168.1.100",
        serverPort: 9999
    )

    networkModule.connect { success, _ in
        guard success else { return }

        // 异步发送字典数据
        networkModule.sendAsync(data: [
            "type": "query",
            "content": "Hello AI"
        ]) { result in
            switch result {
            case .success:
                print("✅ 异步发送成功")
            case .failure(let error):
                print("❌ 异步发送失败: \(error)")
            }
        }

        // 异步发送请求
        let request = AENetReq(
            post: "/api/message",
            parameters: ["session_id": "abc123"]
        )

        networkModule.sendAsync(request) { result in
            switch result {
            case .success:
                print("✅ 异步请求发送成功")
            case .failure(let error):
                print("❌ 异步请求发送失败: \(error)")
            }
        }
    }
}

// MARK: - 消息监听示例

func exampleMessageListener() {
    let networkModule = AEAINetworkModule()

    // 创建监听者
    let listener = CustomMessageListener()

    // 添加监听者
    networkModule.addListener(listener)

    // 配置并连接
    networkModule.configure(
        serverIP: "192.168.1.100",
        serverPort: 9999
    )

    networkModule.connect { success, _ in
        if success {
            print("✅ 已连接，等待接收消息...")
        }
    }

    // 稍后移除监听者
    // networkModule.removeListener(listener)
}

// MARK: - 自定义监听者

class CustomMessageListener: AENetworkMessageListener {

    func onMessageReceived(_ message: [String: Any]) {
        print("📨 监听者收到消息: \(message)")

        // 处理不同类型的消息
        if let type = message["type"] as? String {
            switch type {
            case "notification":
                handleNotification(message)
            case "response":
                handleResponse(message)
            case "error":
                handleError(message)
            default:
                print("未知消息类型: \(type)")
            }
        }
    }

    private func handleNotification(_ message: [String: Any]) {
        print("处理通知消息: \(message)")
    }

    private func handleResponse(_ message: [String: Any]) {
        print("处理响应消息: \(message)")
    }

    private func handleError(_ message: [String: Any]) {
        print("处理错误消息: \(message)")
    }
}

// MARK: - 链式配置示例

func exampleChainConfiguration() {
    let networkModule = AEAINetworkModule()

    // 链式配置
    networkModule
        .configure(serverIP: "192.168.1.100", serverPort: 9999)
        .connect { success, error in
            if success {
                print("✅ 连接成功")
            }
        }
}

// MARK: - TCP 连接示例

func exampleTCPConnection() {
    let networkModule = AEAINetworkModule()

    // 配置为 TCP 连接
    networkModule.configure(
        serverIP: "192.168.1.100",
        serverPort: 8080,
        protocolType: .tcp  // 使用 TCP 协议
    )

    networkModule.connect { success, _ in
        if success {
            print("✅ TCP 连接成功")

            // 发送数据
            try? networkModule.send(data: [
                "type": "tcp_message",
                "content": "Hello via TCP"
            ])
        }
    }
}

// MARK: - 完整应用场景示例

class AINetworkManager {

    private let networkModule = AEAINetworkModule()
    private var isReady = false

    func setup(serverIP: String, serverPort: UInt16) {
        // 配置网络
        networkModule.configure(
            serverIP: serverIP,
            serverPort: serverPort,
            protocolType: .udp
        )

        // 添加消息监听
        let listener = CustomMessageListener()
        networkModule.addListener(listener)

        // 连接
        networkModule.connect { [weak self] success, error in
            if success {
                print("✅ AI 网络已就绪")
                self?.isReady = true
            } else {
                print("❌ AI 网络连接失败: \(error?.localizedDescription ?? "")")
            }
        }
    }

    func sendMessage(_ text: String) {
        guard isReady else {
            print("⚠️ 网络未就绪")
            return
        }

        let messageData: [String: Any] = [
            "type": "ai_query",
            "text": text,
            "timestamp": Date().timeIntervalSince1970,
            "request_id": UUID().uuidString
        ]

        networkModule.sendAsync(data: messageData) { result in
            switch result {
            case .success:
                print("✅ 消息已发送: \(text)")
            case .failure(let error):
                print("❌ 消息发送失败: \(error)")
            }
        }
    }

    func disconnect() {
        networkModule.disconnect()
        isReady = false
        print("🛑 AI 网络已断开")
    }

    var connectionStatus: String {
        return networkModule.isConnected ? "已连接" : "未连接"
    }
}

// MARK: - 使用 AEModuleCenter 自动初始化示例

/*
// 在 AppDelegate 中注册模块
import AEModuleCenter

class AppDelegate: UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 创建并配置网络模块
        let networkModule = AEAINetworkModule()
        networkModule.configure(
            serverIP: "192.168.1.100",
            serverPort: 9999,
            protocolType: .udp
        )

        // 注册到模块中心
        AEModuleCenter.shared.registerModule(networkModule)

        // 模块中心会自动调用 initializeNetwork()

        return true
    }
}
*/
