//
//  AEStorageInterface.swift
//  AECloudStorage
//
//  Created on 2026/09/08.
//

import Foundation

/// 存储接口（provider 协议；baseDir 沙盒，具体 storage 实现各操作）
public protocol AEStorageInterface: AnyObject {

    /// 唯一标识
    var uid: String { get }

    /// provider 名称
    var name: String { get }

    /// 根目录（沙盒）
    var baseDir: String { get }

    /// 是否已加载（鉴权/初始化完成）
    var isLoaded: Bool { get }

    /// 首次鉴权/初始化校验（刷新 token、标记 isLoaded）
    /// - Returns: 是否鉴权成功
    func verify() async -> Bool

    /// 上传本地文件到远端
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远端路径（相对 baseDir）
    /// - Returns: provider 原始响应
    func upload(localPath: String, remotePath: String) async throws -> [String: Any]

    /// 下载远端文件到本地
    /// - Parameters:
    ///   - remotePath: 远端路径
    ///   - localPath: 本地保存路径
    /// - Returns: 本地保存路径
    func download(remotePath: String, localPath: String) async throws -> String

    /// 列出远端目录文件
    /// - Parameter remoteDir: 远端目录
    /// - Returns: 文件节点列表
    func listFiles(remoteDir: String) async throws -> [AECloudFile]

    /// 删除远端文件
    func delete(remotePath: String) async throws -> [String: Any]

    /// 创建远端目录
    func mkdir(remotePath: String) async throws -> [String: Any]

    /// 远端路径是否存在
    func exists(remotePath: String) async throws -> Bool
}

// MARK: - 默认实现

public extension AEStorageInterface {

    /// 状态信息
    func getStatus() -> [String: Any] {

        return [
            "uid": uid,
            "name": name,
            "baseDir": baseDir,
            "loaded": isLoaded
        ]
    }

    /// 解析路径（沙盒拼接）：相对路径拼接到 baseDir；绝对路径须在 baseDir 内；空/"/" 返回 baseDir
    func resolvePath(_ remotePath: String) -> String {

        let base = baseDir
        let trimmed = remotePath.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || trimmed == "/" {
            return base
        }

        // 绝对路径：须在 baseDir 内
        if trimmed.hasPrefix("/") {
            if trimmed == base { return base }
            if trimmed.hasPrefix(base + "/") { return trimmed }
            return base + trimmed
        }

        // 相对路径：拼接到 baseDir
        return base + "/" + trimmed
    }
}
