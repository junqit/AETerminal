//
//  AEModuleCenter.swift
//  AEModuleCenter
//
//  Created on 2026/04/14.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 模块管理中心
/// 提供线程安全的模块注册、移除和生命周期事件转发功能
@objc public final class AEModuleCenter: NSObject {

    // MARK: - Singleton

    /// 单例实例（私有）
    private static let shared = AEModuleCenter()

    // MARK: - Private Properties

    /// 存储已注册的模块（使用 NSHashTable 支持弱引用，避免循环引用）
    private let modules: NSHashTable<AnyObject>

    /// 锁，用于保护关键区域
    private let lock: NSRecursiveLock

    // MARK: - Initialization

    private override init() {
        // 使用弱引用的 HashTable，模块被释放时自动移除
        self.modules = NSHashTable<AnyObject>.weakObjects()
        // 递归锁，支持同一线程多次加锁
        self.lock = NSRecursiveLock()
        self.lock.name = "com.aemodulecenter.lock"

        super.init()
    }

    // MARK: - Module Management (Public Class Methods)

    /// 注册模块（线程安全）
    /// - Parameter module: 实现了 AEModuleProtocol 协议的模块实例
    /// - Returns: true 注册成功，false 注册失败（模块已存在）
    @objc @discardableResult
    public class func register(module: AEModuleProtocol) -> Bool {
        return shared.registerModule(module)
    }

    /// 移除模块（线程安全）
    /// - Parameter module: 要移除的模块实例
    /// - Returns: true 移除成功，false 移除失败（模块不存在）
    @objc @discardableResult
    public class func unregister(module: AEModuleProtocol) -> Bool {
        return shared.unregisterModule(module)
    }

    /// 移除所有模块（线程安全）
    @objc public class func unregisterAll() {
        shared.unregisterAllModules()
    }

    /// 获取已注册模块数量
    /// - Returns: 模块数量
    @objc public class var moduleCount: Int {
        return shared.getModuleCount()
    }

    /// 获取指定协议类型的模块实例
    /// - Parameter protocolType: 协议类型
    /// - Returns: 实现了该协议的模块实例，如果没有则返回 nil
    public class func module<T>(for protocolType: T.Type) -> T? {
        return shared.getModule(for: protocolType)
    }

    // MARK: - Module Management (Private Instance Methods)

    /// 注册模块（实例方法）
    private func registerModule(_ module: AEModuleProtocol) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // 检查模块是否已存在
        if modules.contains(module as AnyObject) {
            debugPrint("[AEModuleCenter] Module already registered: \(type(of: module))")
            return false
        }

        // 添加模块
        modules.add(module as AnyObject)
        debugPrint("[AEModuleCenter] Module registered successfully: \(type(of: module))")
        return true
    }

    /// 移除模块（实例方法）
    private func unregisterModule(_ module: AEModuleProtocol) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // 检查模块是否存在
        if !modules.contains(module as AnyObject) {
            debugPrint("[AEModuleCenter] Module not found: \(type(of: module))")
            return false
        }

        // 移除模块
        modules.remove(module as AnyObject)
        debugPrint("[AEModuleCenter] Module unregistered successfully: \(type(of: module))")
        return true
    }

    /// 移除所有模块（实例方法）
    private func unregisterAllModules() {
        lock.lock()
        defer { lock.unlock() }

        let count = modules.count
        modules.removeAllObjects()
        debugPrint("[AEModuleCenter] All modules unregistered, count: \(count)")
    }

    /// 获取已注册模块数量（实例方法）
    private func getModuleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }

        return modules.count
    }

    /// 获取指定协议类型的模块实例（实例方法）
    private func getModule<T>(for protocolType: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }

        let result = modules.allObjects.compactMap { $0 as? T }.first
        debugPrint("[AEModuleCenter] Getting module for \(protocolType), found: \(result != nil), total modules: \(modules.allObjects)")
        return result
    }

    // MARK: - Private Helper

    /// 获取所有模块的快照（线程安全）
    /// - Returns: 模块数组
    private func getModulesSnapshot() -> [AEModuleProtocol] {
        lock.lock()
        defer { lock.unlock() }

        return modules.allObjects.compactMap { $0 as? AEModuleProtocol }
    }

    // MARK: - Lifecycle Forwarding (macOS Class Methods)

