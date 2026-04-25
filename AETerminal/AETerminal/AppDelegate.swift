//
//  AppDelegate.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AEModuleCenter
import AEAINetworkModule
import AENetworkEngine

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// 网络模块实例（保持强引用）
    private let networkModule = AEAINetworkModule()

    func applicationWillFinishLaunching(_ notification: Notification) {
        
        // 2. 注册模块到 AEModuleCenter
        registerModules()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 1. 配置网络模块
        configureNetworkModule()

        // 3. 转发生命周期事件到 AEModuleCenter
        AEModuleCenter.applicationDidFinishLaunching(aNotification)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 转发生命周期事件到 AEModuleCenter
        AEModuleCenter.applicationWillTerminate(aNotification)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 转发生命周期事件到 AEModuleCenter
        AEModuleCenter.applicationDidBecomeActive(notification)
    }

    func applicationWillResignActive(_ notification: Notification) {
        // 转发生命周期事件到 AEModuleCenter
        AEModuleCenter.applicationWillResignActive(notification)
    }

    // MARK: - Private Methods

    /// 配置网络模块
    private func configureNetworkModule() {
        
        AENetHttpEngine.configure(config: AENetHttpConfig(baseURL: "http://127.0.0.1:9000"))

        // 配置 UDP 网络参数
        // TODO: 根据实际需求修改服务器地址和端口
        networkModule.configure(
            serverHost: "127.0.0.1",  // 服务器地址
            serverPort: 9000           // 服务器端口
        )
    }

    /// 注册模块
    private func registerModules() {
        // 注册网络模块
        AEModuleCenter.register(module: networkModule)

        // 可以在这里注册其他模块
        // AEModuleCenter.register(module: OtherModule())
    }
}

