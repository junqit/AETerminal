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
/// - add(packet) 追加一个分片；已收到末包（FLAG_LAST_FRAGMENT）且 0..lastSeq 全部到齐时组包，
///   组包完成后清空 packets。
/// - isComplete 检测是否已组包完成：packets 为空代表包已经完整。
/// - assemble() 返回组包后的完整数据。
public final class AEPacketPool {

    /// 唯一标识
    let uniqueId: UInt16

    /// seq -> packet；组包完成后清空
    private var packets: [UInt8: AEPacket] = [:]

    /// 末包 seq；未收到末包时为 nil
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

    /// 追加一个分片；已收到末包且收齐时组包，组包后清空 packets。
    func add(_ packet: AEPacket) {
        let seq = packet.header.packetSeq
        packets[seq] = packet
        dataTypeRaw = packet.header.dataType

        if packet.header.isLastFragment {
            lastSeq = seq
        }

        // 末包已到且 0..lastSeq 全部到齐 → 组包
        if let last = lastSeq {
            var complete = true
            for i in 0...last {
                if packets[i] == nil {
                    complete = false
                    break
                }
            }
            if complete {
                var data = Data()
                for i in 0...last {
                    data.append(packets[i]!.data)
                }
                assembled = data
                // 组包完成，清空 packets（为空代表已完整）
                packets.removeAll()
            }
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
