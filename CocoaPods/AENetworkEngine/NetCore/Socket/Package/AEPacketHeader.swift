//
//  AEPacketHeader.swift
//  AENetworkEngine
//
//  Created on 2026/04/26.
//

import Foundation

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

    /// 数据类型（低 4 位），1 字节中的低 4 位
    let dataType: AEDataType

    /// 标志位（高 4 位）：bit4 闲置、bit5=压缩、bit6=加密、bit7=保留
    private var flags: UInt8

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
    init(dataType: AEDataType, flags: UInt8 = 0, uniqueId: UInt16, packetSeq: UInt8, length: UInt16, checksum: UInt16) {
        self.magicCode = MAGIC_CODE
        self.dataType = dataType
        self.flags = flags
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
        let dataTypeByte = data[2]
        let uniqueId = (UInt16(data[3]) << 8) | UInt16(data[4])
        let packetSeq = data[5]
        let length = (UInt16(data[6]) << 8) | UInt16(data[7])
        let checksum = (UInt16(data[8]) << 8) | UInt16(data[9])

        // 验证魔数
        guard magicCode == MAGIC_CODE else {
            throw AEPacketError.invalidMagicCode(expected: MAGIC_CODE, actual: magicCode)
        }

        // 低 4 位为类型，高 4 位为标志位
        guard let dataType = AEDataType(rawValue: dataTypeByte & DATA_TYPE_MASK) else {
            throw AEPacketError.invalidDataType(value: dataTypeByte)
        }
        let flags = dataTypeByte & 0xF0

        return AEPacketHeader(
            dataType: dataType,
            flags: flags,
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

        // 低 4 位类型 | 高 4 位标志位
        let dataTypeByte = dataType.rawValue | flags

        data.append(Data(bytes: &magicBE, count: 2))
        data.append(dataTypeByte)                  // 1 byte
        data.append(Data(bytes: &uniqueIdBE, count: 2))
        data.append(packetSeq)                     // 1 byte
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

    /// 实际数据类型
    var dataTypeValue: AEDataType? {
        return dataType
    }

    /// 是否为末包（packetSeq == LAST_PACKET_SEQ，即 255）
    var isLastFragment: Bool {
        return packetSeq == LAST_PACKET_SEQ
    }

    /// 是否为压缩包（第 5 位置 1）
    var isCompressed: Bool {
        return (flags & AEFlag.compressed.rawValue) != 0
    }

    /// 是否为加密包（第 6 位置 1）
    var isEncrypted: Bool {
        return (flags & AEFlag.encrypted.rawValue) != 0
    }

    /// 第 7 位保留标志是否置 1
    var isReserved: Bool {
        return (flags & AEFlag.reserved.rawValue) != 0
    }

    /// 设置标志位：true 置 1、false 置 0
    mutating func setFlag(_ flag: AEFlag, on: Bool) {
        flags = on ? (flags | flag.rawValue) : (flags & ~flag.rawValue)
    }

    /// 是否为非分片单包
    var isSinglePacket: Bool {
        return uniqueId == UNIQUE_ID_SENTINEL
    }
}
