//
//  AENetworkListenerManager.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AENetworkEngine

/// 网络监听者管理器
internal class AENetworkListenerManager {

    // MARK: - Properties

    /// 监听者数组（使用 NSHashTable 支持弱引用）
    private let listeners: NSHashTable<AnyObject>

    /// 监听者锁
    private let listenersLock = NSLock()

    // MARK: - Initialization

    init() {
        // 使用弱引用 HashTable，监听者被释放时自动移除
        self.listeners = NSHashTable<AnyObject>.weakObjects()
    }

    // MARK: - Public Methods

    /// 注册监听者
    /// - Parameter listener: 监听者实例
    func addListener(_ listener: AENetworkMessageListener) {
        listenersLock.lock()
        defer { listenersLock.unlock() }

        // 检查是否已存在
        if listeners.contains(listener as AnyObject) {
            log("⚠️ 监听者已注册: \(type(of: listener))")
            return
        }

        listeners.add(listener as AnyObject)
        log("✓ 注册监听者: \(type(of: listener)), 当前监听者数量: \(listeners.count)")
    }

    /// 移除监听者
    /// - Parameter listener: 监听者实例
    func removeListener(_ listener: AENetworkMessageListener) {
        listenersLock.lock()
        defer { listenersLock.unlock() }

        if listeners.contains(listener as AnyObject) {
            listeners.remove(listener as AnyObject)
            log("✓ 移除监听者: \(type(of: listener)), 当前监听者数量: \(listeners.count)")
        } else {
            log("⚠️ 监听者不存在: \(type(of: listener))")
        }
    }

    /// 移除所有监听者
    func removeAllListeners() {
        listenersLock.lock()
        defer { listenersLock.unlock() }

        let count = listeners.count
        listeners.removeAllObjects()
        log("✓ 移除所有监听者, 数量: \(count)")
    }

    /// 通知所有监听者
    /// - Parameter response: 响应对象
    func notifyListeners(response: AENetRsp) {
        let snapshot = getListenersSnapshot()
        log("📢 通知 \(snapshot.count) 个监听者")

        DispatchQueue.main.async {
            for listener in snapshot {
                listener.didReceiveMessage(response)
            }
        }
    }

    /// 获取监听者数量
    var count: Int {
        listenersLock.lock()
        defer { listenersLock.unlock() }
        return listeners.count
    }

    // MARK: - Private Methods

    /// 获取监听者快照
    private func getListenersSnapshot() -> [AENetworkMessageListener] {
        listenersLock.lock()
        defer { listenersLock.unlock() }

        return listeners.allObjects.compactMap { $0 as? AENetworkMessageListener }
    }

    /// 日志输出
    private func log(_ message: String) {
        print("[AENetworkListenerManager] \(message)")
    }
}
