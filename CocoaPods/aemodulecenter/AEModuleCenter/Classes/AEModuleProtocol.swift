//
//  AEModuleProtocol.swift
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

/// Module 协议，定义了 Application 生命周期各个阶段的回调方法
/// 所有注册到 AEModuleCenter 的模块都需要实现此协议
@objc public protocol AEModuleProtocol: AnyObject {

    // MARK: - Application Lifecycle

#if os(iOS)
    /// Application 启动完成
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - launchOptions: 启动参数
    /// - Returns: true 表示处理成功，false 表示失败
    @objc optional func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool

    /// Application 将要进入前台
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationWillEnterForeground(_ application: UIApplication)

    /// Application 已经进入前台（变为活跃状态）
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationDidBecomeActive(_ application: UIApplication)

    /// Application 将要失去活跃状态
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationWillResignActive(_ application: UIApplication)

    /// Application 已经进入后台
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationDidEnterBackground(_ application: UIApplication)

    /// Application 将要终止
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationWillTerminate(_ application: UIApplication)

    // MARK: - Memory Warning

    /// 收到内存警告
    /// - Parameter application: UIApplication 实例
    @objc optional func applicationDidReceiveMemoryWarning(_ application: UIApplication)

    // MARK: - Remote Notification

    /// 注册远程通知成功
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - deviceToken: 设备 Token
    @objc optional func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    )

    /// 注册远程通知失败
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - error: 错误信息
    @objc optional func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    )

    /// 收到远程通知
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - userInfo: 通知信息
    ///   - completionHandler: 完成回调
    @objc optional func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    )

    // MARK: - URL Handling

    /// 打开 URL
    /// - Parameters:
    ///   - app: UIApplication 实例
    ///   - url: URL
    ///   - options: 选项
    /// - Returns: true 表示处理成功，false 表示失败
    @objc optional func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any]
    ) -> Bool

    // MARK: - User Activity

    /// 继续用户活动
    /// - Parameters:
    ///   - application: UIApplication 实例
    ///   - userActivity: 用户活动
    ///   - restorationHandler: 恢复处理器
    /// - Returns: true 表示处理成功，false 表示失败
    @objc optional func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool
#elseif os(macOS)
    /// Application 启动完成
    /// - Parameter notification: 通知对象
    @objc optional func applicationDidFinishLaunching(_ notification: Notification)

    /// Application 已经进入前台（变为活跃状态）
    /// - Parameter notification: 通知对象
    @objc optional func applicationDidBecomeActive(_ notification: Notification)

    /// Application 将要失去活跃状态
    /// - Parameter notification: 通知对象
    @objc optional func applicationWillResignActive(_ notification: Notification)

    /// Application 将要终止
    /// - Parameter notification: 通知对象
    @objc optional func applicationWillTerminate(_ notification: Notification)
#endif
}
