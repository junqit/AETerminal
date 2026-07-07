//
//  AEPacketParser.swift
//  AENetworkEngine
//
//  Created on 2026/04/28.
//

import Foundation
import AELogProxy

/// 数据包解析器代理协议
public protocol AEPacketParserDelegate: AnyObject {

    /// 收到请求类型数据包
    func parser(_ parser: AEPacketParser, didReceiveRequest request: AENetReq)

    /// 收到响应类型数据包
    func parser(_ parser: AEPacketParser, didReceiveResponse response: AENetRsp)
}

public extension AEPacketParserDelegate {
    func parser(_ parser: AEPacketParser, didReceiveRequest request: AENetReq) {}
    func parser(_ parser: AEPacketParser, didReceiveResponse response: AENetRsp) {}
}

/// 数据包解析器 - 负责从缓冲区解析数据包
public class AEPacketParser {

    // MARK: - Properties

    /// 数据缓冲区（内部创建）
    private let buffer = AEPacketBuffer()

    /// 解析队列（后台线程）
    private let parseQueue = DispatchQueue(label: "com.aenetwork.packet.parse", qos: .userInitiated)

    /// 解析信号量
    private let parseSemaphore = DispatchSemaphore(value: 0)

    /// 是否正在运行
    private var isRunning = false

    /// 分片重组：uniqueId -> AEPacketPool；解析队列单线程访问，无需加锁
    private var packetPools: [UInt16: AEPacketPool] = [:]

    /// 代理
    public weak var delegate: AEPacketParserDelegate?

    // MARK: - Initialization

    /// 初始化解析器
    public init() {
        // 内部创建缓冲区，无需外部传入
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// 启动解析器
    public func start() {
        guard !isRunning else { return }

        isRunning = true
        parseQueue.async { [weak self] in
            self?.parseLoop()
        }

        AELog("🚀 [Parser] 解析器已启动")
    }

    /// 停止解析器
    public func stop() {
        isRunning = false
        parseSemaphore.signal()  // 唤醒线程以便退出
        AELog("🛑 [Parser] 解析器已停止")
    }

    /// 追加数据并通知解析器
    public func appendData(_ data: Data) {
        buffer.append(data)
        parseSemaphore.signal()
    }

    /// 清空缓冲区
    public func reset() {
        buffer.clear()
        packetPools.removeAll()
    }

    // MARK: - Private Methods

    /// 解析循环（运行在后台线程）
    private func parseLoop() {
        while isRunning {
            // 等待信号
            parseSemaphore.wait()

            guard isRunning else { break }

            // 循环解析所有可用数据包
            while isRunning {
                let parsed = parseNextPacket()
                if !parsed {
                    break  // 没有完整数据包，等待下次信号
                }
            }
        }

        AELog("✅ [Parser] 解析线程已退出")
    }

    /// 解析下一个数据包
    /// - Returns: 是否成功解析了一个完整数据包
    private func parseNextPacket() -> Bool {
        // 1. 检查是否有足够的数据解析包头
        guard buffer.count >= AEPacketHeader.headerSize else {
            return false
        }

        // 2. 提取包头数据（使用下标）
        guard let headerData = buffer[0..<AEPacketHeader.headerSize] else {
            return false
        }

        // 3. 解析包头
        let header: AEPacketHeader
        do {
            header = try AEPacketHeader.from(data: headerData)
        } catch {
            AELog("❌ [Parser] 解析包头失败: \(error)")
            AELog("❌ [Parser] \(error)")

            // 查找下一个可能的魔数位置
            if let nextMagicIndex = findNextMagicCode() {
                AELog("⚠️ [Parser] 跳过 \(nextMagicIndex) bytes 数据，尝试下一个包头")
                buffer.removeData(start: 0, end: nextMagicIndex)
                return true  // 继续尝试解析
            } else {
                // 没有找到魔数，数据可能还未接收完整，等待更多数据
                return false
            }
        }

        // 4. 检查是否有足够的数据体
        let dataLength = Int(header.length)
        let totalRequired = AEPacketHeader.headerSize + dataLength

        guard buffer.count >= totalRequired else {
            return false
        }

        // 5. 提取完整数据包（使用下标）
        guard let packetData = buffer[0..<totalRequired] else {
            return false
        }

        // 6. 提取数据体（使用下标）
        let bodyData = packetData.subdata(in: AEPacketHeader.headerSize..<totalRequired)

        // 7. 验证并创建数据包
        let packet: AEPacket
        do {
            packet = try AEPacket.from(header: header, data: bodyData)
        } catch {
            AELog("❌ [Parser] 数据包校验失败: \(error)")
            AELog("❌ [Parser] \(error)")

            // 校验失败，丢弃整个数据包，继续解析
            buffer.removeData(start: 0, end: totalRequired)
            return true  // 继续尝试解析下一个
        }

        // 8. 移除已解析的数据
        buffer.removeData(start: 0, end: totalRequired)

        // 9. 处理数据包（分片重组或直接分发）
        handlePacket(packet)

        return true  // 成功解析，继续尝试解析下一个
    }

    /// 处理数据包：非分片单包直接分发；分片包按 uniqueId 收齐后拼装再分发
    private func handlePacket(_ packet: AEPacket) {
        // 非分片单包：直接按类型分发
        if packet.header.isSinglePacket {
            dispatch(data: packet.data, dataType: packet.header.dataTypeValue)
            return
        }

        // 分片包：按 uniqueId 收集，收齐后拼装再分发
        let uniqueId = packet.header.uniqueId

        let pool: AEPacketPool
        if let existing = packetPools[uniqueId] {
            pool = existing
            pool.add(packet)
        } else {
            // 首个分片：传入构造函数
            pool = AEPacketPool(uniqueId: uniqueId, packet: packet)
            packetPools[uniqueId] = pool
        }

        // 每收到一包都检测是否已完整
        if pool.isComplete {
            let assembled = pool.assemble()
            let dataType = pool.dataTypeValue
            packetPools.removeValue(forKey: uniqueId)
            AELog("🧩 [Parser] 分片组包完成 - uniqueId=\(uniqueId), size=\(assembled.count)")
            dispatch(data: assembled, dataType: dataType)
        }
    }

    /// 按数据类型分发完整数据
    private func dispatch(data: Data, dataType: AEDataType?) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            AELog("⚠️ [Parser] 无法解析数据包为 JSON")
            return
        }

        switch dataType {
        case .request:
            guard let request = AENetReq.fromMap(json) else {
                AELog("⚠️ [Parser] AENetReq.fromMap 解析失败")
                return
            }
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.delegate?.parser(self, didReceiveRequest: request)
            }

        case .response:
            guard let response = AENetRsp.fromMap(json) else {
                AELog("⚠️ [Parser] AENetRsp.fromMap 解析失败")
                return
            }
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.delegate?.parser(self, didReceiveResponse: response)
            }

        case .heartbeat, .ping, .pong, .custom:
            break

        case .none:
            AELog("⚠️ [Parser] 未知数据类型")
        }
    }


    /// 查找下一个魔数位置
    /// - Returns: 魔数的偏移位置，如果未找到返回 nil
    private func findNextMagicCode() -> Int? {
        let magicCode: UInt16 = 0x1EAE
        let magicByte1 = UInt8((magicCode >> 8) & 0xFF)
        let magicByte2 = UInt8(magicCode & 0xFF)

        // 从位置 1 开始搜索（跳过当前位置）
        for i in 1..<(buffer.count - 1) {
            if buffer[i] == magicByte1, buffer[i + 1] == magicByte2 {
                return i
            }
        }

        return nil
    }
}
