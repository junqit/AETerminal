//
//  AEPacket.swift
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
public let MAX_PACKET_DATA_LENGTH: Int = Int(MAX_UINT16) - 8 - 10

/// 末包掩码：MAX_PACKET_DATA_LENGTH 第 4 位置 1（0xFFED | 0x10 = 0xFFFD）
public let LAST_PACKET_MASK: UInt16 = 0xFFFD

/// UniqueID 哨兵值：0 表示非分片单包（无唯一标识需求）
public let UNIQUE_ID_SENTINEL: UInt16 = MIN_UINT16

/// DataType 字节低 4 位为数据类型，高 4 位为标志位
public let DATA_TYPE_MASK: UInt8 = 0x0F

/// 末包标志：第 4 位（0x10）。将该位置 1、其余位不变，表示该分片已是最后一包
/// 用法：末包 dataType = 类型值 | FLAG_LAST_FRAGMENT（如 RESPONSE 末包 = 0x02 | 0x10 = 0x12）
public let FLAG_LAST_FRAGMENT: UInt8 = 0x10

/// 数据类型枚举
/// DataType 字节低 4 位表示数据类型（取值 0x0~0xF），高 4 位保留（可用于标志位）。
/// 解析时用 DATA_TYPE_MASK 取低 4 位再匹配枚举。
public enum AEDataType: UInt8 {
    case request = 0x01    // 请求数据 (AENetReq)
    case response = 0x02   // 响应数据 (AENetRsp)
    case heartbeat = 0x03  // 心跳包
    case ping = 0x04       // Ping
    case pong = 0x05       // Pong
    case custom = 0x0F     // 自定义数据
}

// MARK: - 数据包头

/// 数据包头结构
///
/// 包结构：
/// ┌─────────────┬──────────┬───────────┬──────────┬──────────┬──────────┬──────────┐
/// │ Magic Code  │ DataType │ UniqueID  │ PacketSeq│  Length  │ Checksum │   Data   │
/// │   (2 bytes) │ (1 byte) │ (2 bytes) │ (1 byte) │ (2 bytes)│ (2 bytes)│ (N bytes)│
/// └─────────────┴──────────┴───────────┴──────────┴──────────┴──────────┴──────────┘
///
/// 总包头长度: 10 bytes
public struct AEPacketHeader {

    /// 魔数，固定为 0x1EAE，2 字节
    let magicCode: UInt16

    /// 数据类型（原始字节）：低 4 位为类型，高 4 位为标志位，1 字节
    let dataType: UInt8

    /// 唯一标识，同一消息的多个分片共用；0 (UNIQUE_ID_SENTINEL) 表示非分片单包，2 字节
    let uniqueId: UInt16

    /// 包次（分片序号，从 0 开始），1 字节
    let packetSeq: UInt8

    /// 本包数据长度（不包含包头），2 字节
    let length: UInt16

    /// 数据校验和（CRC16），2 字节
    let checksum: UInt16

    /// 包头固定长度
    static let headerSize: Int = 10  // 2 + 1 + 2 + 1 + 2 + 2

    /// 初始化包头
    init(dataType: UInt8, uniqueId: UInt16, packetSeq: UInt8, length: UInt16, checksum: UInt16) {
        self.magicCode = MAGIC_CODE
        self.dataType = dataType
        self.uniqueId = uniqueId
        self.packetSeq = packetSeq
        self.length = length
        self.checksum = checksum
    }

    /// 从字节流解析包头
    /// - Parameter data: 至少 10 字节的数据
    /// - Returns: 解析后的包头对象
    /// - Throws: 如果数据长度不足或魔数不匹配
    static func from(data: Data) throws -> AEPacketHeader {
        guard data.count >= headerSize else {
            throw AEPacketError.insufficientData(expected: headerSize, actual: data.count)
        }

        // 大端序（网络字节序）逐字节解包，避免未对齐指针 load 崩溃：H(2) B(1) H(2) B(1) H(2) H(2)
        let magicCode = (UInt16(data[0]) << 8) | UInt16(data[1])
        let dataType = data[2]
        let uniqueId = (UInt16(data[3]) << 8) | UInt16(data[4])
        let packetSeq = data[5]
        let length = (UInt16(data[6]) << 8) | UInt16(data[7])
        let checksum = (UInt16(data[8]) << 8) | UInt16(data[9])

        // 验证魔数
        guard magicCode == MAGIC_CODE else {
            throw AEPacketError.invalidMagicCode(expected: MAGIC_CODE, actual: magicCode)
        }

        return AEPacketHeader(
            dataType: dataType,
            uniqueId: uniqueId,
            packetSeq: packetSeq,
            length: length,
            checksum: checksum
        )
    }

    /// 将包头序列化为字节流
    /// - Returns: 10 字节的包头数据
    func toBytes() -> Data {
        var data = Data(capacity: AEPacketHeader.headerSize)

        // 大端序（网络字节序）
        var magicBE = magicCode.bigEndian
        var uniqueIdBE = uniqueId.bigEndian
        var lengthBE = length.bigEndian
        var checksumBE = checksum.bigEndian

        data.append(Data(bytes: &magicBE, count: 2))
        data.append(dataType)                       // 1 byte
        data.append(Data(bytes: &uniqueIdBE, count: 2))
        data.append(packetSeq)                      // 1 byte
        data.append(Data(bytes: &lengthBE, count: 2))
        data.append(Data(bytes: &checksumBE, count: 2))

        return data
    }

