//
//  AEUDPSocketClient.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/9.
//

import Foundation
import Network

/// UDP Socket 客户端（支持请求-响应匹配和推送消息）
public class AEUDPSocketClient {

    // MARK: - Properties

    /// 配置
    private var config: AEUDPSocketConfig

    /// NWConnection（用于 UDP 通信）
    private var connection: NWConnection?

    /// 接收队列
    private let receiveQueue = DispatchQueue(label: "com.aenetwork.udp.receive")

    /// 发送队列
    private let sendQueue = DispatchQueue(label: "com.aenetwork.udp.send")

    /// 是否已连接
    public private(set) var isConnected: Bool = false

    /// 请求 ID 计数器（原子操作）
    private let requestIdCounter = AtomicCounter()

    /// 待处理的请求字典 [requestId: completion]
    private var pendingRequests: [String: ([String: Any]?, Error?) -> Void] = [:]
    private let pendingRequestsLock = NSLock()

    /// 推送消息回调（服务器主动推送的消息，没有 request_id）
    public var pushMessageHandler: (([String: Any]) -> Void)?

    /// 是否正在监听
    private var isListening: Bool = false

    /// 超时时间（秒）
    private let timeout: TimeInterval = 5.0

    /// 是否启用日志
    public var enableLog: Bool = true

    // MARK: - Lifecycle

    public init(config: AEUDPSocketConfig) {
        self.config = config
    }

    deinit {
        disconnect()
    }

    // MARK: - Public Methods

    /// 连接到服务器
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        guard !isConnected else {
            log("已经连接")
            completion?(true, nil)
            return
        }

        // 创建 UDP 连接
        let host = NWEndpoint.Host(config.serverHost)
        let port = NWEndpoint.Port(rawValue: config.serverPort)!

        connection = NWConnection(host: host, port: port, using: .udp)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.isConnected = true
                self.log("✓ 已连接到服务器: \(self.config.serverHost):\(self.config.serverPort)")

                // 连接成功后启动持续监听
                self.startContinuousListening()

                completion?(true, nil)

            case .failed(let error):
                self.isConnected = false
                self.log("✗ 连接失败: \(error)")
                completion?(false, error)

            case .waiting(let error):
                self.log("⏳ 等待连接: \(error)")

            case .cancelled:
                self.isConnected = false
                self.log("连接已取消")

            default:
                break
            }
        }

        connection?.start(queue: receiveQueue)
    }

    /// 断开连接
    public func disconnect() {
        isListening = false

        // 清理所有待处理的请求
        pendingRequestsLock.lock()
        let requests = pendingRequests
        pendingRequests.removeAll()
        pendingRequestsLock.unlock()

        // 通知所有待处理请求连接已断开
        let error = NSError(domain: "AEUDPSocketClient",
                           code: -999,
                           userInfo: [NSLocalizedDescriptionKey: "连接已断开"])
        for (_, completion) in requests {
            completion(nil, error)
        }

        connection?.cancel()
        connection = nil
        isConnected = false
        log("已断开连接")
    }

    /// 发送 JSON 数据（带请求-响应匹配）
    /// - Parameters:
    ///   - data: 要发送的字典数据
    ///   - completion: 完成回调（会自动匹配响应）
    public func send(data: [String: Any], completion: (([String: Any]?, Error?) -> Void)? = nil) {
        guard isConnected else {
            let error = NSError(domain: "AEUDPSocketClient",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "未连接到服务器"])
            completion?(nil, error)
            return
        }

        // 生成唯一的 request_id
        let requestId = generateRequestId()

        // 将 request_id 添加到数据中
        var messageData = data
        messageData["request_id"] = requestId
        messageData["timestamp"] = ISO8601DateFormatter().string(from: Date())

        // 如果有 completion，保存到待处理字典
        if let completion = completion {
            pendingRequestsLock.lock()
            pendingRequests[requestId] = completion
            pendingRequestsLock.unlock()

            // 设置超时
            setupTimeout(for: requestId)
        }

        // 转换为 JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: messageData, options: []) else {
            let error = NSError(domain: "AEUDPSocketClient",
                               code: -2,
                               userInfo: [NSLocalizedDescriptionKey: "JSON 序列化失败"])

            // 清理待处理请求
            if completion != nil {
                pendingRequestsLock.lock()
                pendingRequests.removeValue(forKey: requestId)
                pendingRequestsLock.unlock()
            }

            completion?(nil, error)
            return
        }

        // 发送数据
        connection?.send(content: jsonData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.log("✗ 发送失败: \(error)")

                // 发送失败，清理并回调
                if completion != nil {
                    self?.pendingRequestsLock.lock()
                    self?.pendingRequests.removeValue(forKey: requestId)
                    self?.pendingRequestsLock.unlock()

                    completion?(nil, error)
                }
            } else {
                self?.log("✓ 已发送数据 [request_id: \(requestId)]")
            }
        })
    }

    // MARK: - Private Methods

    /// 启动持续监听
    private func startContinuousListening() {
        guard !isListening else { return }

        isListening = true
        log("✓ 开始持续监听消息")

        // 在接收队列上启动持续监听循环
        receiveQueue.async { [weak self] in
            self?.receiveLoop()
        }
    }

    /// 持续接收消息的循环
    private func receiveLoop() {
        // 使用 while 循环而不是递归，避免栈溢出
        while isListening && isConnected {
            // 使用信号量来等待每次接收完成
            let semaphore = DispatchSemaphore(value: 0)

            connection?.receiveMessage { [weak self] data, _, _, error in
                guard let self = self else {
                    semaphore.signal()
                    return
                }

                if let error = error {
                    self.log("✗ 接收错误: \(error)")
                } else if let data = data {
                    self.handleReceivedData(data)
                }

                // 完成本次接收，继续下一次
                semaphore.signal()
            }

            // 等待本次接收完成
            semaphore.wait()
        }

        log("监听循环已退出")
    }

    /// 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        // 解析 JSON
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            log("✗ JSON 解析失败")
            return
        }

        log("✓ 收到消息: \(json)")

        // 检查是否有 request_id
        if let requestId = json["request_id"] as? String {
            // 响应消息：匹配请求并回调
            handleResponseMessage(requestId: requestId, response: json)
        } else {
            // 推送消息：直接回调给上层
            handlePushMessage(json)
        }
    }

    /// 处理响应消息（有 request_id）
    private func handleResponseMessage(requestId: String, response: [String: Any]) {
        pendingRequestsLock.lock()
        let completion = pendingRequests.removeValue(forKey: requestId)
        pendingRequestsLock.unlock()

        if let completion = completion {
            log("✓ 匹配到请求 [request_id: \(requestId)]")
            completion(response, nil)
        } else {
            log("⚠️ 未找到匹配的请求 [request_id: \(requestId)]，可能已超时")
        }
    }

    /// 处理推送消息（没有 request_id）
    private func handlePushMessage(_ message: [String: Any]) {
        log("📨 收到推送消息: \(message["type"] ?? "unknown")")

        if let handler = pushMessageHandler {
            handler(message)
        } else {
            log("⚠️ 未设置推送消息处理器，消息被忽略")
        }
    }

    /// 生成唯一的请求 ID
    private func generateRequestId() -> String {
        let counter = requestIdCounter.increment()
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return "req_\(timestamp)_\(counter)"
    }

    /// 设置请求超时
    private func setupTimeout(for requestId: String) {
        receiveQueue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }

            self.pendingRequestsLock.lock()
            let completion = self.pendingRequests.removeValue(forKey: requestId)
            self.pendingRequestsLock.unlock()

            if let completion = completion {
                self.log("⏱ 请求超时 [request_id: \(requestId)]")
                let error = NSError(domain: "AEUDPSocketClient",
                                   code: -3,
                                   userInfo: [NSLocalizedDescriptionKey: "请求超时"])
                completion(nil, error)
            }
        }
    }

    /// 日志输出
    private func log(_ message: String) {
        guard enableLog else { return }
        print("[AEUDPSocketClient] \(message)")
    }
}

