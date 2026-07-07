//
//  AECacheEngineProtocol.swift
//  AEFoundation
//
//  缓存引擎协议
//

import Foundation

/// 缓存引擎协议
public protocol AECacheEngineProtocol {

    /// 存储数据
    /// - Parameters:
    ///   - value: 要存储的值
    ///   - key: 键
    func set<T: Codable>(_ value: T, forKey key: String)

    /// 读取数据
    /// - Parameters:
    ///   - key: 键
    ///   - type: 数据类型
    /// - Returns: 存储的值，如果不存在返回 nil
    func get<T: Codable>(_ key: String, as type: T.Type) -> T?

    /// 删除数据
    /// - Parameter key: 键
    func remove(forKey key: String)

    /// 清空所有数据
    func removeAll()

    /// 判断是否存在
    /// - Parameter key: 键
    /// - Returns: 是否存在
    func exists(forKey key: String) -> Bool
}
