//
//  AEModulePrivacyProtocol.swift
//  AEModuleCenter
//
//  Created by Claude on 2026/5/9.
//

import Foundation

/// 隐私协议弹框消息转发协议
@objc public protocol AEModulePrivacyProtocol: AnyObject {

    /// 用户同意隐私协议
    @objc optional func privacyDidAgree()

    /// 用户拒绝隐私协议
    @objc optional func privacyDidDecline()

    /// 隐私协议弹框即将展示
    @objc optional func privacyWillShow()

    /// 隐私协议弹框已关闭
    @objc optional func privacyDidDismiss()
}
