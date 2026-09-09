//
//  AEPacket.swift
//  AENetworkEngine
//
//  Created on 2026/04/26.
//

import Foundation

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
    ///   - packetSeq: 包次（分片序号；末包恒为 LAST_PACKET_SEQ）
    /// - Returns: 完整的数据包对象
    static func create(
        dataType: AEDataType,
        data: Data,
        uniqueId: UInt16 = UNIQUE_ID_SENTINEL,
        packetSeq: UInt8 = 0
    ) -> AEPacket {
        // 末包改由 packetSeq == LAST_PACKET_SEQ 判定，flags 不再置位
        let flags: UInt8 = 0
        // 计算校验和（CRC16）
        let checksum = calculateCRC16(data: data)

        // 创建包头
        let header = AEPacketHeader(
            dataType: dataType,
            flags: flags,
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
}
