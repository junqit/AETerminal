//
//  AECacheEngine.swift
//  AEFoundation
//
//  缓存引擎管理类
//

import Foundation

/// 存储类型
public enum AECacheStorageType {
    /// UserDefaults 存储
    case userDefaults
    /// 文件存储
    case file
    /// 数据库存储
    case database
}

/// 缓存引擎管理类
public class AECacheEngine {

    /// 唯一标识
    private let identifier: String

    /// 存储类型
    private let storageType: AECacheStorageType

    /// 内部引擎
    private let engine: AECacheEngineProtocol

    /// 初始化
    /// - Parameters:
    ///   - identifier: 唯一标识（如用户ID、模块名等）
    ///   - storageType: 存储类型
    public init(identifier: String, storageType: AECacheStorageType = .file) {
        self.identifier = identifier
        self.storageType = storageType

        // 根据类型创建对应的引擎
        switch storageType {
        case .userDefaults:
            self.engine = AEUserDefaultsCacheEngine(identifier: identifier)
        case .file:
            self.engine = AEFileCacheEngine(identifier: identifier)
        case .database:
            self.engine = AEDBCacheEngine(identifier: identifier)
        }
    }

    // MARK: - Public Methods

    /// 存储数据
    /// - Parameters:
    ///   - value: 要存储的值（必须遵循 Codable）
    ///   - key: 键
    public func set<T: Codable>(_ value: T, forKey key: String) {
        engine.set(value, forKey: key)
    }

    /// 读取数据
    /// - Parameters:
    ///   - key: 键
    ///   - type: 数据类型
    /// - Returns: 存储的值，如果不存在返回 nil
    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        return engine.get(key, as: type)
    }

    /// 删除数据
    /// - Parameter key: 键
    public func remove(forKey key: String) {
        engine.remove(forKey: key)
    }

    /// 清空所有数据
    public func removeAll() {
        engine.removeAll()
    }

    /// 判断是否存在
    /// - Parameter key: 键
    /// - Returns: 是否存在
    public func exists(forKey key: String) -> Bool {
        return engine.exists(forKey: key)
    }

    // MARK: - Static Methods

    /// 删除指定 identifier 下所有存储类型的数据（file、database、userDefaults）
    /// - Parameter identifier: 唯一标识
    public static func removeAll(forIdentifier identifier: String) {
        // 删除文件存储
        let fileEngine = AEFileCacheEngine(identifier: identifier)
        fileEngine.removeAll()

        // 删除数据库存储
        let dbEngine = AEDBCacheEngine(identifier: identifier)
        dbEngine.removeAll()

        // 删除 UserDefaults 存储
        let userDefaultsEngine = AEUserDefaultsCacheEngine(identifier: identifier)
        userDefaultsEngine.removeAll()
    }
}
