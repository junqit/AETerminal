//
//  AECloudStorageProtocol.swift
//  AECloudStorage
//
//  Created on 2026/09/08.
//

import Foundation
import AEModuleCenter

/// 云存储模块能力协议（继承 AEModuleProtocol；用户注册 + 文件上传）
public protocol AECloudStorageProtocol: AEModuleProtocol {

    /// 注册用户 id（绑定当前云存储用户）
    /// - Parameter userId: 用户唯一标识
    func register(userId: String)

    /// 上传文件/数据流
    /// - Parameter request: 上传描述（name=文件名、path=远端路径、source=本地路径或字节流）
    /// - Returns: provider 原始响应
    @discardableResult
    func upload(_ request: AECloudUpload) async throws -> [String: Any]
}
