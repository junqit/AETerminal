//
//  NetworkModuleUsageExample.swift
//  使用示例
//

import Foundation
import AEAINetworkModule

// MARK: - 创建监听者

class MyMessageListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        print("收到消息: \(message)")

        let type = message["type"] as? String ?? "unknown"

        switch type {
        case "chat_response":
            if let responseMessage = message["message"] as? String {
                print("AI 回复: \(responseMessage)")
            }

        case "notification":
            print("收到推送通知")

        default:
            print("其他消息类型: \(type)")
        }
    }
}

// MARK: - 使用示例

class NetworkExampleViewController {

    private let networkModule: AEAINetworkModule
    private let listener = MyMessageListener()

    init(networkModule: AEAINetworkModule) {
        self.networkModule = networkModule

        // 注册监听者
        networkModule.addListener(listener)
    }

    deinit {
        // 移除监听者
        networkModule.removeListener(listener)
    }

    // MARK: - 发送示例

    /// 示例 1: 同步发送（等待发送完成）
    func sendMessageSync() {
        let data: [String: Any] = [
            "type": "chat",
            "message": "你好，这是一条测试消息"
        ]

        let result = networkModule.send(data: data)

        switch result {
        case .success:
            print("✓ 发送成功")
        case .failure(let error):
            print("✗ 发送失败: \(error)")
        }
    }

    /// 示例 2: 异步发送（不阻塞）
    func sendMessageAsync() {
        let data: [String: Any] = [
            "type": "chat",
            "message": "你好，这是异步消息"
        ]

        networkModule.sendAsync(data: data) { result in
            switch result {
            case .success:
                print("✓ 异步发送成功")
            case .failure(let error):
                print("✗ 异步发送失败: \(error)")
            }
        }
    }

    /// 示例 3: 发送自定义消息
    func sendCustomMessage() {
        let data: [String: Any] = [
            "type": "custom",
            "data": [
                "action": "query",
                "parameters": [
                    "key1": "value1",
                    "key2": "value2"
                ]
            ]
        ]

        networkModule.sendAsync(data: data) { result in
            switch result {
            case .success:
                print("✓ 自定义消息发送成功")
            case .failure(let error):
                print("✗ 自定义消息发送失败: \(error)")
            }
        }
    }

    /// 示例 4: 批量发送消息
    func sendMultipleMessages() {
        let messages = [
            ["type": "chat", "message": "消息 1"],
            ["type": "chat", "message": "消息 2"],
            ["type": "chat", "message": "消息 3"]
        ]

        // 消息会按顺序一条条发送
        for (index, message) in messages.enumerated() {
            networkModule.sendAsync(data: message) { result in
                print("消息 \(index + 1) 发送结果: \(result)")
            }
        }
    }

    /// 示例 5: 查询监听者数量
    func checkListenerCount() {
        let count = networkModule.listenerCount
        print("当前监听者数量: \(count)")
    }
}

// MARK: - 多个监听者示例

class ChatListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        // 只处理聊天消息
        if message["type"] as? String == "chat_response" {
            print("[ChatListener] 处理聊天消息")
        }
    }
}

class NotificationListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        // 只处理通知消息
        if message["type"] as? String == "notification" {
            print("[NotificationListener] 处理通知消息")
        }
    }
}

class AnalyticsListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        // 记录所有消息用于分析
        print("[AnalyticsListener] 记录消息: \(message["type"] ?? "unknown")")
    }
}

// MARK: - 在 AppDelegate 中使用

/*
class AppDelegate: NSObject, NSApplicationDelegate {

    private let networkModule = AEAINetworkModule()

    // 创建多个监听者
    private let chatListener = ChatListener()
    private let notificationListener = NotificationListener()
    private let analyticsListener = AnalyticsListener()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 配置网络
        networkModule.configure(serverHost: "127.0.0.1", serverPort: 9000)

        // 2. 注册模块
        AEModuleCenter.shared.register(module: networkModule)

        // 3. 注册监听者
        networkModule.addListener(chatListener)
        networkModule.addListener(notificationListener)
        networkModule.addListener(analyticsListener)

        // 4. 转发生命周期
        AEModuleCenter.shared.applicationDidFinishLaunching(notification)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理监听者（可选，因为使用弱引用会自动清理）
        networkModule.removeAllListeners()
    }
}
*/
