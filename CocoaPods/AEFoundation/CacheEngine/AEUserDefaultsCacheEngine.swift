//
//  AEUserDefaultsCacheEngine.swift
//  AEFoundation
//
//  基于 UserDefaults 的缓存引擎
//

import Foundation

/// 基于 UserDefaults 的缓存引擎
public class AEUserDefaultsCacheEngine: AECacheEngineProtocol {

    /// 唯一标识（用于命名空间隔离）
    private let identifier: String

    /// UserDefaults 实例
    private let userDefaults: UserDefaults

    /// 初始化
    /// - Parameter identifier: 唯一标识
    public init(identifier: String) {
        self.identifier = identifier
        self.userDefaults = UserDefaults.standard
    }

    /// 生成带命名空间的 key
    private func namespacedKey(_ key: String) -> String {
        return "\(identifier).\(key)"
    }

    public func set<T: Codable>(_ value: T, forKey key: String) {
        let nsKey = namespacedKey(key)

        // 编码为 Data
        if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: nsKey)
        }
    }

    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let nsKey = namespacedKey(key)

        guard let data = userDefaults.data(forKey: nsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    public func remove(forKey key: String) {
        let nsKey = namespacedKey(key)
        userDefaults.removeObject(forKey: nsKey)
    }

    public func removeAll() {
        // 获取所有 key，删除属于当前 identifier 的
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefix = "\(identifier)."

        for key in allKeys where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func exists(forKey key: String) -> Bool {
        let nsKey = namespacedKey(key)
        return userDefaults.object(forKey: nsKey) != nil
    }
}
