//
//  AEPackageData.swift
//  AENetworkEngine
//
//  Created on 2026/09/05.
//

import Foundation
import AELogProxy

/// 待发送数据的包装，负责转换为 [AEPacket]（接管分片逻辑）。
public final class AEPackageData {

    /// 待发送数据
    public let data: Data

    /// 数据类型
    public let dataType: AEDataType

    /// 转换后的 packet 列表（单包或分片；末包 packetSeq 恒为 LAST_PACKET_SEQ）
    public let packets: [AEPacket]

    public init(data: Data, dataType: AEDataType) {
        self.data = data
        self.dataType = dataType
        self.packets = AEPackageData.makePackets(dataType: dataType, data: data)
    }

    // MARK: - 分片 UniqueID

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

    /// 由 data 构造 packet 列表（单包或分片）
    private static func makePackets(dataType: AEDataType, data: Data) -> [AEPacket] {
        var packets: [AEPacket] = []

        // 单包：无需分片，UniqueID 用哨兵值
        if data.count <= MAX_PACKET_DATA_LENGTH {
            packets.append(AEPacket.create(dataType: dataType, data: data))
            return packets
        }

        // 分片：共用 UniqueID，packetSeq 从 255 倒数，末包恒为 LAST_PACKET_SEQ
        let uniqueId = nextUniqueId()
        let total = (data.count + MAX_PACKET_DATA_LENGTH - 1) / MAX_PACKET_DATA_LENGTH

        // 分片数不可超过 LAST_PACKET_SEQ（末包恒为 255，倒数下溢即超限）
        guard total <= Int(LAST_PACKET_SEQ) else {
            AELog("❌ [Package] 数据分片数超过上限，数据大小:\(data.count) 分片数:\(total)")
            return []
        }

        for i in 0..<total {
            let start = i * MAX_PACKET_DATA_LENGTH
            let end = min(start + MAX_PACKET_DATA_LENGTH, data.count)
            let chunk = data.subdata(in: start..<end)
            // seq 从 (LAST_PACKET_SEQ - total + 1) 倒数至 LAST_PACKET_SEQ，末包恒为 255
            let seq = UInt8(Int(LAST_PACKET_SEQ) - total + 1 + i)
            packets.append(AEPacket.create(
                dataType: dataType,
                data: chunk,
                uniqueId: uniqueId,
                packetSeq: seq
            ))
        }
        return packets
    }
}
