//
//  AEAINetworkProtocolUsageExample.swift
//  AEAINetworkModule
//
//  Created by Claude on 2026/4/24.
//

import Foundation
import AENetworkEngine

/**
 AEAINetworkProtocol 使用示例

 演示如何通过协议接口使用网络功能，包括接收 AENetReq 并发送
 */

// MARK: - 使用协议接口的服务类

/// AI 网络服务 - 通过协议接口使用网络功能
class AINetworkService {

    // 使用协议类型，而不是具体实现类型
    private let networkModule: AEAINetworkProtocol

    /// 初始化
    /// - Parameter networkModule: 实现了 AEAINetworkProtocol 的网络模块
    init(networkModule: AEAINetworkProtocol) {
        self.networkModule = networkModule
    }

    // MARK: - 发送 AENetReq 示例

    /// 发送查询请求
    /// - Parameters:
    ///   - query: 查询文本
    ///   - completion: 完成回调
    func sendQuery(_ query: String, completion: @escaping (Bool) -> Void) {
        // 创建 AENetReq 请求
        let request = AENetReq(
            post: "/api/query",
            parameters: [
                "query": query,
                "timestamp": Date().timeIntervalSince1970
            ],
            headers: [
                "Content-Type": "application/json",
                "User-Agent": "AEAIClient/1.0"
            ]
        )

        // 异步发送请求
        networkModule.sendAsync(request) { result in
            switch result {
            case .success:
                print("✅ 查询请求发送成功")
                completion(true)
            case .failure(let error):
                print("❌ 查询请求发送失败: \(error)")
                completion(false)
            }
        }
    }

    /// 上传用户数据
    /// - Parameter userData: 用户数据字典
    func uploadUserData(_ userData: [String: Any]) {
        // 将字典转换为 JSON body
        guard let bodyData = try? JSONSerialization.data(withJSONObject: userData) else {
            print("❌ 用户数据序列化失败")
            return
        }

        // 创建 POST 请求
        let request = AENetReq(
            post: "/api/user/upload",
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )

        // 同步发送
        do {
            try networkModule.send(request)
            print("✅ 用户数据上传成功")
        } catch {
            print("❌ 用户数据上传失败: \(error)")
        }
    }

    /// 获取设备状态
    /// - Parameter deviceId: 设备 ID
    func fetchDeviceStatus(deviceId: String) {
        // 创建 GET 请求
        let request = AENetReq(
            get: "/api/device/status",
            parameters: ["device_id": deviceId],
            headers: ["Authorization": "Bearer token"]
        )

        // 异步发送
        networkModule.sendAsync(request) { result in
            if case .success = result {
                print("✅ 设备状态请求已发送")
            }
        }
    }

    // MARK: - 发送字典数据示例

    /// 发送心跳包
    func sendHeartbeat() {
        let heartbeatData: [String: Any] = [
            "type": "heartbeat",
            "timestamp": Date().timeIntervalSince1970,
            "client_version": "1.0.0"
        ]

        // 异步发送字典
        networkModule.sendAsync(data: heartbeatData) { result in
            if case .success = result {
                print("💓 心跳包已发送")
            }
        }
    }

    /// 发送自定义消息
    /// - Parameters:
    ///   - messageType: 消息类型
    ///   - content: 消息内容
    func sendCustomMessage(messageType: String, content: [String: Any]) {
        var messageData = content
        messageData["type"] = messageType
        messageData["timestamp"] = Date().timeIntervalSince1970

        // 同步发送
        do {
            try networkModule.send(data: messageData)
            print("✅ 自定义消息已发送: \(messageType)")
        } catch {
            print("❌ 自定义消息发送失败: \(error)")
        }
    }

    // MARK: - 连接管理

    /// 检查并确保连接
    func ensureConnection(completion: @escaping (Bool) -> Void) {
        if networkModule.isConnected {
            completion(true)
        } else {
            networkModule.connect { success, error in
                if success {
                    print("✅ 网络已连接")
                } else {
                    print("❌ 网络连接失败: \(error?.localizedDescription ?? "")")
                }
                completion(success)
            }
        }
    }

    /// 断开连接
    func closeConnection() {
        networkModule.disconnect()
        print("🛑 网络已断开")
    }

    /// 获取连接状态
    var connectionStatus: String {
        return networkModule.isConnected ? "已连接" : "未连接"
    }
}

// MARK: - 批量请求处理器

/// 批量请求处理器 - 演示如何处理多个 AENetReq
class BatchRequestHandler {

    private let networkModule: AEAINetworkProtocol

    init(networkModule: AEAINetworkProtocol) {
        self.networkModule = networkModule
    }

    /// 批量发送请求
    /// - Parameter requests: 请求数组
    func sendBatchRequests(_ requests: [AENetReq]) {
        print("📦 开始批量发送 \(requests.count) 个请求...")

        for (index, request) in requests.enumerated() {
            networkModule.sendAsync(request) { result in
                switch result {
                case .success:
                    print("✅ 请求 #\(index + 1) 发送成功")
                case .failure(let error):
                    print("❌ 请求 #\(index + 1) 发送失败: \(error)")
                }
            }
        }
    }

