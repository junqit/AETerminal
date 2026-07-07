//
//  AEUserAccountModule.swift
//  AEUserAccountModule
//
//  Created on 2026/5/15.
//

import Foundation
import AEModuleCenter
import AELogProxy

/// 用户账号模块 - 管理用户 uid、ident 等账号信息
public class AEUserAccountModule: NSObject, AEModuleProtocol, AEUserAccountModuleProtocol {

    // MARK: - Properties

    public private(set) var uid: String?
    public private(set) var ident: String?

    public var isLoggedIn: Bool {
        return uid != nil && ident != nil
    }

    // MARK: - AEModuleProtocol Lifecycle

#if os(macOS)
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AELog("[AEUserAccountModule] 模块已启动")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AELog("[AEUserAccountModule] 模块将终止")
    }
#endif

#if os(iOS)
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AELog("[AEUserAccountModule] 模块已启动")
        return true
    }
#endif

    // MARK: - AEModuleAccountProtocol

    public func userDidLogin() {
        AELog("[AEUserAccountModule] 收到用户登录通知, uid=\(uid ?? "nil"), ident=\(ident ?? "nil")")
    }

    public func userDidLogout() {
        logout()
    }

    public func userInfoDidUpdate() {
        AELog("[AEUserAccountModule] 用户信息已更新, uid=\(uid ?? "nil"), ident=\(ident ?? "nil")")
    }

    // MARK: - AEUserAccountModuleProtocol

    public func login(uid: String, ident: String) {
        self.uid = uid
        self.ident = ident
        AELog("[AEUserAccountModule] 用户登录: uid=\(uid), ident=\(ident)")
        AEModuleCenter.userDidLogin()
    }

    public func logout() {
        let previousUid = uid
        self.uid = nil
        self.ident = nil
        AELog("[AEUserAccountModule] 用户退出登录: previousUid=\(previousUid ?? "nil")")
        AEModuleCenter.userDidLogout()
    }
}
