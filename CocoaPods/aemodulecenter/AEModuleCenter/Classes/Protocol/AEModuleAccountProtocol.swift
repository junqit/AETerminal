//
//  AEModuleAccountProtocol.swift
//  AEModuleCenter
//
//  Created by Claude on 2026/5/9.
//

import Foundation

/// 用户账号状态变更消息转发协议
@objc public protocol AEModuleAccountProtocol: AnyObject {

    /// 用户登录成功
    @objc optional func userDidLogin()

    /// 用户退出登录
    @objc optional func userDidLogout()

    /// 用户信息发生变更
    @objc optional func userInfoDidUpdate()
}
