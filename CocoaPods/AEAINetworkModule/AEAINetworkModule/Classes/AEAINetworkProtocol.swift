//
//  AEAINetworkProtocol.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AEModuleCenter
import AENetworkEngine

/// AEAI 网络能力协议
/// 定义网络模块对外提供的能力接口
/// 继承 AEModuleProtocol，使其可以被 AEModuleCenter 管理
public protocol AEAINetworkProtocol: AEModuleProtocol {

    // MARK: - Send Methods - AENetReq

    /// 发送 AENetReq 请求（同步）
    /// - Parameter request: 网络请求对象
    /// - Returns: 发送结果
    /// - Throws: 发送失败时抛出错误
    @discardableResult
    func send(_ request: AENetReq) throws -> Bool

    /// 异步发送 AENetReq 请求
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - completion: 完成回调
    func sendAsync(_ request: AENetReq, completion: ((Result<Bool, Error>) -> Void)?)

    // MARK: - Send Methods - Dictionary

    /// 发送字典数据（同步）
    /// - Parameter data: 要发送的数据字典
    /// - Returns: 发送结果
    /// - Throws: 发送失败时抛出错误
    @discardableResult
    func send(data: [String: Any]) throws -> Bool

    /// 异步发送字典数据
    /// - Parameters:
    ///   - data: 要发送的数据字典
    ///   - completion: 完成回调
    func sendAsync(data: [String: Any], completion: ((Result<Bool, Error>) -> Void)?)

    // MARK: - Listener Management

    /// 注册消息监听者
    /// - Parameter listener: 监听者实例
    func addListener(_ listener: AENetworkMessageListener)

    /// 移除消息监听者
    /// - Parameter listener: 监听者实例
    func removeListener(_ listener: AENetworkMessageListener)

    /// 移除所有监听者
    func removeAllListeners()

    /// 获取监听者数量
    var listenerCount: Int { get }

    // MARK: - Connection Management

    /// 手动连接网络
    /// - Parameter completion: 连接结果回调
    func connect(completion: ((Bool, Error?) -> Void)?)

    /// 手动断开网络
    func disconnect()

    /// 获取网络连接状态
    var isConnected: Bool { get }
}
