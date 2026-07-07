import Foundation

/// IO 数据包模型
public struct AEIOModel {
    /// Magic 标识（2字节）
    public let magic: UInt16 = 0xAEAE

    /// 标识符（2字节） - 用于区分数据流
    public let identifier: UInt16

    /// 索引（1字节） - 分包索引
    public let index: UInt8

    /// 总包数（1字节）
    public let totalPackets: UInt8

    /// 数据长度（2字节）
    public let length: UInt16

    /// 数据内容
    public let data: Data

    /// 包头大小
    public static let headerSize = 8  // 2+2+1+1+2

    public init(identifier: UInt16, index: UInt8, totalPackets: UInt8, data: Data) {
        self.identifier = identifier
        self.index = index
        self.totalPackets = totalPackets
        self.length = UInt16(data.count)
        self.data = data
    }

    /// 序列化为 Data
    public func serialize() -> Data {
        var bytes = Data()
        bytes.append(contentsOf: magic.bigEndian.bytes)
        bytes.append(contentsOf: identifier.bigEndian.bytes)
        bytes.append(index)
        bytes.append(totalPackets)
        bytes.append(contentsOf: length.bigEndian.bytes)
        bytes.append(data)
        return bytes
    }

    /// 从 Data 反序列化
    public static func deserialize(_ data: Data) -> AEIOModel? {
        guard data.count >= headerSize else { return nil }

        let magic = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) })
        guard magic == 0xAEAE else { return nil }

        let identifier = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) })
        let index = data[4]
        let totalPackets = data[5]
        let length = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: UInt16.self) })

        let payload = data.subdata(in: headerSize..<min(headerSize + Int(length), data.count))

        return AEIOModel(identifier: identifier, index: index, totalPackets: totalPackets, data: payload)
    }
}

/// 数据流 - 包装 AESession
public class AEDataStream {
    private let io: AEIOProtocol
    private let security: AENetSecurity?
    private var pendingPackets: [UInt16: [UInt8: AEIOModel]] = [:]
    private let lock = NSLock()

    public init(io: AEIOProtocol, security: AENetSecurity? = nil) {
        self.io = io
        self.security = security
    }

    /// 发送数据（自动分包）
    public func send(data: Data, completion: ((Bool, Error?) -> Void)? = nil) {
        // 1. 加密数据
        let encryptedData: Data
        if let security = security {
            encryptedData = security.encrypt(data) ?? data
        } else {
            encryptedData = data
        }

        // 2. 计算分包
        let mtu = io.mtu - AEIOModel.headerSize
        let totalPackets = (encryptedData.count + mtu - 1) / mtu
        let identifier = UInt16.random(in: 1...UInt16.max)

        // 3. 分包发送
        for i in 0..<totalPackets {
            let start = i * mtu
            let end = min((i + 1) * mtu, encryptedData.count)
            let chunk = encryptedData.subdata(in: start..<end)

            let packet = AEIOModel(
                identifier: identifier,
                index: UInt8(i),
                totalPackets: UInt8(totalPackets),
                data: chunk
            )

            io.send(data: packet.serialize()) { success, error in
                if i == totalPackets - 1 {
                    completion?(success, error)
                }
            }
        }
    }

    /// 接收数据包并拼接
    public func handleReceivedPacket(_ packetData: Data) -> Data? {
        guard let packet = AEIOModel.deserialize(packetData) else { return nil }

        lock.lock()
        defer { lock.unlock() }

        // 存储包
        if pendingPackets[packet.identifier] == nil {
            pendingPackets[packet.identifier] = [:]
        }
        pendingPackets[packet.identifier]?[packet.index] = packet

        // 检查是否所有包都到齐
        guard let packets = pendingPackets[packet.identifier],
              packets.count == Int(packet.totalPackets) else {
            return nil
        }

        // 拼接数据
        var completeData = Data()
        for i in 0..<Int(packet.totalPackets) {
            if let p = packets[UInt8(i)] {
                completeData.append(p.data)
            }
        }

        // 清理
        pendingPackets.removeValue(forKey: packet.identifier)

        // 解密
        if let security = security {
            return security.decrypt(completeData)
        }
        return completeData
    }
}
