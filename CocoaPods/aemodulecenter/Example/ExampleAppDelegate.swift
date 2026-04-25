//
//  ExampleAppDelegate.swift
//  AEModuleCenter Example
//
//  Created on 2026/04/14.
//

import UIKit
// import AEModuleCenter  // 在实际项目中取消注释

@main
class ExampleAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // MARK: - Module Instances
    // 保持对模块的强引用，防止被提前释放

    private let analyticsModule = AnalyticsModule()
    private let networkModule = NetworkModule()
    private let pushModule = PushNotificationModule()
    private let databaseModule = DatabaseModule()
    private let customModule = ExampleModule(name: "CustomModule")

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        print("=== AppDelegate: Application Starting ===\n")

        // 1. 注册所有模块
        registerModules()

        // 2. 转发启动事件到所有模块
        let result = AEModuleCenter.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        print("\n=== AppDelegate: All modules initialized ===")
        print("Total registered modules: \(AEModuleCenter.shared.moduleCount)\n")

        return result
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("\n=== AppDelegate: Will Enter Foreground ===")
        AEModuleCenter.shared.applicationWillEnterForeground(application)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("\n=== AppDelegate: Did Become Active ===")
        AEModuleCenter.shared.applicationDidBecomeActive(application)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("\n=== AppDelegate: Will Resign Active ===")
        AEModuleCenter.shared.applicationWillResignActive(application)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("\n=== AppDelegate: Did Enter Background ===")
        AEModuleCenter.shared.applicationDidEnterBackground(application)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("\n=== AppDelegate: Will Terminate ===")
        AEModuleCenter.shared.applicationWillTerminate(application)

        // 可选：清理所有模块
        // AEModuleCenter.shared.unregisterAll()
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("\n=== AppDelegate: ⚠️ Memory Warning ===")
        AEModuleCenter.shared.applicationDidReceiveMemoryWarning(application)
    }

    // MARK: - Remote Notification

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("\n=== AppDelegate: Did Register For Remote Notifications ===")
        AEModuleCenter.shared.application(
            application,
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("\n=== AppDelegate: Failed To Register For Remote Notifications ===")
        AEModuleCenter.shared.application(
            application,
            didFailToRegisterForRemoteNotificationsWithError: error
        )
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("\n=== AppDelegate: Did Receive Remote Notification ===")
        AEModuleCenter.shared.application(
            application,
            didReceiveRemoteNotification: userInfo,
            fetchCompletionHandler: completionHandler
        )
    }

    // MARK: - URL Handling

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("\n=== AppDelegate: Open URL: \(url) ===")
        return AEModuleCenter.shared.application(app, open: url, options: options)
    }

    // MARK: - User Activity

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        print("\n=== AppDelegate: Continue User Activity ===")
        return AEModuleCenter.shared.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
    }

    // MARK: - Private Methods

    private func registerModules() {
        print("Registering modules...\n")

        // 注册所有模块
        let modules: [AEModuleProtocol] = [
            analyticsModule,
            networkModule,
            pushModule,
            databaseModule,
            customModule
        ]

        for module in modules {
            let success = AEModuleCenter.shared.register(module: module)
            if success {
                print("✅ Registered: \(type(of: module))")
            } else {
                print("❌ Failed to register: \(type(of: module))")
            }
        }

        print("")
    }

    // MARK: - Dynamic Module Management Example

    /// 动态添加模块的示例
    func addNewModule() {
        let newModule = ExampleModule(name: "DynamicModule")
        let success = AEModuleCenter.shared.register(module: newModule)
        print(success ? "✅ Dynamic module added" : "❌ Failed to add dynamic module")
    }

    /// 移除模块的示例
    func removeModule() {
        let success = AEModuleCenter.shared.unregister(module: customModule)
        print(success ? "✅ Module removed" : "❌ Failed to remove module")
        print("Remaining modules: \(AEModuleCenter.shared.moduleCount)")
    }
}