    /// 验证数据完整性（使用 CRC16）
    /// - Parameter data: 要验证的数据
    /// - Returns: 数据是否完整
    func validate(data: Data) -> Bool {
        return checksum == AEPacket.calculateCRC16(data: data)
    }

    /// 实际数据类型（低 4 位）
    var dataTypeValue: AEDataType? {
        return AEDataType(rawValue: dataType & DATA_TYPE_MASK)
    }

    /// 是否为末包（第 4 位置 1）
    var isLastFragment: Bool {
        return (dataType & FLAG_LAST_FRAGMENT) != 0
    }

    /// 是否为非分片单包
    var isSinglePacket: Bool {
        return uniqueId == UNIQUE_ID_SENTINEL
    }
}

// MARK: - 完整数据包

/// 完整的数据包
public struct AEPacket {

    /// 包头
    let header: AEPacketHeader

    /// 数据内容
    let data: Data

    /// 创建数据包
    /// - Parameters:
    ///   - dataType: 数据类型
    ///   - data: 数据内容
    ///   - uniqueId: 唯一标识（默认 UNIQUE_ID_SENTINEL 表示非分片单包）
    ///   - packetSeq: 包次（分片序号，从 0 开始）
    ///   - isLastFragment: 是否为末包（置位 FLAG_LAST_FRAGMENT）
    /// - Returns: 完整的数据包对象
    static func create(
        dataType: AEDataType,
        data: Data,
        uniqueId: UInt16 = UNIQUE_ID_SENTINEL,
        packetSeq: UInt8 = 0,
        isLastFragment: Bool = false
    ) -> AEPacket {
        // 末包：第 4 位置 1，其余位（类型位）不变
        let rawDataType = isLastFragment ? (dataType.rawValue | FLAG_LAST_FRAGMENT) : dataType.rawValue
        // 计算校验和（CRC16）
        let checksum = calculateCRC16(data: data)

        // 创建包头
        let header = AEPacketHeader(
            dataType: rawDataType,
            uniqueId: uniqueId,
            packetSeq: packetSeq,
            length: UInt16(data.count),
            checksum: checksum
        )

        return AEPacket(header: header, data: data)
    }

    /// 将数据包序列化为字节流
    /// - Returns: 完整的数据包字节流
    func toBytes() -> Data {
        var result = header.toBytes()
        result.append(data)
        return result
    }

    /// 从包头和数据创建数据包
    /// - Parameters:
    ///   - header: 已解析的包头
    ///   - data: 数据内容
    /// - Returns: 数据包对象
    /// - Throws: 如果校验失败
    static func from(header: AEPacketHeader, data: Data) throws -> AEPacket {
        // 验证数据完整性
        guard header.validate(data: data) else {
            let actualCRC = calculateCRC16(data: data)
            throw AEPacketError.checksumMismatch(expected: header.checksum, actual: actualCRC)
        }

        return AEPacket(header: header, data: data)
    }

    /// 计算数据的 CRC16 校验和（CRC-16/MODBUS）
    /// - Parameter data: 要计算校验和的数据
    /// - Returns: CRC16 校验和（0x0000 - 0xFFFF）
    static func calculateCRC16(data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF

        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 0x0001 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }

        return crc & 0xFFFF
    }

    // MARK: - 组装 packet 列表（data -> [AEPacket]）

    /// 分片 UniqueID 自增序号（跳过 0 哨兵值）
    private static var uniqueIdSeq: UInt16 = 0

    /// 生成下一个分片 UniqueID（1...MAX_UINT16，跳过 0 哨兵值）
    private static func nextUniqueId() -> UInt16 {
        uniqueIdSeq = uniqueIdSeq &+ 1               // UInt16 溢出回绕：65535 -> 0
        if uniqueIdSeq == UNIQUE_ID_SENTINEL {
            uniqueIdSeq = 1
        }
        return uniqueIdSeq
    }

    /// 由 data 转换为 AEPacket 列表（单包或分片），内聚处理 UniqueID 与末包标志。
    ///
    /// - data <= MAX_PACKET_DATA_LENGTH：单包，UniqueID 用哨兵值（接收侧直接分发，不进分片池）
    /// - data >  MAX_PACKET_DATA_LENGTH：分片，共用一个非哨兵 UniqueID，packetSeq 从 0 递增，
    ///   末包 dataType 第 4 位置 1（FLAG_LAST_FRAGMENT）
    ///
    /// - Parameters:
    ///   - dataType: 数据类型
    ///   - data: 待发送的完整数据
    /// - Returns: packet 列表（按发送顺序）
    static func packets(dataType: AEDataType, data: Data) -> [AEPacket] {
        var packets: [AEPacket] = []

        // 单包：无需分片，UniqueID 用哨兵值
        if data.count <= MAX_PACKET_DATA_LENGTH {
            packets.append(AEPacket.create(dataType: dataType, data: data))
            return packets
        }

        // 分片：共用 UniqueID，末包打标志
        let uniqueId = nextUniqueId()
        let total = (data.count + MAX_PACKET_DATA_LENGTH - 1) / MAX_PACKET_DATA_LENGTH
        for seq in 0..<total {
            let start = seq * MAX_PACKET_DATA_LENGTH
            let end = min(start + MAX_PACKET_DATA_LENGTH, data.count)
            let chunk = data.subdata(in: start..<end)
            packets.append(AEPacket.create(
                dataType: dataType,
                data: chunk,
                uniqueId: uniqueId,
                packetSeq: UInt8(seq),
                isLastFragment: (seq == total - 1)
            ))
        }
        return packets
    }
}

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
