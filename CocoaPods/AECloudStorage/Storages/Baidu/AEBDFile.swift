//
//  AEBDFile.swift
//  AECloudStorage
//
//  Created on 2026/09/05.
//

import Foundation
import AELogProxy

/// 百度网盘文件节点（值 + CRUD 能力，委托 storage 执行操作）
public final class AEBDFile {

    /// 文件节点值
    public var file: AECloudFile

    /// 所属 storage（注入，CRUD 委托给它）
    public weak var storage: AEBaiduStorage?

    // MARK: - Init

    public init(file: AECloudFile, storage: AEBaiduStorage? = nil) {

        self.file = file
        self.storage = storage
    }

    /// 便捷构造（name/type/path + storage）
    public convenience init(name: String,
                            type: AECloudFileType,
                            path: String,
                            storage: AEBaiduStorage? = nil) {

        let f = AECloudFile(name: name,
                            type: type,
                            path: path,
                            parent: AECloudFile.parentOf(path))
        self.init(file: f, storage: storage)
    }

    // MARK: - Raw → AECloudFile

    /// 由百度原始字段构造 AECloudFile（isdir/server_filename/size/md5/path）
    public static func fromDict(_ data: [String: Any]) -> AECloudFile? {

        let isdirValue = (data["isdir"] as? Int)
            ?? (data["is_dir"] as? Int)
            ?? (((data["type"] as? String) == "folder") ? 1 : 0)
        let isFolder = isdirValue != 0

        let path = data["path"] as? String
        let name = (data["server_filename"] as? String)
            ?? (data["filename"] as? String)
            ?? (data["name"] as? String)
            ?? ""

        return AECloudFile(
            name: name,
            type: isFolder ? .folder : .file,
            size: Int64((data["size"] as? Int) ?? 0),
            hash: (data["md5"] as? String) ?? (data["sha"] as? String) ?? (data["sha1"] as? String),
            path: path,
            parent: (data["parent"] as? String) ?? AECloudFile.parentOf(path ?? ""),
            children: []
        )
    }

    // MARK: - CRUD（委托 storage）

    /// 创建（文件夹 → mkdir；文件 → upload，需 localPath）
    public func create(localPath: String? = nil) async throws -> Any {

        guard let storage = storage, let path = file.path else {
            throw NSError(domain: "AEBDFile", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "无 storage 或 path"])
        }

        if file.isFolder {
            return try await storage.mkdir(remotePath: path)
        }
        guard let localPath = localPath else {
            throw NSError(domain: "AEBDFile", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "文件创建需 localPath"])
        }
        return try await storage.upload(localPath: localPath, remotePath: path)
    }

    /// 读取（文件夹 → 列子文件；文件 → 空）
    public func read() async throws -> [AECloudFile] {

        guard let storage = storage, let path = file.path else {
            throw NSError(domain: "AEBDFile", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "无 storage 或 path"])
        }
        if file.isFile { return [] }
        return try await storage.listFiles(remoteDir: path)
    }

    /// 下载到本地
    public func download(localPath: String) async throws -> String {

        guard let storage = storage, let path = file.path else {
            throw NSError(domain: "AEBDFile", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "无 storage 或 path"])
        }
        return try await storage.download(remotePath: path, localPath: localPath)
    }

    /// 删除（百度暂未实现 → 抛 NotImplemented）
    public func delete() async throws -> Any {

        guard let storage = storage, let path = file.path else {
            throw NSError(domain: "AEBDFile", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "无 storage 或 path"])
        }
        return try await storage.delete(remotePath: path)
    }
}
