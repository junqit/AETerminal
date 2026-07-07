//
//  AEInfoMap.swift
//  AEFoundation
//
//  Created by Claude on 2026/4/29.
//

import Foundation

/// 信息映射协议
/// 定义对象转换为字典映射的能力
public protocol AEInfoProtocol {

    /// 将对象转换为字典映射
    /// - Returns: 包含对象信息的字典
    func toInfoMap() -> [String: Any]
}

/// AEInfoMapProtocol 的默认实现扩展
public extension AEInfoProtocol {

    /// 将对象信息转换为 JSON 字符串
    /// - Returns: JSON 格式的字符串，如果转换失败则返回 nil
    func toJSONString() -> String? {
        let infoMap = toInfoMap()

        guard let jsonData = try? JSONSerialization.data(withJSONObject: infoMap, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    /// 将对象信息转换为 JSON Data
    /// - Returns: JSON 格式的 Data，如果转换失败则返回 nil
    func toJSONData() -> Data? {
        let infoMap = toInfoMap()
        return try? JSONSerialization.data(withJSONObject: infoMap, options: [])
    }
}
