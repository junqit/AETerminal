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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 1. 先注册模块到 AEModuleCenter（由 AEModuleCenter 持有）
        registerModules()

        // 2. 再配置网络模块（通过协议获取模块实例）
        configureNetworkModule()

        print("✅ 模块注册和配置完成")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 3. 转发生命周期事件到 AEModuleCenter，触发模块初始化
        AEModuleCenter.applicationDidFinishLaunching(aNotification)

        print("✅ 生命周期事件已转发")

        // 4. 验证模块是否可用
        if let networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self) {
            print("✅ AppDelegate 中可以获取到网络服务")
        } else {
            print("❌ AppDelegate 中获取不到网络服务")
        }
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

    /// 注册模块
    private func registerModules() {
        // 注册网络模块（由 AEModuleCenter 持有）
        AEModuleCenter.register(module: AEAINetworkModule())

        // 可以在这里注册其他模块
        // AEModuleCenter.register(module: OtherModule())
    }

    /// 配置网络模块
    private func configureNetworkModule() {
        // 通过 AEModuleCenter 获取网络模块
        guard let networkModule = AEModuleCenter.module(for: AEAINetworkProtocol.self) else {
            print("❌ 获取网络模块失败")
            return
        }

        // 配置 HTTP
        let httpConfig = AENetConfig(type: .http, host: "127.0.0.1", port: 9000)
        networkModule.configure(with: httpConfig)

        // 配置 Socket
        let socketConfig = AENetConfig(type: .socket, host: "127.0.0.1", port: 8888)
        networkModule.configure(with: socketConfig)
    }
}

