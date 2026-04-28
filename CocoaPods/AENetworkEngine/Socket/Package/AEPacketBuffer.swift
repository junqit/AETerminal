//
//  AEPacketBuffer.swift
//  AENetworkEngine
//
//  Created on 2026/04/27.
//

import Foundation

/// 数据包缓冲区 - 用于处理数据流并解析完整的数据包
public class AEPacketBuffer {

    // MARK: - Properties

    /// 接收缓冲区
    private var receiveBuffer = Data()

    /// 缓冲区访问锁
    private let bufferLock = NSLock()

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

    public init() {
        startParseThread()
    }

    deinit {
        stopParseThread()
    }

    // MARK: - Public Methods

    /// 追加接收到的数据
    /// - Parameter data: 新接收的数据
    public func append(_ data: Data) {
        bufferLock.lock()
        receiveBuffer.append(data)
        let bufferSize = receiveBuffer.count
        bufferLock.unlock()

        print("📦 [Buffer] 追加数据: \(data.count) bytes, 缓冲区总大小: \(bufferSize) bytes")

        // 发送信号，触发解析
        parseSemaphore.signal()
    }

    /// 清空缓冲区
    public func clear() {
        bufferLock.lock()
        receiveBuffer.removeAll()
        bufferLock.unlock()

        print("🧹 [Buffer] 缓冲区已清空")
    }

    /// 获取缓冲区大小
    public var bufferSize: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return receiveBuffer.count
    }

    // MARK: - Private Methods - Thread Management

    /// 启动解析线程
    private func startParseThread() {
        guard !isRunning else { return }

        isRunning = true
        parseQueue.async { [weak self] in
            self?.parseLoop()
        }

        print("🚀 [Buffer] 解析线程已启动")
    }

    /// 停止解析线程
    private func stopParseThread() {
        isRunning = false
        parseSemaphore.signal()  // 唤醒线程以便退出
        print("🛑 [Buffer] 解析线程已停止")
    }

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

        print("✅ [Buffer] 解析线程已退出")
    }

    /// 解析下一个数据包
    /// - Returns: 是否成功解析了一个完整数据包
    private func parseNextPacket() -> Bool {
        bufferLock.lock()

        // 1. 检查是否有足够的数据解析包头
        guard receiveBuffer.count >= AEPacketHeader.headerSize else {
            bufferLock.unlock()
            return false
        }

        // 2. 提取包头数据
        let headerData = receiveBuffer.prefix(AEPacketHeader.headerSize)

        // 3. 解析包头
        let header: AEPacketHeader
        do {
            header = try AEPacketHeader.from(data: headerData)
            print("📦 [Buffer] 解析包头成功: dataType=0x\(String(format: "%04X", header.dataType)), length=\(header.length)")
        } catch {
            print("❌ [Buffer] 解析包头失败: \(error)")
            onParseError?(error)

            // 查找下一个可能的魔数位置
            if let nextMagicIndex = findNextMagicCode() {
                print("⚠️ [Buffer] 跳过 \(nextMagicIndex) bytes 数据，尝试下一个包头")
                receiveBuffer.removeFirst(nextMagicIndex)
                bufferLock.unlock()
                return true  // 继续尝试解析
            } else {
                // 没有找到魔数，清空缓冲区
                print("⚠️ [Buffer] 未找到有效魔数，清空缓冲区")
                receiveBuffer.removeAll()
                bufferLock.unlock()
                return false
            }
        }

        // 4. 检查是否有足够的数据体
        let dataLength = Int(header.length)
        let totalRequired = AEPacketHeader.headerSize + dataLength

        guard receiveBuffer.count >= totalRequired else {
            bufferLock.unlock()
            return false
        }

        // 5. 提取数据体
        let bodyData = receiveBuffer.subdata(in: AEPacketHeader.headerSize..<totalRequired)

        // 6. 验证并创建数据包
        let packet: AEPacket
        do {
            packet = try AEPacket.from(header: header, data: bodyData)
            print("✅ [Buffer] 解析数据包成功: \(dataLength) bytes, checksum=0x\(String(format: "%04X", header.checksum))")
        } catch {
            print("❌ [Buffer] 数据包校验失败: \(error)")
            onParseError?(error)

            // 校验失败，丢弃整个数据包，继续解析
            receiveBuffer.removeFirst(totalRequired)
            bufferLock.unlock()
            return true  // 继续尝试解析下一个
        }

        // 7. 移除已解析的数据
        receiveBuffer.removeFirst(totalRequired)
        bufferLock.unlock()

        // 8. 解析为 AENetRsp 并回调
        parsePacketToResponse(packet)

        return true  // 成功解析，继续尝试解析下一个
    }

    /// 将数据包解析为 AENetRsp
    /// - Parameter packet: 完整的数据包
    private func parsePacketToResponse(_ packet: AEPacket) {
        let data = packet.data

        print("🔍 [Buffer] 解析数据包为 AENetRsp: \(data.count) bytes")

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("⚠️ [Buffer] 无法解析数据包为 JSON")
            let error = NSError(domain: "AEPacketBuffer", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析数据包为 JSON"])
            onParseError?(error)
            return
        }

        guard let requestId = json["requestId"] as? String else {
            print("⚠️ [Buffer] 数据包中缺少 requestId 字段")
            let error = NSError(domain: "AEPacketBuffer", code: -2, userInfo: [NSLocalizedDescriptionKey: "数据包中缺少 requestId 字段"])
            onParseError?(error)
            return
        }

        print("✅ [Buffer] 解析 AENetRsp 成功: requestId=\(requestId)")

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

    /// 查找下一个魔数位置（需要在锁内调用）
    /// - Returns: 魔数的偏移位置，如果未找到返回 nil
    private func findNextMagicCode() -> Int? {
        let magicCode: UInt16 = 0x1EAE
        let magicBytes = withUnsafeBytes(of: magicCode.bigEndian) { Data($0) }

        // 从位置 1 开始搜索（跳过当前位置）
        for i in 1..<receiveBuffer.count - 1 {
            let slice = receiveBuffer[i..<(i + 2)]
            if slice == magicBytes {
                return i
            }
        }

        return nil
    }
}
