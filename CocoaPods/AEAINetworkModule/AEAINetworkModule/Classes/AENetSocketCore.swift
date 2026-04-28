//
//  AENetSocketCore.swift
//  AEAINetworkModule
//
//  Created on 2026/04/28.
//

import Foundation
import AENetworkEngine

/// Socket 网络核心 - 实现 AENetCoreProtocol，封装 AEAISocketManager
public class AENetSocketCore: AENetCoreProtocol {

    // MARK: - AENetCoreProtocol

    /// 网络核心代理
    public weak var delegate: AENetCoreDelegate?

    /// 网络核心类型
    public var coreType: AENetworkType {
        return .socket
    }

    // MARK: - Properties

    /// Socket 管理器
    private var socketManager: AEAISocketManager?

    /// 网络配置
    private var config: AENetConfig

    /// 连接状态变化回调
    public var onConnectionStateChanged: ((AESocketState) -> Void)?

    /// 是否已连接
    public var isConnected: Bool {
        return socketManager?.isConnected ?? false
    }

    // MARK: - Initialization

    /// 初始化
    /// - Parameter config: 网络配置
    public init(config: AENetConfig) {
        self.config = config
    }

    // MARK: - Connection Management

    /// 连接到服务器
    /// - Parameter completion: 完成回调
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        // 创建 Socket 管理器
        socketManager = AEAISocketManager(
            serverIP: config.host,
            serverPort: config.port,
            path: config.path
        )

        // 设置状态变化回调
        socketManager?.onConnectionStateChanged = { [weak self] state in
            self?.onConnectionStateChanged?(state)
        }

        // 设置响应接收回调（主动推送）
        socketManager?.onResponseReceived = { [weak self] response in
            // 通过 delegate 通知上层（主动推送的数据）
            self?.delegate?.netCore(didReceive: response)
        }

        // 执行连接
        socketManager?.connect(completion: completion)
    }

    /// 断开连接
    public func disconnect() {
        socketManager?.disconnect()
        socketManager = nil
    }

    // MARK: - AENetCoreProtocol Methods

    /// 发送请求
    /// - Parameters:
    ///   - request: 请求对象
    ///   - completion: 完成回调（可选）
    public func send(request: AENetReq, completion: ((AENetRsp) -> Void)?) {
        guard let socketManager = socketManager else {
            let error = NSError(
                domain: "AENetSocketCore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Socket 未连接"]
            )
            let response = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                error: error
            )

            // 如果有 completion，调用 completion
            if let completion = completion {
                completion(response)
            } else {
                // 否则通过 delegate 通知
                delegate?.netCore(didReceive: response)
            }
            return
        }

        // 发送请求
        do {
            try socketManager.send(request)

            // Socket 是异步的，响应会通过 onResponseReceived 回调返回
            // 如果有 completion，需要等待响应（这里简化处理，实际可能需要请求ID映射）
            // 响应会通过 socketManager.onResponseReceived 回调返回
        } catch {
            let response = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                error: error
            )

            // 如果有 completion，调用 completion
            if let completion = completion {
                completion(response)
            } else {
                // 否则通过 delegate 通知
                delegate?.netCore(didReceive: response)
            }
        }
    }
}
