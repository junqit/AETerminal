//
//  AEWebModule.swift
//  AEWebModule
//
//  Created on 2026/09/08.
//

import Foundation
import AEModuleCenter

/// Web 模块 - 管理内嵌 WKWebView，提供打开网址能力
public final class AEWebModule: NSObject, AEModuleProtocol, AEWebModuleProtocol {

    // MARK: - Properties

    /// 嵌入用的 Web 控制器（caller 嵌入 controller.view）
    public let controller: AEWebViewController

    // MARK: - Initialization

    public override init() {
        self.controller = AEWebViewController()
        super.init()
    }

    // MARK: - AEModuleProtocol - Lifecycle

#if os(macOS)
    /// Application 启动完成（macOS）- Web 按需载入，启动无需预热
    public func applicationDidFinishLaunching(_ notification: Notification) {
    }
#endif

#if os(iOS)
    /// Application 启动完成（iOS）- Web 按需载入，启动无需预热
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
#endif

    // MARK: - AEWebModuleProtocol

    /// 打开网址（载入已嵌入的 WebView）
    /// - Parameter url: 要打开的网址
    public func open(url: URL) {
        controller.load(url: url)
    }
}
