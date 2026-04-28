//
//  AEPacketParser.swift
//  AENetworkEngine
//
//  Created on 2026/04/28.
//

import Foundation

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

    /// 响应接收回调（解析后的 AENetRsp）
    public var onResponseReceived: ((AENetRsp) -> Void)?

    /// 解析错误回调
    public var onParseError: ((Error) -> Void)?

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

        print("🚀 [Parser] 解析器已启动")
    }

    /// 停止解析器
    public func stop() {
        isRunning = false
        parseSemaphore.signal()  // 唤醒线程以便退出
        print("🛑 [Parser] 解析器已停止")
    }

    /// 通知解析器有新数据可以解析
    public func notifyDataAvailable() {
        parseSemaphore.signal()
    }

    /// 获取缓冲区引用
    public func getBuffer() -> AEPacketBuffer {
        return buffer
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

        print("✅ [Parser] 解析线程已退出")
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
            print("📦 [Parser] 解析包头成功: dataType=\(header.dataType), length=\(header.length)")
        } catch {
            print("❌ [Parser] 解析包头失败: \(error)")
            onParseError?(error)

            // 查找下一个可能的魔数位置
            if let nextMagicIndex = findNextMagicCode() {
                print("⚠️ [Parser] 跳过 \(nextMagicIndex) bytes 数据，尝试下一个包头")
                buffer.removeData(start: 0, end: nextMagicIndex)
                return true  // 继续尝试解析
            } else {
                // 没有找到魔数，清空缓冲区
                print("⚠️ [Parser] 未找到有效魔数，清空缓冲区")
                buffer.clear()
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
            print("✅ [Parser] 解析数据包成功: \(dataLength) bytes, checksum=0x\(String(format: "%04X", header.checksum))")
        } catch {
            print("❌ [Parser] 数据包校验失败: \(error)")
            onParseError?(error)

            // 校验失败，丢弃整个数据包，继续解析
            buffer.removeData(start: 0, end: totalRequired)
            return true  // 继续尝试解析下一个
        }

        // 8. 移除已解析的数据
        buffer.removeData(start: 0, end: totalRequired)

        // 9. 解析为 AENetRsp 并回调
        parsePacketToResponse(packet)

        return true  // 成功解析，继续尝试解析下一个
    }

    /// 将数据包解析为 AENetRsp
    /// - Parameter packet: 完整的数据包
    private func parsePacketToResponse(_ packet: AEPacket) {
        let data = packet.data

        print("🔍 [Parser] 解析数据包为 AENetRsp: \(data.count) bytes")

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("⚠️ [Parser] 无法解析数据包为 JSON")
            let error = NSError(domain: "AEPacketParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析数据包为 JSON"])
            onParseError?(error)
            return
        }

        guard let requestId = json["requestId"] as? String else {
            print("⚠️ [Parser] 数据包中缺少 requestId 字段")
            let error = NSError(domain: "AEPacketParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "数据包中缺少 requestId 字段"])
            onParseError?(error)
            return
        }

        print("✅ [Parser] 解析 AENetRsp 成功: requestId=\(requestId)")

        // 创建响应对象
        let response = AENetRsp(
            requestId: requestId,
            protocolType: .socket,
            statusCode: 200,
            data: data,
            error: nil
        )

        // 回调到主线程
        DispatchQueue.main.async { [weak self] in
            self?.onResponseReceived?(response)
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
