//
//  AEUserAccountModuleProtocol.swift
//  AEUserAccountModule
//
//  Created on 2026/5/15.
//

import Foundation
import AEModuleCenter
import AEFoundation
import AELogProxy

/// 用户账号模块协议，提供用户 uid、ident 等账号信息
public protocol AEUserAccountModuleProtocol: AEModuleProtocol, AEInfoProtocol {

    /// 当前用户 uid（未登录时为 nil）
    var uid: String? { get }

    /// 当前用户 ident 标识（未登录时为 nil）
    var ident: String? { get }

    /// 当前用户是否已登录
    var isLoggedIn: Bool { get }

    /// 登录
    /// - Parameters:
    ///   - uid: 用户 uid
    ///   - ident: 用户 ident 标识
    func login(uid: String, ident: String)

    /// 退出登录
    func logout()
}

// MARK: - AEInfoProtocol

public extension AEUserAccountModuleProtocol {

    func toInfoMap() -> [String: Any] {
        var info: [String: Any] = [:]

        if let uid = uid, !uid.isEmpty {
            info["uid"] = uid
        } else {
            AELog("⚠️ [AEUserAccount] toInfoMap: uid 为空")
        }

        if let ident = ident, !ident.isEmpty {
            info["ident"] = ident
        } else {
            AELog("⚠️ [AEUserAccount] toInfoMap: ident 为空")
        }

        return info
    }
}
