//
//  AEPacket.swift
//  AENetworkEngine
//
//  Created on 2026/04/26.
//

import Foundation

/// 魔数：0x1EAE
/// 0x1E = ASCII Record Separator (RS) 控制字符
/// 0xAE = 扩展ASCII字符
private let MAGIC_CODE: UInt16 = 0x1EAE

/// 数据类型枚举
public enum AEDataType: UInt16 {
    case request = 0x0001    // 请求数据 (AENetReq)
    case response = 0x0002   // 响应数据 (AENetRsp)
    case heartbeat = 0x0003  // 心跳包
    case ping = 0x0004       // Ping
    case pong = 0x0005       // Pong
    case custom = 0x00FF     // 自定义数据
}

/// 数据包头结构
///
/// 包结构：
/// ┌─────────────┬──────────┬──────────┬──────────┬──────────┐
/// │ Magic Code  │ DataType │  Length  │ Checksum │   Data   │
/// │   (2 bytes) │ (2 bytes)│ (4 bytes)│ (2 bytes)│ (N bytes)│
/// └─────────────┴──────────┴──────────┴──────────┴──────────┘
///
/// 总包头长度: 10 bytes
public struct AEPacketHeader {

    /// 魔数，固定为 0x1EAE，2字节
    let magicCode: UInt16

    /// 数据类型，2字节
    let dataType: AEDataType

    /// 数据长度（不包含包头），4字节
    let length: UInt32

    /// 数据校验和（CRC16），2字节
    let checksum: UInt16

    /// 包头固定长度
    static let headerSize: Int = 10  // 2 + 2 + 4 + 2

    /// 初始化包头
    init(dataType: AEDataType, length: UInt32, checksum: UInt16) {
        self.magicCode = MAGIC_CODE
        self.dataType = dataType
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

        // 使用大端序解包
        let magicCode = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }.bigEndian
        let dataTypeRaw = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.bigEndian
        let length = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        let checksum = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt16.self) }.bigEndian

        // 验证魔数
        guard magicCode == MAGIC_CODE else {
            throw AEPacketError.invalidMagicCode(expected: MAGIC_CODE, actual: magicCode)
        }

        // 解析数据类型
        guard let dataType = AEDataType(rawValue: dataTypeRaw) else {
            throw AEPacketError.invalidDataType(value: dataTypeRaw)
        }

        return AEPacketHeader(
            dataType: dataType,
            length: length,
            checksum: checksum
        )
    }

    /// 将包头序列化为字节流
    /// - Returns: 10 字节的包头数据
    func toBytes() -> Data {
        var data = Data(capacity: AEPacketHeader.headerSize)

        // 使用大端序（网络字节序）
        var magicBE = magicCode.bigEndian
        var dataTypeBE = dataType.rawValue.bigEndian
        var lengthBE = length.bigEndian
        var checksumBE = checksum.bigEndian

        data.append(Data(bytes: &magicBE, count: 2))
        data.append(Data(bytes: &dataTypeBE, count: 2))
        data.append(Data(bytes: &lengthBE, count: 4))
        data.append(Data(bytes: &checksumBE, count: 2))

        return data
    }

    /// 验证数据完整性（使用 CRC16）
    /// - Parameter data: 要验证的数据
    /// - Returns: 数据是否完整
    func validate(data: Data) -> Bool {
        return checksum == AEPacket.calculateCRC16(data: data)
    }
}

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
    /// - Returns: 完整的数据包对象
    static func create(dataType: AEDataType, data: Data) -> AEPacket {
        // 计算校验和（CRC16）
        let checksum = calculateCRC16(data: data)

        // 创建包头
        let header = AEPacketHeader(
            dataType: dataType,
            length: UInt32(data.count),
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

/// 数据包错误类型
public enum AEPacketError: Error, LocalizedError {
    case insufficientData(expected: Int, actual: Int)
    case invalidMagicCode(expected: UInt16, actual: UInt16)
    case checksumMismatch(expected: UInt16, actual: UInt16)
    case invalidDataType(value: UInt16)

    public var errorDescription: String? {
        switch self {
        case .insufficientData(let expected, let actual):
            return "数据长度不足，需要至少 \(expected) 字节，实际 \(actual) 字节"
        case .invalidMagicCode(let expected, let actual):
            return String(format: "无效的魔数: 0x%04X, 期望: 0x%04X", actual, expected)
        case .checksumMismatch(let expected, let actual):
            return String(format: "数据校验失败: 期望 0x%04X, 实际 0x%04X", expected, actual)
        case .invalidDataType(let value):
            return String(format: "无效的数据类型: 0x%04X", value)
        }
    }
}
