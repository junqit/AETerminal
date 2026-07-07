//
//  ExampleModule.swift
//  AEModuleCenter Example
//
//  Created on 2026/04/14.
//

import Foundation
import UIKit
import AELogProxy
// import AEModuleCenter  // 在实际项目中取消注释

/// 示例模块 - 展示如何实现 AEModuleProtocol
class ExampleModule: NSObject, AEModuleProtocol {

    // MARK: - Properties

    private let moduleName: String

    // MARK: - Initialization

    init(name: String) {
        self.moduleName = name
        super.init()
        AELog("[\(moduleName)] Module initialized")
    }

    deinit {
        AELog("[\(moduleName)] Module deinitialized")
    }

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[\(moduleName)] Application did finish launching")

        // 模拟一些初始化工作
        setupModule()

        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AELog("[\(moduleName)] Application will enter foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AELog("[\(moduleName)] Application did become active")
        // 刷新数据或恢复操作
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AELog("[\(moduleName)] Application will resign active")
        // 暂停操作
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AELog("[\(moduleName)] Application did enter background")
        // 保存状态
        saveState()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AELog("[\(moduleName)] Application will terminate")
        // 清理资源
        cleanup()
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AELog("[\(moduleName)] ⚠️ Received memory warning")
        // 清理缓存
        clearCache()
    }

    // MARK: - Private Methods

    private func setupModule() {
        AELog("[\(moduleName)] Setting up module...")
    }

    private func saveState() {
        AELog("[\(moduleName)] Saving state...")
    }

    private func cleanup() {
        AELog("[\(moduleName)] Cleaning up...")
    }

    private func clearCache() {
        AELog("[\(moduleName)] Clearing cache...")
    }
}

// MARK: - Analytics Module Example

class AnalyticsModule: NSObject, AEModuleProtocol {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[Analytics] Initializing analytics SDK...")
        // Analytics.initialize(apiKey: "your-api-key")
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AELog("[Analytics] Tracking app_active event")
        // Analytics.track(event: "app_active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AELog("[Analytics] Tracking app_background event")
        // Analytics.track(event: "app_background")
    }
}

// MARK: - Network Module Example

class NetworkModule: NSObject, AEModuleProtocol {

    private var isMonitoring = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[Network] Starting network monitoring...")
        startMonitoring()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AELog("[Network] Stopping network monitoring...")
        stopMonitoring()
    }

    private func startMonitoring() {
        isMonitoring = true
        // NetworkReachability.shared.startMonitoring()
    }

    private func stopMonitoring() {
        isMonitoring = false
        // NetworkReachability.shared.stopMonitoring()
    }
}

// MARK: - Push Notification Module Example

class PushNotificationModule: NSObject, AEModuleProtocol {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[Push] Requesting push notification authorization...")
        requestAuthorization(application: application)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AELog("[Push] Registered with device token: \(token)")
        // 上传 token 到服务器
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AELog("[Push] ❌ Failed to register: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AELog("[Push] Received remote notification: \(userInfo)")

        // 处理推送通知
        handleRemoteNotification(userInfo) { success in
            completionHandler(success ? .newData : .failed)
        }
    }

    private func requestAuthorization(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                AELog("[Push] ❌ Authorization error: \(error)")
                return
            }

            if granted {
                AELog("[Push] ✅ Authorization granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                AELog("[Push] ❌ Authorization denied")
            }
        }
    }

    private func handleRemoteNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void) {
        // 模拟异步处理
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            AELog("[Push] Notification processed successfully")
            completion(true)
        }
    }
}

// MARK: - Database Module Example

class DatabaseModule: NSObject, AEModuleProtocol {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[Database] Initializing database...")
        setupDatabase()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AELog("[Database] Performing background sync...")
        performBackgroundSync()
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AELog("[Database] ⚠️ Clearing database cache...")
        clearDatabaseCache()
    }

    private func setupDatabase() {
        // Database.setup()
    }

    private func performBackgroundSync() {
        // Database.sync()
    }

    private func clearDatabaseCache() {
        // Database.clearCache()
    }
}
