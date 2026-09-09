//
//  AEPacketError.swift
//  AENetworkEngine
//
//  Created on 2026/04/26.
//

import Foundation

// MARK: - 错误类型

/// 数据包错误类型
public enum AEPacketError: Error, LocalizedError {
    case insufficientData(expected: Int, actual: Int)
    case invalidMagicCode(expected: UInt16, actual: UInt16)
    case checksumMismatch(expected: UInt16, actual: UInt16)
    case invalidDataType(value: UInt8)

    public var errorDescription: String? {
        switch self {
        case .insufficientData(let expected, let actual):
            return "数据长度不足，需要至少 \(expected) 字节，实际 \(actual) 字节"
        case .invalidMagicCode(let expected, let actual):
            return String(format: "无效的魔数: 0x%04X, 期望: 0x%04X", actual, expected)
        case .checksumMismatch(let expected, let actual):
            return String(format: "数据校验失败: 期望 0x%04X, 实际 0x%04X", expected, actual)
        case .invalidDataType(let value):
            return String(format: "无效的数据类型: 0x%02X", value)
        }
    }
}
