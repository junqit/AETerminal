//
//  AEReqManager.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/9/4.
//

import Foundation
import AELogProxy

/// 请求管理器：线程安全地管理 AENetReq 的添加与移除（按 requestId 索引）。
public class AEReqManager {

    // MARK: - Properties

    /// 待处理请求 [requestId: AENetReq]
    private var requests: [String: AENetReq] = [:]

    /// 访问锁
    private let lock = NSLock()

    // MARK: - Initialization

    /// 初始化
    public init() {}

    // MARK: - Add / Remove

    /// 添加请求（按 requestId 索引；已存在同 requestId 将覆盖）
    /// - Parameter request: 请求对象
    public func add(_ request: AENetReq) {

        lock.lock()
        requests[request.requestId] = request
        lock.unlock()
    }

    /// 按 requestId 移除请求
    /// - Parameter requestId: 请求唯一标识
    /// - Returns: 被移除的请求；未命中返回 nil
    @discardableResult
    public func remove(_ requestId: String) -> AENetReq? {

        lock.lock()
        let removed = requests.removeValue(forKey: requestId)
        lock.unlock()

        if removed == nil {
            AELog("⚠️ [AEReqManager] 移除请求未命中，requestId:\(requestId)")
        }

        return removed
    }

    /// 移除指定请求（等价于按其 requestId 移除）
    /// - Parameter request: 请求对象
    /// - Returns: 被移除的请求；未命中返回 nil
    @discardableResult
    public func remove(_ request: AENetReq) -> AENetReq? {

        return remove(request.requestId)
    }

    /// 清空全部请求
    public func removeAll() {

        lock.lock()
        let count = requests.count
        requests.removeAll()
        lock.unlock()

        AELog("✅ [AEReqManager] 清空请求池，数量:\(count)")
    }

    // MARK: - Query

    /// 按 requestId 查询请求
    /// - Parameter requestId: 请求唯一标识
    /// - Returns: 命中的请求；未命中返回 nil
    public func request(for requestId: String) -> AENetReq? {

        lock.lock()
        let req = requests[requestId]
        lock.unlock()
        return req
    }

    /// 是否存在指定 requestId 的请求
    /// - Parameter requestId: 请求唯一标识
    /// - Returns: 存在返回 true
    public func contains(_ requestId: String) -> Bool {

        lock.lock()
        let exists = requests[requestId] != nil
        lock.unlock()
        return exists
    }

    /// 全部请求（快照）
    public var allRequests: [AENetReq] {

        lock.lock()
        let snapshot = Array(requests.values)
        lock.unlock()
        return snapshot
    }

    /// 当前请求数量
    public var count: Int {

        lock.lock()
        let n = requests.count
        lock.unlock()
        return n
    }
}