// MARK: - Convenience Methods

extension AEUDPSocketClient {

    /// Ping 服务器
    /// - Parameter completion: 完成回调
    public func ping(completion: @escaping (Bool, Error?) -> Void) {
        let pingData: [String: Any] = [
            "type": "ping"
        ]

        send(data: pingData) { response, error in
            if let error = error {
                completion(false, error)
                return
            }

            if let response = response,
               let type = response["type"] as? String,
               type == "pong" {
                completion(true, nil)
            } else {
                let error = NSError(domain: "AEUDPSocketClient",
                                   code: -5,
                                   userInfo: [NSLocalizedDescriptionKey: "Ping 响应无效"])
                completion(false, error)
            }
        }
    }

    /// 发送聊天消息
    /// - Parameters:
    ///   - message: 消息内容
    ///   - contextId: 上下文 ID
    ///   - completion: 完成回调
    public func sendChat(message: String,
                        contextId: String? = nil,
                        completion: @escaping ([String: Any]?, Error?) -> Void) {
        var chatData: [String: Any] = [
            "type": "chat",
            "message": message
        ]

        if let contextId = contextId {
            chatData["context_id"] = contextId
        }

        send(data: chatData, completion: completion)
    }

    /// 发送自定义消息
    /// - Parameters:
    ///   - customData: 自定义数据
    ///   - completion: 完成回调
    public func sendCustom(data customData: [String: Any],
                          completion: @escaping ([String: Any]?, Error?) -> Void) {
        let requestData: [String: Any] = [
            "type": "custom",
            "data": customData
        ]

        send(data: requestData, completion: completion)
    }
}

// MARK: - Async/Await Support

@available(iOS 13.0, macOS 10.15, *)
extension AEUDPSocketClient {

    /// 连接到服务器（async/await）
    public func connect() async throws {
        try await withCheckedThrowingContinuation { continuation in
            connect { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "AEUDPSocketClient", code: -1))
                }
            }
        }
    }

    /// 发送并接收（async/await）
    public func send(data: [String: Any]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            send(data: data) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let response = response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: NSError(domain: "AEUDPSocketClient", code: -1))
                }
            }
        }
    }

    /// Ping（async/await）
    public func ping() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            ping { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// 发送聊天消息（async/await）
    public func sendChat(message: String, contextId: String? = nil) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            sendChat(message: message, contextId: contextId) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let response = response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: NSError(domain: "AEUDPSocketClient", code: -1))
                }
            }
        }
    }
}

// MARK: - Atomic Counter

/// 原子计数器（线程安全）
private class AtomicCounter {
    private var value: Int = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