#if os(macOS)
    /// Application 启动完成
    @objc public class func applicationDidFinishLaunching(_ notification: Notification) {
        shared.forwardApplicationDidFinishLaunching(notification)
    }

    /// Application 已经进入前台（变为活跃状态）
    @objc public class func applicationDidBecomeActive(_ notification: Notification) {
        shared.forwardApplicationDidBecomeActive(notification)
    }

    /// Application 将要失去活跃状态
    @objc public class func applicationWillResignActive(_ notification: Notification) {
        shared.forwardApplicationWillResignActive(notification)
    }

    /// Application 将要终止
    @objc public class func applicationWillTerminate(_ notification: Notification) {
        shared.forwardApplicationWillTerminate(notification)
    }
#endif

    // MARK: - Lifecycle Forwarding (Private Instance Methods)

#if os(macOS)
    /// Application 启动完成（实例方法）
    private func forwardApplicationDidFinishLaunching(_ notification: Notification) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.applicationDidFinishLaunching?(notification)
        }
    }

    /// Application 已经进入前台（实例方法）
    private func forwardApplicationDidBecomeActive(_ notification: Notification) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.applicationDidBecomeActive?(notification)
        }
    }

    /// Application 将要失去活跃状态（实例方法）
    private func forwardApplicationWillResignActive(_ notification: Notification) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.applicationWillResignActive?(notification)
        }
    }

    /// Application 将要终止（实例方法）
    private func forwardApplicationWillTerminate(_ notification: Notification) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.applicationWillTerminate?(notification)
        }
    }
#endif

#if os(iOS)
    // MARK: - Remote Notification (Public Class Methods)

    /// 注册远程通知成功
    @objc public class func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        shared.forwardApplication(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    /// 注册远程通知失败
    @objc public class func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        shared.forwardApplication(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    /// 收到远程通知
    @objc public class func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        shared.forwardApplication(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }

    // MARK: - URL Handling (Public Class Methods)

    /// 打开 URL
    @objc @discardableResult
    public class func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return shared.forwardApplication(app, open: url, options: options)
    }

    // MARK: - User Activity (Public Class Methods)

    /// 继续用户活动
    @objc @discardableResult
    public class func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return shared.forwardApplication(application, continue: userActivity, restorationHandler: restorationHandler)
    }
#endif

    // MARK: - iOS Lifecycle Forwarding (Private Instance Methods)

#if os(iOS)
    /// 注册远程通知成功（实例方法）
    private func forwardApplication(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        }
    }

    /// 注册远程通知失败（实例方法）
    private func forwardApplication(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            module.application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
        }
    }

    /// 收到远程通知（实例方法）
    private func forwardApplication(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let snapshot = getModulesSnapshot()
        let group = DispatchGroup()
        var results: [UIBackgroundFetchResult] = []
        let resultsLock = NSLock()

        for module in snapshot {
            if module.application(_:didReceiveRemoteNotification:fetchCompletionHandler:) != nil {
                group.enter()
                module.application?(application, didReceiveRemoteNotification: userInfo) { result in
                    resultsLock.lock()
                    results.append(result)
                    resultsLock.unlock()
                    group.leave()
                }
            }
        }

        // 等待所有模块处理完成
        group.notify(queue: .main) {
            // 合并结果：优先级 newData > failed > noData
            let finalResult: UIBackgroundFetchResult
            if results.contains(.newData) {
                finalResult = .newData
            } else if results.contains(.failed) {
                finalResult = .failed
            } else {
                finalResult = .noData
            }
            completionHandler(finalResult)
        }
    }

    /// 打开 URL（实例方法）
    private func forwardApplication(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            if let handled = module.application?(app, open: url, options: options), handled {
                return true
            }
        }

        return false
    }

    /// 继续用户活动（实例方法）
    private func forwardApplication(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        let snapshot = getModulesSnapshot()

        for module in snapshot {
            if let handled = module.application?(application, continue: userActivity, restorationHandler: restorationHandler), handled {
                return true
            }
        }

        return false
    }
#endif
}
