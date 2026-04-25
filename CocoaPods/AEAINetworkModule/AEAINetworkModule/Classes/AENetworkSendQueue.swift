//
//  AENetworkSendQueue.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AENetworkEngine

/// 网络发送队列
internal class AENetworkSendQueue {

    // MARK: - Properties

    /// 网络管理器
    private weak var networkManager: AEUDPNetworkManager?

    /// 串行队列（保证消息按顺序发送）
    private let sendQueue = DispatchQueue(label: "com.aeai.network.send", qos: .userInitiated)

    /// 是否正在发送
    private var isSending = false

    /// 发送锁
    private let sendLock = NSLock()

    // MARK: - Initialization

    init(networkManager: AEUDPNetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Public Methods

    /// 发送消息（同步，等待发送完成）
    /// - Parameter data: 要发送的数据字典
    /// - Returns: 发送结果
    @discardableResult
    func send(data: [String: Any]) -> AENetworkSendResult {
        guard let networkManager = networkManager else {
            return .failure(NSError(
                domain: "AENetworkSendQueue",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "网络管理器不存在"]
            ))
        }

        // 使用信号量实现同步等待
        let semaphore = DispatchSemaphore(value: 0)
        var result: AENetworkSendResult = .failure(NSError(
            domain: "AENetworkSendQueue",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "发送超时"]
        ))

        // 在串行队列上发送，保证顺序
        sendQueue.async { [weak self] in
            guard let self = self else {
                result = .failure(NSError(
                    domain: "AENetworkSendQueue",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "队列已释放"]
                ))
                semaphore.signal()
                return
            }

            // 标记正在发送
            self.sendLock.lock()
            self.isSending = true
            self.sendLock.unlock()

            // 发送消息（这里不需要 request_id，客户端会自动添加）
            networkManager.sendMessage(type: data["type"] as? String ?? "custom", data: data) { response, error in
                if let error = error {
                    result = .failure(error)
                } else {
                    result = .success
                }

                // 标记发送完成
                self.sendLock.lock()
                self.isSending = false
                self.sendLock.unlock()

                // 通知完成
                semaphore.signal()
            }
        }

        // 等待发送完成（最多等待 10 秒）
        let timeout = DispatchTime.now() + .seconds(10)
        _ = semaphore.wait(timeout: timeout)

        return result
    }

    /// 异步发送消息（不等待结果）
    /// - Parameters:
    ///   - data: 要发送的数据字典
    ///   - completion: 完成回调（可选）
    func sendAsync(data: [String: Any], completion: ((AENetworkSendResult) -> Void)? = nil) {
        sendQueue.async { [weak self] in
            let result = self?.send(data: data) ?? .failure(NSError(
                domain: "AENetworkSendQueue",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "队列已释放"]
            ))

            completion?(result)
        }
    }
}
