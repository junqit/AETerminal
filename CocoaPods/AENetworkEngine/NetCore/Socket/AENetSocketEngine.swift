//
//  AENetSocketEngineEngine.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/23.
//

import Foundation
import Network
import AEFoundation
import AELogProxy

/// Socket 连接状态
public enum AESocketState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

/// Socket 错误类型
public enum AESocketError: Error {
    case invalidAddress
    case connectionFailed
    case sendFailed
    case notConnected
    case encodingFailed
}

/// 网络 Socket 类，支持 TCP/UDP 连接
public class AENetSocketEngine: AENetCoreProtocol {

    // MARK: - Properties

    /// IP 地址
    public let ip: String

    /// 端口号
    public let port: UInt16

    /// 协议类型
    public let protocolType: AENetSocketType

    /// 数据类型（默认 .data；发送业务数据时使用，由引擎保存）
    public var dataType: AEDataType = .data

    /// 连接状态（原子包装）
    private let _state = AEAtom<AESocketState>(.disconnected)

    public var state: AESocketState {
        var current: AESocketState = .disconnected
        _state.read { current = $0 }
        return current
    }

    /// NWConnection 连接对象
    private var connection: NWConnection?

    /// 网络IO队列
    private let queue = DispatchQueue(label: "com.aenetwork.socket.io", qos: .userInitiated)

    /// 数据解析队列
    private let parseQueue = DispatchQueue(label: "com.aenetwork.socket.parse", qos: .userInitiated)

    /// 状态变化回调
    public var onStateChanged: ((AESocketState) -> Void)?

    /// 接收响应回调（解析后的 AENetRsp）
    public var onResponseReceived: ((AENetRsp) -> Void)?

    /// 网络核心代理（AENetCoreProtocol；接收主动推送的响应）
    public weak var delegate: AENetCoreDelegate?

    /// 网络核心类型
    public var coreType: AENetworkType {
        return .socket
    }

    /// 待处理的请求 [requestId: AENetReq]
    private var pendingRequests: [String: AENetReq] = [:]
    private let pendingLock = NSLock()

    /// 数据包解析器
    private let packetParser = AEPacketParser()

    /// 待发送数据队列（AEPackageData）；子线程串行处理，上一个完成才发下一个
    private var pendingPackages: [AEPackageData] = []

    /// 发送队列锁
    private let sendLock = NSLock()

    /// 是否正在处理发送队列
    private var isSending = false

    /// 发送子线程（串行）
    private let sendDispatchQueue = DispatchQueue(label: "com.aenetwork.socket.send", qos: .userInitiated)

    /// UDP 心跳间隔（秒），定时发送空心跳包保活链路，避免 NAT 表项超时
    private let heartbeatInterval: Int = 15

    /// 心跳定时器（仅 UDP，保活链路）
    private var heartbeatTimer: DispatchSourceTimer?

    // MARK: - Initialization

    /// 初始化 Socket
    /// - Parameters:
    ///   - ip: IP 地址
    ///   - port: 端口号
    ///   - protocolType: 协议类型（TCP/UDP）
    public init(ip: String, port: UInt16, protocolType: AENetSocketType = .tcp) {
        
        self.ip = ip
        self.port = port
        self.protocolType = protocolType

        // 配置解析器代理
        packetParser.delegate = self

        // 启动解析器
        packetParser.start()
    }

    // MARK: - Connection Management

    /// 连接 Socket
    public func connect() throws {
        switch state {
        case .disconnected, .failed:
            break
        default:
            AELog("⚠️ [Socket] 连接已存在，跳过重复连接")
            return
        }

        AELog("🔌 [Socket] 开始连接: \(ip):\(port) (\(protocolType == .tcp ? "TCP" : "UDP"))")

        let host = NWEndpoint.Host(ip)

        let port = NWEndpoint.Port(rawValue: self.port)!

        let parameters: NWParameters
        switch protocolType {
        case .tcp:
            parameters = .tcp
        case .udp:
            parameters = .udp
        }

        connection = NWConnection(host: host, port: port, using: parameters)

        updateState(.connecting)

        connection?.stateUpdateHandler = { [weak self] newState in
            self?.handleStateChange(newState)
        }

        connection?.start(queue: queue)

        // 开始接收数据
        receiveData()
    }

