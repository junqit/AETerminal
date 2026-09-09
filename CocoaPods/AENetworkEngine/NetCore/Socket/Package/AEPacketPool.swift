//
//  AEPacketPool.swift
//  AENetworkEngine
//
//  对应服务端 AEPacketPool：单条消息的分片收集与拼装。
//

import Foundation

/// 单条消息的分片收集与拼装。
///
/// 同一 UniqueID 的多个分片归入同一个 AEPacketPool：
/// - add(packet) 追加一个分片；末包（packetSeq == LAST_PACKET_SEQ）已到且 packets.count == lastSeq - firstSeq + 1 时组包，
///   组包完成后清空 packets。
/// - isComplete 检测是否已组包完成：packets 为空代表包已经完整。
/// - assemble() 返回组包后的完整数据。
public final class AEPacketPool {

    /// 唯一标识
    let uniqueId: UInt16

    /// seq -> packet；组包完成后清空
    private var packets: [UInt8: AEPacket] = [:]

    /// 首包 seq（首个收到的分片；有序到达即最小 seq）；未收到分片时为 nil
    private var firstSeq: UInt8?

    /// 末包 seq（== LAST_PACKET_SEQ）；未收到末包时为 nil
    private(set) var lastSeq: UInt8?

    /// 组包后的完整数据；未组包完成时为 nil
    private var assembled: Data?

    /// 分片数据类型原始字节（低 4 位类型，高 4 位标志）；组包清空 packets 后仍保留
    private(set) var dataTypeRaw: UInt8 = 0

    /// 传入收到的第一个分片构造
    init(uniqueId: UInt16, packet: AEPacket) {
        self.uniqueId = uniqueId
        add(packet)
    }

    /// 追加一个分片；末包已到且收齐时组包，组包后清空 packets。
    func add(_ packet: AEPacket) {
        let seq = packet.header.packetSeq
        packets[seq] = packet
        dataTypeRaw = packet.header.dataType.rawValue

        // 首包 seq 仅在首个分片到达时记录（有序到达即最小 seq）
        if firstSeq == nil {
            firstSeq = seq
        }

        // 末包：packetSeq == LAST_PACKET_SEQ（255）
        if packet.header.isLastFragment {
            lastSeq = seq
        }

        // 末包已到且 收到数量 == lastSeq - firstSeq + 1（跨度等于数量，无空洞）→ 组包
        if let first = firstSeq, let last = lastSeq, packets.count == Int(last) - Int(first) + 1 {
            var data = Data()
            for i in first...last {
                data.append(packets[i]!.data)
            }
            assembled = data
            // 组包完成，清空 packets（为空代表已完整）
            packets.removeAll()
        }
    }

    /// 是否已组包完成：packets 为空代表包已经完整。
    var isComplete: Bool {
        return packets.isEmpty
    }

    /// 返回组包后的完整数据；未组包完成时返回空 Data。
    func assemble() -> Data {
        return assembled ?? Data()
    }

    /// 实际数据类型（低 4 位）
    var dataTypeValue: AEDataType? {
        return AEDataType(rawValue: dataTypeRaw & DATA_TYPE_MASK)
    }
}