    /// 顺序发送请求（一个完成后再发下一个）
    /// - Parameters:
    ///   - requests: 请求数组
    ///   - completion: 全部完成后的回调
    func sendSequentialRequests(_ requests: [AENetReq], completion: @escaping (Bool) -> Void) {
        guard !requests.isEmpty else {
            completion(true)
            return
        }

        var remainingRequests = requests
        let firstRequest = remainingRequests.removeFirst()

        networkModule.sendAsync(firstRequest) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                if remainingRequests.isEmpty {
                    completion(true)
                } else {
                    self.sendSequentialRequests(remainingRequests, completion: completion)
                }
            case .failure:
                completion(false)
            }
        }
    }
}

// MARK: - 使用示例

func exampleProtocolUsage() {
    // 创建网络模块
    let networkModule = AEAINetworkModule()

    // 配置网络
    networkModule.configure(
        serverIP: "192.168.1.100",
        serverPort: 9999,
        protocolType: .udp
    )

    // 连接
    networkModule.connect { success, _ in
        guard success else { return }

        // 创建服务实例（使用协议类型）
        let aiService = AINetworkService(networkModule: networkModule)

        // 发送查询
        aiService.sendQuery("Hello AI") { success in
            print("查询结果: \(success)")
        }

        // 上传用户数据
        aiService.uploadUserData([
            "username": "test_user",
            "email": "test@example.com"
        ])

        // 获取设备状态
        aiService.fetchDeviceStatus(deviceId: "device_123")

        // 发送心跳
        aiService.sendHeartbeat()

        // 发送自定义消息
        aiService.sendCustomMessage(
            messageType: "notification",
            content: ["title": "Test", "body": "Hello"]
        )
    }
}

// MARK: - 批量请求示例

func exampleBatchRequests() {
    let networkModule = AEAINetworkModule()
    networkModule.configure(serverIP: "192.168.1.100", serverPort: 9999)

    networkModule.connect { success, _ in
        guard success else { return }

        let batchHandler = BatchRequestHandler(networkModule: networkModule)

        // 创建多个请求
        let requests = [
            AENetReq(get: "/api/status"),
            AENetReq(get: "/api/version"),
            AENetReq(post: "/api/log", parameters: ["level": "info"])
        ]

        // 批量发送（并发）
        batchHandler.sendBatchRequests(requests)

        // 或者顺序发送
        batchHandler.sendSequentialRequests(requests) { success in
            print("批量请求完成: \(success)")
        }
    }
}

// MARK: - 依赖注入示例

/// 演示如何通过依赖注入使用协议
class DataSyncManager {

    // 依赖协议，不依赖具体实现
    private let network: AEAINetworkProtocol

    /// 通过构造器注入网络模块
    init(network: AEAINetworkProtocol) {
        self.network = network
    }

    /// 同步数据
    func syncData(_ data: [String: Any]) {
        let request = AENetReq(
            post: "/api/sync",
            parameters: data,
            headers: ["Content-Type": "application/json"]
        )

        network.sendAsync(request) { result in
            switch result {
            case .success:
                print("✅ 数据同步成功")
            case .failure(let error):
                print("❌ 数据同步失败: \(error)")
            }
        }
    }
}

// 使用
func exampleDependencyInjection() {
    // 创建网络模块
    let networkModule = AEAINetworkModule()
    networkModule.configure(serverIP: "192.168.1.100", serverPort: 9999)

    // 注入到其他服务
    let syncManager = DataSyncManager(network: networkModule)
    syncManager.syncData(["key": "value"])
}

// MARK: - Mock 测试示例

/// Mock 网络模块（用于测试）
class MockNetworkModule: AEAINetworkProtocol {

    var mockIsConnected: Bool = true
    var sendCalled = false
    var lastSentRequest: AENetReq?
    var lastSentData: [String: Any]?

    func send(_ request: AENetReq) throws -> Bool {
        sendCalled = true
        lastSentRequest = request
        return true
    }

    func sendAsync(_ request: AENetReq, completion: ((Result<Bool, Error>) -> Void)?) {
        sendCalled = true
        lastSentRequest = request
        completion?(.success(true))
    }

    func send(data: [String: Any]) throws -> Bool {
        sendCalled = true
        lastSentData = data
        return true
    }

    func sendAsync(data: [String: Any], completion: ((Result<Bool, Error>) -> Void)?) {
        sendCalled = true
        lastSentData = data
        completion?(.success(true))
    }

    func addListener(_ listener: AENetworkMessageListener) {}
    func removeListener(_ listener: AENetworkMessageListener) {}
    func removeAllListeners() {}
    var listenerCount: Int { return 0 }

    func connect(completion: ((Bool, Error?) -> Void)?) {
        completion?(true, nil)
    }

    func disconnect() {}

    var isConnected: Bool { return mockIsConnected }
}

// 测试使用
func exampleTestingWithMock() {
    // 使用 Mock 对象进行测试
    let mockNetwork = MockNetworkModule()
    let service = AINetworkService(networkModule: mockNetwork)

    // 发送请求
    service.sendQuery("test query") { success in
        print("Mock 测试成功: \(success)")
    }

    // 验证
    assert(mockNetwork.sendCalled, "send 方法应该被调用")
    assert(mockNetwork.lastSentRequest != nil, "应该记录最后发送的请求")
}