    /// 断开连接
    public func disconnect() {
        AELog("🔌 [Socket] 断开连接: \(ip):\(port)")
        stopHeartbeat()
        connection?.cancel()
        connection = nil

        // 清空缓冲区
        packetParser.reset()

        // 清空待处理请求
        pendingLock.lock()
        pendingRequests.removeAll()
        pendingLock.unlock()

        // 清空发送队列
        sendLock.lock()
        pendingPackages.removeAll()
        isSending = false
        sendLock.unlock()

        updateState(.disconnected)
    }

    // MARK: - Send Data

    /// 发送 AENetReq 消息
    /// - Parameter request: 请求对象，响应通过 request.onStreamReceived / request.onCompleted 回调
    public func send(request: AENetReq) {
        guard case .connected = state else {
            AELog("⚠️ [Socket] 未连接，发送请求失败")
            return
        }

        pendingLock.lock()
        pendingRequests[request.requestId] = request
        pendingLock.unlock()

        do {
            let data = try encodeRequest(request)
            try send(data)
        } catch {
            AELog("⚠️ [Socket] 请求发送失效 requestId:\(request.requestId)")
        }
    }

    /// 发送原始数据（封装为数据包）
    /// - Parameter data: 要发送的数据
    /// - Throws: 发送失败时抛出错误
    public func send(_ data: Data) throws {
        switch state {
        case .connected:
            break
        default:
            throw AESocketError.notConnected
        }

        // 构造 AEPackageData 入发送队列；子线程串行处理（上一个完成才发下一个）
        enqueue(AEPackageData(data: data, dataType: dataType))
    }

    /// 发送网络响应（AENetCoreProtocol）
    /// - Parameter response: 网络响应对象
    public func send(response: AENetRsp) {
        do {
            let data = try response.encode()
            try send(data)
        } catch {
            AELog("⚠️ [Socket] 响应发送失败 requestId:\(response.requestId)")
        }
    }

    /// 逐包下发整个 packet 列表（不组装合并，避免内存碎片），DispatchGroup 等所有包完成回调
    private func sendPackets(_ packets: [AEPacket], completion: @escaping (Error?) -> Void) {
        guard !packets.isEmpty else {
            completion(nil)
            return
        }
        guard let connection = connection else {
            completion(AESocketError.notConnected)
            return
        }

        let group = DispatchGroup()
        let errorLock = NSLock()
        var firstError: Error?

        for packet in packets {
            group.enter()
            connection.send(content: packet.toBytes(), completion: .contentProcessed { error in
                if let error = error {
                    errorLock.lock()
                    if firstError == nil { firstError = error }
                    errorLock.unlock()
                }
                group.leave()
            })
        }

        group.notify(queue: sendDispatchQueue) { completion(firstError) }
    }

    // MARK: - Private Methods

    /// 入队 AEPackageData；空闲则启动子线程串行处理
    private func enqueue(_ package: AEPackageData) {
        sendLock.lock()
        pendingPackages.append(package)
        let start = !isSending
        if start { isSending = true }
        sendLock.unlock()

        if start {
            sendDispatchQueue.async { [weak self] in self?.processSendQueue() }
        }
    }

    /// 串行处理发送队列：出队一个 AEPackageData 下发，完成后处理下一个
    private func processSendQueue() {
        sendLock.lock()
        guard !pendingPackages.isEmpty else {
            isSending = false
            sendLock.unlock()
            return
        }
        let package = pendingPackages.removeFirst()
        sendLock.unlock()

        sendPackets(package.packets) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                AELog("❌ [Socket] 数据包发送失败")
                self.updateState(.failed(AESocketError.sendFailed))
                self.sendLock.lock()
                self.pendingPackages.removeAll()
                self.isSending = false
                self.sendLock.unlock()
                return
            }

