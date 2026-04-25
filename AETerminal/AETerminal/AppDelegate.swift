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

        AENetHttpEngine.configure(config: AENetConfig(host: "127.0.0.1", port: 9000))

    }

    /// 注册模块
    private func registerModules() {
        // 注册网络模块
        AEModuleCenter.register(module: AEAINetworkModule())

        // 可以在这里注册其他模块
        // AEModuleCenter.register(module: OtherModule())
    }
}

