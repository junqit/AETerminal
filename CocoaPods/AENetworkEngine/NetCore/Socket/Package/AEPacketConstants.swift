//
//  AEPacketConstants.swift
//  AENetworkEngine
//
//  Created on 2026/04/26.
//

import Foundation

// MARK: - 协议常量

/// 魔数：0x1EAE
/// 0x1E = ASCII Record Separator (RS) 控制字符
/// 0xAE = 扩展ASCII字符
public let MAGIC_CODE: UInt16 = 0x1EAE

/// 2 字节无符号最值
public let MIN_UINT16: UInt16 = 0x0000
public let MAX_UINT16: UInt16 = 0xFFFF

/// 单包 Data 最大长度：2 字节上限 0xFFFF 扣除 UDP 头(8) + AEPacket 包头(10)
/// 该值 0xFFED 的二进制第 4 位（0x10）为 0
public let MAX_PACKET_DATA_LENGTH: Int = 1024 * 4//Int(MAX_UINT16) - 8 - 10

/// 末包分片序号：packetSeq 从 255 倒数，末包恒为 255；接收侧据此判定末包（不再使用标志位）
public let LAST_PACKET_SEQ: UInt8 = 255

/// UniqueID 哨兵值：0 表示非分片单包（无唯一标识需求）
public let UNIQUE_ID_SENTINEL: UInt16 = MIN_UINT16

/// DataType 字节低 4 位为数据类型，高 4 位为标志位
public let DATA_TYPE_MASK: UInt8 = 0x0F

/// 包标志位（DataType 字节高 4 位）；多个标志位可按位或组合，运算时取 rawValue
public enum AEFlag: UInt8 {
    /// 保留标志位：第 5 位（0x20），预留给压缩标志
    case compressed = 0x20

    /// 保留标志位：第 6 位（0x40），预留给加密标志
    case encrypted = 0x40

    /// 保留标志位：第 7 位（0x80），预留给扩展用途
    case reserved = 0x80
}

/// 数据类型枚举
/// DataType 字节低 4 位表示数据类型（取值 0x0~0xF），高 4 位保留（可用于标志位）。
/// 解析时用 DATA_TYPE_MASK 取低 4 位再匹配枚举。
public enum AEDataType: UInt8 {
    case data = 0x00       // 数据
    case heartbeat = 0x01  // 心跳包
    case ping = 0x02       // Ping
    case pong = 0x03       // Pong
}