            // 本 AEPackageData 完成，处理下一个
            self.sendDispatchQueue.async { [weak self] in self?.processSendQueue() }
        }
    }

    private func handleResponse(_ response: AENetRsp) {

        pendingLock.lock()
        let request = pendingRequests[response.requestId]
        if response.isCompleted {
            pendingRequests.removeValue(forKey: response.requestId)
        }
        pendingLock.unlock()

        if let request = request {
            if response.isCompleted, let callback = request.onCompleted {
                callback(response)
                return
            }
            if !response.isCompleted, let callback = request.onStreamReceived {
                callback(response)
                return
            }
        }

        delegate?.netCore(didReceive: response)
        onResponseReceived?(response)
    }

    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            AELog("✅ [Socket] 连接成功: \(ip):\(port)")
            updateState(.connected)

            // UDP 无连接态，定时发心跳保活链路，避免 NAT 表项超时导致链路失败
            if protocolType == .udp {
                startHeartbeat()
            }

        case .waiting(let error):
            AELog("⏳ [Socket] 连接等待: \(error)")
            updateState(.failed(error))

        case .failed(let error):
            AELog("❌ [Socket] 连接失败: \(error)")
            stopHeartbeat()
            updateState(.failed(error))

        case .cancelled:
            AELog("🔌 [Socket] 连接已取消")
            stopHeartbeat()
            updateState(.disconnected)

        case .setup:
            AELog("🔧 [Socket] 连接设置中...")

        case .preparing:
            AELog("⚙️ [Socket] 连接准备中...")

        @unknown default:
            AELog("⚠️ [Socket] 未知状态: \(newState)")
        }
    }

    private func updateState(_ newState: AESocketState) {
        _state.write { $0 = newState }
        onStateChanged?(newState)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {

                // 解析放到独立线程，不阻塞下一次接收
                self.parseQueue.async { [weak self] in
                    self?.packetParser.appendData(data)
                }
            }

            if let error = error {
                AELog("❌ [Socket] 接收数据错误: \(error)")
                self.updateState(.failed(error))
                return
            }

            if isComplete {
                if self.protocolType == .udp {
                    // UDP: isComplete 表示当前数据报完整，继续接收下一个
                    // 异步调度避免递归栈溢出
                    self.queue.async { [weak self] in
                        self?.receiveData()
                    }
                } else {
                    // TCP: isComplete 且无后续数据表示对端关闭
                    if data == nil || data!.isEmpty {
                        AELog("🔌 [Socket] TCP 连接关闭")
                        self.updateState(.disconnected)
                    } else {
                        self.queue.async { [weak self] in
                            self?.receiveData()
                        }
                    }
                }
            } else {
                // 未完成，异步调度继续接收，避免递归栈溢出
                self.queue.async { [weak self] in
                    self?.receiveData()
                }
            }
        }
    }

    // MARK: - Heartbeat

    /// 启动 UDP 心跳保活（仅 UDP，连接成功后调用）
    private func startHeartbeat() {

        // 先清理已有定时器，避免重复启动
        stopHeartbeat()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.scheduleRepeating(
            deadline: .now() + .seconds(heartbeatInterval),
            interval: .seconds(heartbeatInterval)
        )
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        timer.resume()
        heartbeatTimer = timer

        AELog("💓 [Socket] UDP 心跳保活已启动，间隔:\(heartbeatInterval)s")
    }

    /// 停止 UDP 心跳保活
    private func stopHeartbeat() {

        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    /// 发送心跳包，保活 UDP 链路
    private func sendHeartbeat() {

        // heartbeat 走同一列表机制（AEPackageData）；载荷用空 JSON 兼容对端解析器
        let packets = AEPackageData(data: Data("{}".utf8), dataType: .heartbeat).packets

        sendPackets(packets) { [weak self] error in
            guard let self = self else { return }

            if error != nil {
                AELog("❌ [Socket] UDP 心跳保活发送失败")
                self.stopHeartbeat()
                self.updateState(.failed(AESocketError.sendFailed))
            }
        }
    }

    private func encodeRequest(_ request: AENetReq) throws -> Data {
        do {
            return try request.encode()
        } catch {
            throw AESocketError.encodingFailed
        }
    }

    // MARK: - Deinit

    deinit {
        disconnect()
    }
}

// MARK: - AEPacketParserDelegate

extension AENetSocketEngine: AEPacketParserDelegate {

    public func parser(_ parser: AEPacketParser, didReceiveRequest request: AENetReq) {
        AELog("📥 [Socket] 收到请求类型数据包: requestId=\(request.requestId)")
    }

    public func parser(_ parser: AEPacketParser, didReceiveResponse response: AENetRsp) {
        handleResponse(response)
    }


}

