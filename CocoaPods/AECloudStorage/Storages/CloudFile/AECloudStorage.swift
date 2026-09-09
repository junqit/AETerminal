//
//  AECloudStorage.swift
//  AECloudStorage
//
//  Created on 2026/09/05.
//

import Foundation
import AELogProxy

/// 云文件数据源（上传用：本地文件路径 或 字节流）
public enum AECloudFileSource {

    /// 本地文件路径
    case localPath(String)

    /// 字节流
    case data(Data)
}

/// 云文件节点（cloud-agnostic 值对象，支持 children 组合树）
public struct AECloudFile {

    public var name: String
    public var type: AECloudFileType
    public var size: Int64
    public var hash: String?
    public var path: String?
    public var parent: String?
    public var children: [AECloudFile]

    public init(name: String = "",
                type: AECloudFileType = .file,
                size: Int64 = 0,
                hash: String? = nil,
                path: String? = nil,
                parent: String? = nil,
                children: [AECloudFile] = []) {

        self.name = name
        self.type = type
        self.size = size
        self.hash = hash
        self.path = path
        self.parent = parent
        self.children = children
    }

    public var isFolder: Bool { type == .folder }

    public var isFile: Bool { type == .file }

    public mutating func addChild(_ child: AECloudFile) {
        children.append(child)
    }

    /// 由路径推导父目录（最后一个 / 前的内容；根 → nil）
    public static func parentOf(_ path: String) -> String? {

        guard !path.isEmpty, path != "/" else { return nil }

        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let lastSlash = trimmed.lastIndex(of: "/") else { return nil }

        let parent = String(trimmed[..<lastSlash])
        return parent.isEmpty ? nil : parent
    }
}

/// 云文件上传描述（精简：文件名 + 远端路径 + 数据源）
public struct AECloudUpload {

    /// 文件名
    public var name: String

    /// 远端路径（相对 baseDir）
    public var path: String

    /// 数据源（本地文件路径 或 字节流）
    public var source: AECloudFileSource

    public init(name: String, path: String, source: AECloudFileSource) {

        self.name = name
        self.path = path
        self.source = source
    }
}
