//
//  AEFileCacheEngine.swift
//  AEFoundation
//
//  基于文件系统的缓存引擎
//

import Foundation

/// 基于文件系统的缓存引擎
public class AEFileCacheEngine: AECacheEngineProtocol {

    /// 唯一标识（用于命名空间隔离）
    private let identifier: String

    /// 缓存目录
    private let cacheDirectory: URL

    /// 文件管理器
    private let fileManager = FileManager.default

    /// 初始化
    /// - Parameter identifier: 唯一标识
    public init(identifier: String) {
        self.identifier = identifier

        // 创建缓存目录：~/Library/Caches/AEFoundation/{identifier}/
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDirectory
            .appendingPathComponent("AEFoundation")
            .appendingPathComponent(identifier)

        // 创建目录（如果不存在）
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// 获取文件 URL
    private func fileURL(forKey key: String) -> URL {
        // 对 key 进行编码，避免特殊字符
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent("\(safeKey).cache")
    }

    public func set<T: Codable>(_ value: T, forKey key: String) {
        let fileURL = fileURL(forKey: key)

        // 编码为 Data
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let fileURL = fileURL(forKey: key)

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    public func remove(forKey key: String) {
        let fileURL = fileURL(forKey: key)
        try? fileManager.removeItem(at: fileURL)
    }

    public func removeAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        // 重新创建目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    public func exists(forKey key: String) -> Bool {
        let fileURL = fileURL(forKey: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
